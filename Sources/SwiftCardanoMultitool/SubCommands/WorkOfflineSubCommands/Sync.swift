import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct Sync: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "sync",
            abstract: "Add UTXO or rewards info to the offline transfer file.",
            discussion: """
            Queries the blockchain for UTXO data (payment address) or rewards data
            (stake address) and stores it in the offline transfer file. Run this
            command on the online machine before transferring the file offline.
            """
        )

        @Option(name: [.short, .long], help: "Path to the .addr file to sync (payment or stake address).")
        var addressFile: FilePath

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

            // Load address info from file
            var addressInfo = try AddressInfo(fromFile: addressFile)

            guard let addressType = addressInfo.type else {
                noora.error(.alert(
                    "Could not determine address type from file.",
                    takeaways: [
                        "Ensure the file contains a valid payment or stake address.",
                        "File: \(addressFile.string)"
                    ]
                ))
                throw ExitCode.validationFailure
            }

            guard let addressName = addressInfo.name else {
                noora.error(.alert(
                    "Could not determine address name.",
                    takeaways: ["Ensure the address file has a recognisable name."]
                ))
                throw ExitCode.validationFailure
            }

            // Refresh protocol data while online
            let protocolParameters = try await noora.progressStep(
                message: "Querying protocol parameters...",
                successMessage: "Protocol parameters retrieved.",
                errorMessage: "Failed to retrieve protocol parameters.",
                showSpinner: true
            ) { _ in
                return try await context.protocolParameters()
            }

            let network = config.cardano?.network ?? .preview

            transfer.protocol.protocolParameters = protocolParameters
            transfer.protocol.era = try await context.era()
            transfer.protocol.network = network

            transfer.general.onlineVersion = "SwiftCardanoMultitool v\(Version.number) via \(context.name)"

            switch addressType {
            case .payment:
                spacedPrint(
                    "Syncing UTXOs for payment address \(.primary(addressName)): \(.primary(try addressInfo.address!.toBech32()))"
                )
                addressInfo.addressTypeEra()

                try await addressInfo.updateUTxOs(context: context)

                let total = addressInfo.utxos.reduce(0) { $0 + Int($1.output.amount.coin) }
                addressInfo = try AddressInfo(
                    addressFile: addressInfo.addressFile,
                    name: addressInfo.name,
                    address: addressInfo.address,
                    era: addressInfo.era,
                    type: addressInfo.type,
                    totalAmount: total,
                    utxos: addressInfo.utxos
                )

                if addressInfo.utxos.isEmpty {
                    noora.warning(.alert(
                        "No UTXOs found on this address.",
                        takeaway: "The address may have no funds."
                    ))
                }

                // Replace or append
                if let existingIdx = transfer.addresses.firstIndex(where: {
                    $0.address?.description == addressInfo.address?.description
                }) {
                    transfer.addresses[existingIdx] = addressInfo
                } else {
                    transfer.addresses.append(addressInfo)
                }

                transfer.history.append(OfflineTransferHistory(action: .addUtxoInfo(fileName: addressName)))

                spacedPrint("\(.success("UTXO info for '\(addressName)' added to the offline transfer file."))")
                spacedPrint("Transfer the file to your offline machine to continue.")

            case .stake:
                spacedPrint(
                    "Syncing rewards for stake address \(.primary(addressName)): \(.primary(try addressInfo.address!.toBech32()))"
                )
                addressInfo.addressTypeEra()

                try await addressInfo.updateStakeAddressInfo(context: context)

                if addressInfo.stakeAddressInfo.isEmpty {
                    noora.error(.alert(
                        "Stake address is not registered on chain.",
                        takeaways: ["Register the stake address before syncing."]
                    ))
                    throw ExitCode.failure
                }

                let totalRewards = addressInfo.stakeAddressInfo.reduce(0) { $0 + $1.rewardAccountBalance }
                addressInfo = try AddressInfo(
                    addressFile: addressInfo.addressFile,
                    name: addressInfo.name,
                    address: addressInfo.address,
                    era: addressInfo.era,
                    type: addressInfo.type,
                    totalAmount: Int(totalRewards),
                    stakeAddressInfo: addressInfo.stakeAddressInfo
                )

                if let existingIdx = transfer.addresses.firstIndex(where: {
                    $0.address?.description == addressInfo.address?.description
                }) {
                    transfer.addresses[existingIdx] = addressInfo
                } else {
                    transfer.addresses.append(addressInfo)
                }

                transfer.history.append(OfflineTransferHistory(action: .addStakeAddr(fileName: addressName)))

                spacedPrint("\(.success("Stake rewards info for '\(addressName)' added to the offline transfer file."))")
                spacedPrint("Transfer the file to your offline machine to continue.")
            }

            try transfer.save(to: inFile)
        }
    }
}
