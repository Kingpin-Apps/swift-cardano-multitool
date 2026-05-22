import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils


extension TransactionMainCommand {
    struct HashScriptData: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "hash-script-data",
            abstract: "Calculate the hash of script data (datum or redeemer).",
            usage: """
            scm transaction hash-script-data --script-data-file datum.json
            scm transaction hash-script-data --script-data-cbor-file datum.cbor
            scm transaction hash-script-data --script-data-value '{"int": 42}'
            scm transaction hash-script-data --script-data-cbor-hex <hex>
            """,
            discussion: """
            Calculate the blake2b-256 hash of Plutus script data. The script data can be \
            a datum, redeemer, or any arbitrary Plutus data, provided as a CBOR file, \
            a JSON file following the Cardano detailed schema, an inline JSON value, \
            or a raw CBOR hex string.
            Use --tool cardano-cli to delegate hashing to cardano-cli instead of SwiftCardano.
            """,
            aliases: ["hsd"]
        )

        // MARK: - Arguments

        @Option(name: .long, help: "Path to a CBOR file containing the script data.")
        var scriptDataCborFile: FilePath? = nil

        @Option(name: .long, help: "Path to a JSON file containing the script data (Cardano detailed schema).")
        var scriptDataFile: FilePath? = nil

        @Option(name: .long, help: "Inline JSON value of the script data.")
        var scriptDataValue: String? = nil

        @Option(name: .long, help: "Raw CBOR hex string of the script data.")
        var scriptDataCborHex: String? = nil

        @Option(name: .long, help: "Whether to use cardano-cli or SwiftCardano to hash the script data.")
        var tool: Tool = .swiftCardano

        @Flag(name: .shortAndLong, help: "Output as JSON instead of formatted text.")
        var json: Bool = false

        // MARK: - Validation

        mutating func validate() throws {
            let inputs = [
                scriptDataCborFile != nil,
                scriptDataFile != nil,
                scriptDataValue != nil,
                scriptDataCborHex != nil
            ].filter { $0 }

            if inputs.count > 1 {
                throw ValidationError(
                    "Provide only one of --script-data-cbor-file, --script-data-file, --script-data-value, or --script-data-cbor-hex."
                )
            }
        }

        // MARK: - Wizard

        enum ScriptDataInputMethod: String, CaseIterable, AlignedChoiceDescribable {
            case cborFile = "cbor-file"
            case jsonFile = "json-file"
            case jsonValue = "json-value"
            case cborHex = "cbor-hex"

            var name: String {
                switch self {
                    case .cborFile: return "CBOR File"
                    case .jsonFile: return "JSON File"
                    case .jsonValue: return "JSON Value"
                    case .cborHex: return "CBOR Hex"
                }
            }

            var details: String {
                switch self {
                    case .cborFile: return "Provide a CBOR-encoded script data file."
                    case .jsonFile: return "Provide a JSON file following the Cardano detailed datum schema."
                    case .jsonValue: return "Enter a JSON value inline."
                    case .cborHex: return "Enter a raw CBOR hex string."
                }
            }
        }

        mutating func wizard() async throws {
            let method: ScriptDataInputMethod = noora.singleChoicePrompt(
                title: "Script Data Input",
                question: "How would you like to provide the script data?"
            )

            switch method {
                case .cborFile:
                    let path = noora.textPrompt(
                        title: "Script Data CBOR File",
                        prompt: "Enter the path to the script data CBOR file:",
                        validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    scriptDataCborFile = FilePath(path)

                case .jsonFile:
                    let path = noora.textPrompt(
                        title: "Script Data JSON File",
                        prompt: "Enter the path to the script data JSON file:",
                        validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    scriptDataFile = FilePath(path)

                case .jsonValue:
                    scriptDataValue = noora.textPrompt(
                        title: "Script Data JSON Value",
                        prompt: "Enter the script data as a JSON value:",
                        validationRules: [NonEmptyValidationRule(error: "JSON value cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                case .cborHex:
                    scriptDataCborHex = noora.textPrompt(
                        title: "Script Data CBOR Hex",
                        prompt: "Enter the raw CBOR hex string of the script data:",
                        validationRules: [NonEmptyValidationRule(error: "CBOR hex cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            tool = try await getToolToUse()
        }

        // MARK: - Run

        mutating func run() async throws {
            let hasInput = scriptDataCborFile != nil
                || scriptDataFile != nil
                || scriptDataValue != nil
                || scriptDataCborHex != nil

            if !hasInput {
                try await wizard()
            }

            try validate()

            let config = try await MultitoolConfig.load(quiet: json)

            if !json {
                try await printToolInfo(config: config, tool: tool)
            }

            let hash: String

            switch tool {
                case .cardanoCLI:
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig()
                    )

                    var arguments: [String] = []

                    if let file = scriptDataCborFile {
                        arguments += ["--script-data-cbor-file", file.string]
                    } else if let file = scriptDataFile {
                        arguments += ["--script-data-file", file.string]
                    } else if let value = scriptDataValue {
                        arguments += ["--script-data-value", value]
                    } else if let hex = scriptDataCborHex {
                        // Write hex to a temp CBOR file for cardano-cli
                        let tempPath = FileManager.default.temporaryDirectory
                            .appendingPathComponent("\(UUID().uuidString).cbor")
                            .path
                        defer { try? FileManager.default.removeItem(atPath: tempPath) }
                        guard let data = Data(hexString: hex) else {
                            noora.error(.alert(
                                "Invalid CBOR hex string.",
                                takeaways: ["Ensure the hex string is a valid even-length hex-encoded byte sequence."]
                            ))
                            throw ExitCode.validationFailure
                        }
                        try data.write(to: URL(fileURLWithPath: tempPath))
                        arguments += ["--script-data-cbor-file", tempPath]
                    }

                    hash = try await cli.transaction.hashScriptData(arguments: arguments)
                
                case .swiftCardano:
                    let plutusData: PlutusData

                    if let file = scriptDataCborFile {
                        let data = try Data(contentsOf: URL(fileURLWithPath: file.string))
                        plutusData = try PlutusData.fromCBOR(data: data)
                    } else if let file = scriptDataFile {
                        let jsonString = try String(contentsOfFile: file.string, encoding: .utf8)
                        plutusData = try PlutusData.fromJSON(jsonString)
                    } else if let value = scriptDataValue {
                        plutusData = try parsePlutusDataFromValue(value)
                    } else if let hex = scriptDataCborHex {
                        plutusData = try PlutusData.fromCBORHex(hex)
                    } else {
                        noora.error("Script data input is required.")
                        throw ExitCode.validationFailure
                    }

                    let datumHashValue = try plutusData.hash()
                    hash = datumHashValue.payload.toHex
            }

            if !json {
                spacedPrint(
                    "Script data hash (\(.muted("using \(tool.description)"))): \(.primary(hash))"
                )
            } else {
                let outputJSON = try JSONSerialization.data(
                    withJSONObject: ["hash": hash],
                    options: [.prettyPrinted, .withoutEscapingSlashes]
                )
                print(String(data: outputJSON, encoding: .utf8) ?? "{}", terminator: "\n\n")
            }
        }
        // MARK: - Private Helpers

        /// Parses a PlutusData value from a JSON string, supporting both the Cardano
        /// detailed schema (e.g. `{"int": 12}`) and bare JSON primitives (e.g. `12`).
        /// `PlutusData.fromJSON` uses `JSONSerialization` without `.allowFragments` so
        /// bare top-level numbers/strings fail without this wrapper.
        private func parsePlutusDataFromValue(_ value: String) throws -> PlutusData {
            guard let data = value.data(using: .utf8) else {
                noora.error("Invalid string encoding for script data value.")
                throw ExitCode.validationFailure
            }

            let fragment = try JSONSerialization.jsonObject(with: data, options: .allowFragments)

            // Bare integer (e.g. `12`, `-5`) → PlutusData.bigInt
            if let num = fragment as? Int {
                return .bigInt(.int(Int64(num)))
            }

            // Object or array — delegate to the schema-aware parser
            return try PlutusData.fromJSON(value)
        }
    }
}
