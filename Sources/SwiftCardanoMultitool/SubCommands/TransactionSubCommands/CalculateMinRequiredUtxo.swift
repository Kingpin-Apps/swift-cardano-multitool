import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoUtils
import SwiftCardanoTxBuilder


extension TransactionMainCommand {
    struct CalculateMinRequiredUtxo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "calculate-min-required-utxo",
            abstract: "Calculate the minimum required UTxO for a transaction output.",
            usage: """
            scm transaction calculate-min-required-utxo --tx-out-address addr1... --tx-out-value "2000000 lovelace"
            """,
            discussion: """
            Calculate the minimum lovelace a transaction output must contain. Provide a recipient \
            address and a value string. Optionally attach a datum or reference script to model \
            a more complex output. Protocol parameters are fetched from the configured chain context.
            Use --tool cardano-cli to delegate calculation to cardano-cli instead of SwiftCardano.
            """,
            aliases: ["min-utxo"]
        )

        // MARK: - Arguments

        @Option(name: .long, help: "The recipient address (bech32).")
        var txOutAddress: String?

        @Option(name: .long, help: "The value for the output in multi-asset syntax, e.g. \"2000000 lovelace\".")
        var txOutValue: String?

        @Option(name: .long, help: "Datum hash (hex) for the transaction output.")
        var txOutDatumHash: String? = nil

        @Option(name: .long, help: "Path to a JSON datum file to hash for the transaction output.")
        var txOutDatumHashFile: FilePath? = nil

        @Option(name: .long, help: "Path to a JSON inline datum file for the transaction output.")
        var txOutInlineDatumFile: FilePath? = nil

        @Option(name: .long, help: "Inline datum JSON value for the transaction output.")
        var txOutInlineDatumValue: String? = nil

        @Option(name: .long, help: "Path to a reference script file for the transaction output.")
        var txOutReferenceScriptFile: FilePath? = nil

        @Option(name: .long, help: "Whether to use cardano-cli or SwiftCardano to calculate the minimum UTxO.")
        var tool: Tool = .swiftCardano

        @Flag(name: .shortAndLong, help: "Output as JSON instead of formatted text.")
        var json: Bool = false

        // MARK: - Wizard

        mutating func wizard() async throws {
            txOutAddress = noora.textPrompt(
                title: "Recipient Address",
                prompt: "Enter the recipient address (bech32):",
                validationRules: [NonEmptyValidationRule(error: "Address cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            txOutValue = noora.textPrompt(
                title: "Output Value",
                prompt: "Enter the output value (e.g. \"2000000 lovelace\"):",
                validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            let hasDatum = noora.yesOrNoChoicePrompt(
                title: "Datum",
                question: "Does this output have a datum?",
                defaultAnswer: false
            )

            if hasDatum {
                enum DatumInputMethod: String, CaseIterable, AlignedChoiceDescribable {
                    case hash = "datum-hash"
                    case hashFile = "datum-hash-file"
                    case inlineFile = "inline-datum-file"
                    case inlineValue = "inline-datum-value"

                    var name: String {
                        switch self {
                            case .hash: return "Datum Hash"
                            case .hashFile: return "Datum Hash File"
                            case .inlineFile: return "Inline Datum File"
                            case .inlineValue: return "Inline Datum Value"
                        }
                    }

                    var details: String {
                        switch self {
                            case .hash: return "Provide a raw datum hash hex string."
                            case .hashFile: return "Hash the datum from a JSON file."
                            case .inlineFile: return "Embed datum from a JSON file."
                            case .inlineValue: return "Embed datum as a JSON value."
                        }
                    }
                }

                let datumMethod: DatumInputMethod = noora.singleChoicePrompt(
                    title: "Datum Input Method",
                    question: "How would you like to specify the datum?"
                )

                switch datumMethod {
                    case .hash:
                        txOutDatumHash = noora.textPrompt(
                            title: "Datum Hash",
                            prompt: "Enter the datum hash (hex):",
                            validationRules: [NonEmptyValidationRule(error: "Datum hash cannot be empty.")]
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                    case .hashFile:
                        txOutDatumHashFile = FilePath(noora.textPrompt(
                            title: "Datum Hash File",
                            prompt: "Enter the path to the JSON datum file:",
                            validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                        ).trimmingCharacters(in: .whitespacesAndNewlines))
                    case .inlineFile:
                        txOutInlineDatumFile = FilePath(noora.textPrompt(
                            title: "Inline Datum File",
                            prompt: "Enter the path to the inline datum JSON file:",
                            validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                        ).trimmingCharacters(in: .whitespacesAndNewlines))
                    case .inlineValue:
                        txOutInlineDatumValue = noora.textPrompt(
                            title: "Inline Datum Value",
                            prompt: "Enter the inline datum as a JSON value:",
                            validationRules: [NonEmptyValidationRule(error: "Datum value cannot be empty.")]
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            let hasRefScript = noora.yesOrNoChoicePrompt(
                title: "Reference Script",
                question: "Does this output have a reference script?",
                defaultAnswer: false
            )

            if hasRefScript {
                txOutReferenceScriptFile = FilePath(noora.textPrompt(
                    title: "Reference Script File",
                    prompt: "Enter the path to the reference script file:",
                    validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            tool = try await getToolToUse()
        }

        // MARK: - Run

        mutating func run() async throws {
            if txOutAddress == nil || txOutValue == nil {
                try await wizard()
            }

            guard let addressString = txOutAddress, let valueString = txOutValue else {
                noora.error("Address and value are required.")
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load(quiet: json)
            let context = try await getContext(config: config)

            if !json {
                try await printToolInfo(config: config, tool: tool)
            }

            let minUtxo: UInt64

            switch tool {
                case .swiftCardano:
                    let address = try SwiftCardanoCore.Address(from: .string(addressString))

                    // Parse lovelace from value string (e.g. "2000000 lovelace" or "2000000")
                    let lovelace = parseLovelaceFromValueString(valueString)
                    let output = TransactionOutput(
                        address: address,
                        amount: Value(coin: Int(lovelace))
                    )

                    minUtxo = try await Utils.minLovelacePostAlonzo(output, context)

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

                    var arguments: [String] = [
                        "--protocol-params-file", protocolParamsFile.string,
                        "--tx-out", "\(addressString) \(valueString)"
                    ]

                    if let hash = txOutDatumHash {
                        arguments += ["--tx-out-datum-hash", hash]
                    }
                    if let file = txOutDatumHashFile {
                        arguments += ["--tx-out-datum-hash-file", file.string]
                    }
                    if let file = txOutInlineDatumFile {
                        arguments += ["--tx-out-inline-datum-file", file.string]
                    }
                    if let value = txOutInlineDatumValue {
                        arguments += ["--tx-out-inline-datum-value", value]
                    }
                    if let file = txOutReferenceScriptFile {
                        arguments += ["--tx-out-reference-script-file", file.string]
                    }

                    minUtxo = UInt64(try await cli.transaction.calculateMinRequiredUtxo(arguments: arguments))
            }

            if !json {
                spacedPrint(
                    "Minimum required UTxO (\(.muted("using \(tool.description)"))): \(.primary("\(minUtxo)")) lovelace / \(.primary(lovelaceToAdaFormatString(minUtxo))) ADA"
                )
            } else {
                let outputJSON = try JSONSerialization.data(
                    withJSONObject: ["minRequiredUtxo": minUtxo],
                    options: [.prettyPrinted, .withoutEscapingSlashes]
                )
                print(String(data: outputJSON, encoding: .utf8) ?? "{}", terminator: "\n\n")
            }
        }

        // MARK: - Private Helpers

        private func parseLovelaceFromValueString(_ valueString: String) -> UInt64 {
            // Handles "2000000 lovelace", "2000000", "2000000lovelace"
            let trimmed = valueString.trimmingCharacters(in: .whitespaces)
            let digits = trimmed.prefix(while: { $0.isNumber })
            return UInt64(digits) ?? 0
        }
    }
}
