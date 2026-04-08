import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension CertificateMainCommand {

    struct ResignCommitteeColdCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            commandName: "resign-committee-cold",
            abstract: "Generates a constitutional committee cold key resignation certificate.",
            usage: """
            scm certificate resign-committee-cold --committee-cold-credential cc_cold1...
            """,
            discussion: """
            Creates a constitutional committee cold key resignation certificate
            that removes a committee member from the constitutional committee.
            An optional anchor (URL + metadata hash) can be provided to link
            the resignation to off-chain metadata. If the
            `--generate-transaction` flag is used, a transaction will also be
            created to submit the certificate on-chain.
            """,
            aliases: ["resign-cc-cold"]
        )

        // MARK: - Required Arguments

        @Option(name: .long, help: "Committee cold credential. Supports: bech32 (cc_cold1...), hex hash, .cc-cold.vkey file.")
        var committeeColdCredential: CommitteeColdCredential?

        // MARK: - CertificateCommandable Arguments

        @OptionGroup var certificateOptions: SharedCertificateOptions

        // MARK: - TransactionCommandable Arguments

        @OptionGroup var transactionOptions: SharedTransactionOptions

        // MARK: - Validation

        mutating func validate() throws {
            try self.validateForTransaction()
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            committeeColdCredential = try await getCommitteeColdCredential(title: "Committee Cold Credential to Resign")
            try await self.wizardForCertificate()
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if committeeColdCredential == nil {
                try await wizard()
            }

            guard let coldCredential = committeeColdCredential else {
                noora.error(.alert("Committee cold credential is required.", takeaways: ["Provide a valid cc_cold credential."]))
                throw ExitCode.validationFailure
            }

            let anchor = try await getOptionalAnchor(purpose: "resignation")

            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let timestamp = DateUtils.getCurrentTimestamp()
            let coldIdHex = try coldCredential.id((.hex, .cip105))

            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(coldIdHex.prefix(8))-\(timestamp).committee-cold-resign.cert")
            }

            guard let outFile = certificateOptions.outFile else {
                noora.error(.alert("Output file path is invalid.", takeaways: ["Provide a valid output file path."]))
                throw ExitCode.validationFailure
            }

            do {
                try await FileUtils.checkFile(outFile)
            } catch {
                noora.error(.alert("Output file already exists: \(outFile.string)", takeaways: ["\(error.localizedDescription)"]))
                throw ExitCode.validationFailure
            }

            print(noora.format("\nGenerating committee cold key resignation certificate"))
            print(noora.format("  Cold: \(.primary(try coldCredential.id()))"))
            if let anchor = anchor {
                print(noora.format("  Anchor URL:  \(.primary(anchor.anchorUrl.absoluteString))"))
                print(noora.format("  Anchor Hash: \(.primary(anchor.anchorDataHash.payload.toHex))"))
            }

            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig(), logger: logger)

                    var arguments: [String]
                    switch coldCredential.credential {
                        case .verificationKeyHash(let hash):
                            arguments = ["--cold-key-hash", hash.payload.toHex]
                        case .scriptHash(let hash):
                            arguments = ["--cold-script-hash", hash.payload.toHex]
                    }
                    if let anchor = anchor {
                        arguments.append(contentsOf: [
                            "--resignation-metadata-url", anchor.anchorUrl.absoluteString,
                            "--resignation-metadata-hash", anchor.anchorDataHash.payload.toHex
                        ])
                    }
                    arguments.append(contentsOf: ["--out-file", outFile.string])

                    try await FileUtils.unlockIfExists(outFile)
                    _ = try await cli.governance.committeeResignation(arguments: arguments)
                    try await FileUtils.fileLock(outFile)
                } else {
                    let cert = SwiftCardanoCore.ResignCommitteeCold(
                        committeeColdCredential: coldCredential,
                        anchor: anchor
                    )
                    try cert.save(to: outFile.string, overwrite: true)
                }
            } catch {
                noora.error(.alert(
                    "Could not write certificate file \(.primary(outFile.string))!",
                    takeaways: ["\(error)"]
                ))
                throw ExitCode.failure
            }

            noora.success(.alert(
                "Committee Cold Key Resignation certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "Cold credential: \(.primary(try coldCredential.id()))",
                    "Include this certificate when building your transaction."
                ]
            ))

            try await FileUtils.displayFile(outFile)

            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)

                let loadedCert = try SwiftCardanoCore.ResignCommitteeCold.load(from: outFile.string)
                txBuilder.certificates = [.resignCommitteeCold(loadedCert)]

                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert("Fee payment address is required.", takeaways: ["Provide a valid fee payment address."]))
                    throw ExitCode.validationFailure
                }

                let signingKeys: [String] = [
                    try feePaymentAddress.info.getSigningMethod().path.string
                ]

                noora.warning(.alert(
                    "Remember to also sign with the cold key.",
                    takeaway: "Add the --signing-key-file for your cc-cold.skey when submitting."
                ))

                let protocolParamsFile = cwd.appending("protocol-parameters.json")
                _ = try await getProtocolParameters(context: context, protocolParamsFile: protocolParamsFile)

                let txTimestamp = DateUtils.getCurrentTimestamp()
                let txRawFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).raw.tx")
                let txFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).tx")
                let txSignedFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).signed.tx")

                try await buildTransaction(
                    txBuilder: txBuilder,
                    config: config,
                    witnessOverride: signingKeys.count + 1,
                    protocolParamsFile: protocolParamsFile,
                    txRawFile: txRawFile,
                    txFile: txFile,
                    txSignedFile: txSignedFile
                )

                var args: [String] = []
                if transactionOptions.useCardanoCLI { args.append("--use-cardano-cli") }
                if transactionOptions.save { args.append("--save") }
                if transactionOptions.submit { args.append("--submit") }

                let signingKeysArgs = signingKeys.flatMap { ["--signing-key-file", $0] }
                await TransactionMainCommand.Sign.main([
                    "--tx-file", txFile.string,
                    "--out-file", txSignedFile.string
                ] + args + signingKeysArgs)

                if !transactionOptions.save {
                    try FileManager.default.removeItem(atPath: txRawFile.string)
                    try FileManager.default.removeItem(atPath: txFile.string)
                    try FileManager.default.removeItem(atPath: txSignedFile.string)
                }
            }
        }
    }
}
