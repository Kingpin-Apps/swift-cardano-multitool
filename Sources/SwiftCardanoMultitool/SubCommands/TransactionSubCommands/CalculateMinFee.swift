import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoUtils
import SwiftCardanoTxBuilder


extension TransactionMainCommand {
    struct CalculateMinFee: TransactionAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "calculate-min-fee",
            abstract: "Calculate the minimum transaction fee.",
            usage: """
            scm transaction calculate-min-fee --tx-file test.tx --witness-count 1
            scm transaction calculate-min-fee --cbor-hex 84a5... --witness-count 2 --reference-script-size 512
            """,
            discussion: """
            Calculate the minimum fee for a Cardano transaction body. Requires a transaction \
            file or raw CBOR hex, the number of key witnesses that will sign the transaction, \
            and access to the configured chain context for protocol parameters.
            Use --tool cardano-cli to delegate calculation to cardano-cli instead of SwiftCardano.
            """,
            aliases: ["min-fee"]
        )

        // MARK: - Arguments

        @Option(name: [.short, .long], help: "The file path to the transaction file.")
        var txFile: FilePath?

        @Option(name: .long, help: "Raw CBOR hex string of the transaction.")
        var cborHex: String?

        @Option(name: .shortAndLong, help: "The number of Shelley key witnesses that will sign the transaction.")
        var witnessCount: Int?

        @Option(name: .long, help: "Total size in bytes of transaction reference scripts (default is 0).")
        var referenceScriptSize: Int = 0

        @Option(name: .long, help: "Whether to use cardano-cli or SwiftCardano to calculate the fee.")
        var tool: Tool = .swiftCardano

        @Flag(name: .shortAndLong, help: "Output as JSON instead of formatted text.")
        var json: Bool = false

        // MARK: - Wizard

        mutating func wizard() async throws {
            let enterTransactionBy = try await getTransactionBy()

            switch enterTransactionBy {
                case .cborHex:
                    cborHex = noora.textPrompt(
                        title: "Transaction CBOR Hex",
                        prompt: "Enter the raw CBOR hex string of the transaction:",
                        validationRules: [NonEmptyValidationRule(error: "CBOR hex cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                case .path:
                    txFile = try await getTransactionFilePath(title: "Select a transaction file.")
            }

            let witnessCountStr = noora.textPrompt(
                title: "Witness Count",
                prompt: "Enter the number of key witnesses that will sign the transaction:",
                validationRules: [NonEmptyValidationRule(error: "Witness count cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let count = Int(witnessCountStr), count >= 0 else {
                noora.error(.alert("Invalid witness count.", takeaways: ["Please enter a non-negative integer."]))
                throw ExitCode.validationFailure
            }
            witnessCount = count

            let refScriptSizeStr = noora.textPrompt(
                title: "Reference Script Size",
                prompt: "Enter the total size in bytes of reference scripts (leave blank for 0):",
                collapseOnAnswer: true
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            if !refScriptSizeStr.isEmpty {
                guard let size = Int(refScriptSizeStr), size >= 0 else {
                    noora.error(.alert("Invalid reference script size.", takeaways: ["Please enter a non-negative integer."]))
                    throw ExitCode.validationFailure
                }
                referenceScriptSize = size
            }

            tool = try await getToolToUse()
        }

        // MARK: - Run

        mutating func run() async throws {
            if (txFile == nil && cborHex == nil) || witnessCount == nil {
                try await wizard()
            }

            guard let witnessCount = witnessCount else {
                noora.error("Witness count is required.")
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load(quiet: json)
            let context = try await getContext(config: config)

            if !json {
                try await printToolInfo(config: config, tool: tool)
            }

            let fee: UInt64

            switch tool {
                case .swiftCardano:
                    let tx = try resolveTransaction()
                    let txLength = UInt64(try tx.toCBORData().count)
                    fee = try await Utils.calculateFee(
                        context,
                        length: txLength,
                        refScriptSize: UInt64(referenceScriptSize)
                    )

                case .cardanoCLI:
                    let tempDir = FileManager.default.temporaryDirectory.path
                    let protocolParamsFile = FilePath("\(tempDir)/protocol-params-\(UUID().uuidString).json")
                    defer { try? FileManager.default.removeItem(atPath: protocolParamsFile.string) }

                    _ = try await getProtocolParameters(
                        context: context,
                        protocolParamsFile: protocolParamsFile,
                        quiet: json
                    )

                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig()
                    )

                    let result = try await cli.transaction.calculateMinFee(arguments: [
                        "--output-text",
                        "--tx-body-file", (try await effectiveTxFile).string,
                        "--protocol-params-file", protocolParamsFile.string,
                        "--witness-count", "\(witnessCount)",
                        "--reference-script-size", "\(referenceScriptSize)"
                    ])

                    fee = UInt64(result)
            }

            if !json {
                spacedPrint(
                    "Minimum fee (\(.muted("using \(tool.description)"))): \(.primary("\(fee)")) lovelace / \(.primary(lovelaceToAdaFormatString(fee))) ADA"
                )
            } else {
                let outputJSON = try JSONSerialization.data(
                    withJSONObject: ["fee": fee],
                    options: [.prettyPrinted, .withoutEscapingSlashes]
                )
                print(String(data: outputJSON, encoding: .utf8) ?? "{}", terminator: "\n\n")
            }
        }
    }
}
