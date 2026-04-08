import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension CertificateMainCommand {

    struct UpdateDRepCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            commandName: "update-drep",
            abstract: "Generates a DRep update certificate.",
            usage: """
            scm certificate update-drep --drep-credential drep1abc
            """,
            discussion: """
            Creates a DRep update certificate that updates the metadata anchor
            of an already-registered Delegation Representative. An optional
            anchor (URL + metadata hash) can be provided to update the off-chain
            metadata reference (CIP-100). If the `--generate-transaction` flag
            is used, a transaction will also be created to submit the certificate
            on-chain.
            """,
            aliases: ["drep-update"]
        )

        // MARK: - Required Arguments

        @Option(name: .long, help: "DRep credential. Supports: bech32 (drep1...), hex hash, .drep.vkey file.")
        var drepCredential: DRepCredential?

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
            drepCredential = try await getDRepCredential(title: "DRep Credential to Update")
            try await self.wizardForCertificate()
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if drepCredential == nil {
                try await wizard()
            }

            guard let drepCredential = drepCredential else {
                noora.error(.alert("DRep credential is required.", takeaways: ["Provide a valid DRep credential."]))
                throw ExitCode.validationFailure
            }

            let anchor = try await getOptionalAnchor(purpose: "DRep update")

            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let timestamp = DateUtils.getCurrentTimestamp()
            let drepIdHex = try drepCredential.id((.hex, .cip105))

            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(drepIdHex.prefix(8))-\(timestamp).drep-update.cert")
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

            print(noora.format("\nGenerating DRep update certificate"))
            print(noora.format("  DRep: \(.primary(try drepCredential.id()))"))
            if let anchor = anchor {
                print(noora.format("  Anchor URL:  \(.primary(anchor.anchorUrl.absoluteString))"))
                print(noora.format("  Anchor Hash: \(.primary(anchor.anchorDataHash.payload.toHex))"))
            }

            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig(), logger: logger)

                    var arguments: [String]
                    switch drepCredential.credential {
                        case .verificationKeyHash(let hash):
                            arguments = ["--drep-key-hash", hash.payload.toHex]
                        case .scriptHash(let hash):
                            arguments = ["--drep-script-hash", hash.payload.toHex]
                    }
                    if let anchor = anchor {
                        arguments.append(contentsOf: [
                            "--drep-metadata-url", anchor.anchorUrl.absoluteString,
                            "--drep-metadata-hash", anchor.anchorDataHash.payload.toHex
                        ])
                    }
                    arguments.append(contentsOf: ["--out-file", outFile.string])

                    try await FileUtils.unlockIfExists(outFile)
                    _ = try await cli.governance.drepUpdate(arguments: arguments)
                    try await FileUtils.fileLock(outFile)
                } else {
                    let cert = SwiftCardanoCore.UpdateDRep(
                        drepCredential: drepCredential,
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
                "DRep Update certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "DRep: \(.primary(try drepCredential.id()))",
                    "Include this certificate when building your transaction."
                ]
            ))

            try await FileUtils.displayFile(outFile)

            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)

                let loadedCert = try SwiftCardanoCore.UpdateDRep.load(from: outFile.string)
                txBuilder.certificates = [.updateDRep(loadedCert)]

                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert("Fee payment address is required.", takeaways: ["Provide a valid fee payment address."]))
                    throw ExitCode.validationFailure
                }

                let signingKeys: [String] = [
                    try feePaymentAddress.info.getSigningMethod().path.string
                ]

                noora.warning(.alert(
                    "Remember to also sign with the DRep key.",
                    takeaway: "Add the --signing-key-file for your .drep.skey when submitting."
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
