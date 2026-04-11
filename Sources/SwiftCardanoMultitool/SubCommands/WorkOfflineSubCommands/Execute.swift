import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct Execute: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "execute",
            abstract: "Submit a queued transaction from the offline transfer file.",
            discussion: """
            Executes (submits) the transaction at the specified index in the offline
            transfer file. Run this command on the online machine after signing the
            transaction offline. The UTXO state is verified before submission.
            """
        )

        @Option(name: [.short, .long], help: "Index of the transaction to execute (0-based, default: 0).")
        var txIndex: Int = 0

        @Option(name: [.short, .long], help: "Path to the offline transfer file.")
        var inFile: FilePath?

        mutating func run() async throws {
            let config = try await MultitoolConfig.load()

            if inFile == nil {
                if let offlineFile = config.offlineFile {
                    inFile = offlineFile
                } else {
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    inFile = cwd.appending("offline-transfer.json")
                }
            }

            guard let inFile else {
                noora.error(.alert(
                    "No offline transfer file path could be determined.",
                    takeaways: ["Set 'offlineFile' in config or pass --in-file."]
                ))
                throw ExitCode.validationFailure
            }

            try FileUtils.checkFileExists(inFile)

            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            var transfer = try OfflineTransfer.load(from: inFile)

            let txCount = transfer.transactions.count
            guard txCount > 0 else {
                noora.error(.alert(
                    "No queued transactions found in the offline transfer file.",
                    takeaways: ["Build and sign a transaction offline first."]
                ))
                throw ExitCode.failure
            }

            guard txIndex >= 0 && txIndex < txCount else {
                noora.error(.alert(
                    "Transaction index \(txIndex) is out of range.",
                    takeaways: ["Valid indices: 0 to \(txCount - 1). There are \(txCount) queued transaction(s)."]
                ))
                throw ExitCode.validationFailure
            }

            let tx = transfer.transactions[txIndex]

            // Verify era match
            let liveEra = try await context.era()
            if let txEra = tx.era, let live = liveEra, txEra != live {
                noora.warning(.alert(
                    "Era mismatch: online=\(live), offline=\(txEra).",
                    takeaway: "Proceeding anyway — the node will reject the transaction if incompatible."
                ))
            }

            // Verify UTXOs haven't changed for fromAddress
            if let fromAddress = tx.fromAddress {
                let fromAddressObj = try SwiftCardanoCore.Address(from: .string(fromAddress))
                let liveUTxOs = try await noora.progressStep(
                    message: "Verifying UTXOs for \(tx.fromName ?? fromAddress)...",
                    successMessage: "UTXOs verified.",
                    errorMessage: "Failed to fetch UTXOs.",
                    showSpinner: true
                ) { _ in
                    return try await context.utxos(address: fromAddressObj)
                }

                if let offlineAddr = transfer.addresses.first(where: { $0.address?.description == fromAddress }) {
                    if offlineAddr.utxos.count != liveUTxOs.count {
                        noora.error(.alert(
                            "UTXO state has changed for \(tx.fromName ?? fromAddress).",
                            takeaways: [
                                "The UTXOs captured offline no longer match the current state.",
                                "Re-sync the address and rebuild the transaction."
                            ]
                        ))
                        throw ExitCode.failure
                    }
                }
            }

            // Display transaction details
            let era = tx.era.map { "\($0)" } ?? "unknown"
            let from = tx.fromName ?? tx.fromAddress ?? "unknown"
            let to = tx.toName ?? tx.toAddress ?? "unknown"
            spacedPrint(
                "\n[\(txIndex)] \(.primary("[\(era)]")) from \(.primary(from)) to \(.primary(to)) \(.muted("(\(tx.date ?? "unknown"))"))"
            )

            guard let txJson = tx.txJson, let cborHex = txJson.cborHex else {
                noora.error(.alert(
                    "Transaction at index \(txIndex) has no CBOR data.",
                    takeaways: ["The transaction may be corrupt or incomplete."]
                ))
                throw ExitCode.failure
            }

            let confirm = noora.yesOrNoChoicePrompt(
                title: "Confirm Submission",
                question: "Submit this transaction to the network?",
                defaultAnswer: false,
                description: "This action cannot be undone."
            )

            guard confirm else {
                noora.info("Transaction submission cancelled by user.")
                throw ExitCode.success
            }

            let transaction = try Transaction.fromCBORHex(cborHex)
            let txId = try await noora.progressStep(
                message: "Submitting transaction...",
                successMessage: "Transaction submitted.",
                errorMessage: "Failed to submit transaction.",
                showSpinner: true
            ) { _ in
                return try await context.submitTx(tx: .transaction(transaction))
            }

            noora.success("Transaction submitted with ID: \(txId)")

            // Mark fromAddress as used, remove executed tx, add history
            if let fromAddress = tx.fromAddress,
               let idx = transfer.addresses.firstIndex(where: { $0.address?.description == fromAddress }) {
                transfer.addresses[idx].used = true
            }

            transfer.transactions.remove(at: txIndex)

            let fromName = tx.fromName ?? tx.fromAddress ?? "unknown"
            let toName = tx.toName ?? tx.toAddress ?? "unknown"
            transfer.history.append(OfflineTransferHistory(
                action: .submitTransaction(txId: txId, fromName: fromName, toName: toName)
            ))

            try transfer.save(to: inFile)
        }
    }
}
