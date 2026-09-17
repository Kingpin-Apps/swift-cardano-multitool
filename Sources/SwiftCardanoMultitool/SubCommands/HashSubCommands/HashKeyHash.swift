import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

extension HashMainCommand {

    struct PaymentKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "payment-key",
            abstract: "Print the hash of a payment verification key.",
            usage: """
            scm hash payment-key --payment-verification-key-file alice.payment.vkey
            scm hash payment-key --payment-verification-key addr_vk1…
            scm hash payment-key --address-name alice
            scm hash payment-key --address addr1v9dj7z3r5k96dqk8kjre7kzhlzete4crejyl3hm754a3dlss0ue7p
            """,
            discussion: """
            Equivalent to 'cardano-cli address key-hash'. Extended keys are hashed
            over their 32-byte public key, so a key and its extended form give the same hash.
            With --address the payment credential is read from an address instead; for a
            script address that is the script hash.
            """,
            aliases: ["address-key"]
        )

        @Option(name: .customLong("payment-verification-key"), help: "Payment verification key (Bech32 addr_vk1…/addr_xvk1… or hex).")
        var verificationKey: String? = nil

        @Option(name: [.customShort("f"), .customLong("payment-verification-key-file")], help: "Filepath of the payment verification key.")
        var verificationKeyFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Address name; hashes '<name>.payment.vkey' in the current directory.")
        var addressName: String? = nil

        @Option(name: .customLong("address"), help: "Payment address to read the payment credential from: Bech32 (addr1…), an address file, or an address name.")
        var address: String? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        mutating func run() async throws {
            var input = KeyHashInput(
                role: .payment,
                verificationKey: verificationKey, verificationKeyFile: verificationKeyFile,
                name: addressName, tool: tool,
                textFlag: "--payment-verification-key", fileFlag: "--payment-verification-key-file",
                nameFlag: "--address-name", nameSuffix: ".payment.vkey",
                address: address, addressFlag: "--address"
            )
            let key: KeyHashInput.ResolvedKey
            switch try await input.resolveSource() {
                case .address(let text):
                    try await input.emitAddressCredential(text, part: .payment, outFile: outFile)
                    return
                case .key(let resolved):
                    key = resolved
            }
            let hash: String
            switch input.resolvedTool {
                case .cardanoCLI:
                    let cli = try await HashUtils.cardanoCLI()
                    hash = try await cli.address.keyHash(arguments: input.cliArguments(key)).trimmed
                case .swiftCardano:
                    hash = try HashUtils.verificationKeyHash(payload: key.payload)
            }
            try HashUtils.emit(HashReport(
                title: "Payment Key Hash",
                summary: "Hashing a payment verification key",
                inputs: input.inputDetails(key),
                method: input.keyHashMethod(key),
                hash: hash, tool: input.resolvedTool, outFile: outFile
            ))
        }
    }

    struct StakeKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stake-key",
            abstract: "Print the hash of a stake verification key.",
            usage: """
            scm hash stake-key --stake-verification-key-file alice.stake.vkey
            scm hash stake-key --stake-verification-key stake_vk1…
            scm hash stake-key --address-name alice
            scm hash stake-key --stake-address stake1uyehkck0lajq8gr28t9uxnuvgcqrc6070x3k9r8048z8y5gh6ffgw
            """,
            discussion: """
            Equivalent to 'cardano-cli stake-address key-hash'. Extended keys are hashed
            over their 32-byte public key, so a key and its extended form give the same hash.
            With --stake-address the stake credential is read from a stake address or a base
            payment address instead; for a script credential that is the script hash.
            """,
            aliases: ["stake-address-key"]
        )

        @Option(name: .customLong("stake-verification-key"), help: "Stake verification key (Bech32 stake_vk1…/stake_xvk1… or hex).")
        var verificationKey: String? = nil

        @Option(name: [.customShort("f"), .customLong("stake-verification-key-file")], help: "Filepath of the stake verification key.")
        var verificationKeyFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Address name; hashes '<name>.stake.vkey' in the current directory.")
        var addressName: String? = nil

        @Option(name: .customLong("stake-address"), help: "Stake address (stake1…) or base payment address (addr1…) to read the stake credential from; also an address file or name.")
        var stakeAddress: String? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        mutating func run() async throws {
            var input = KeyHashInput(
                role: .stake,
                verificationKey: verificationKey, verificationKeyFile: verificationKeyFile,
                name: addressName, tool: tool,
                textFlag: "--stake-verification-key", fileFlag: "--stake-verification-key-file",
                nameFlag: "--address-name", nameSuffix: ".stake.vkey",
                address: stakeAddress, addressFlag: "--stake-address"
            )
            let key: KeyHashInput.ResolvedKey
            switch try await input.resolveSource() {
                case .address(let text):
                    try await input.emitAddressCredential(text, part: .stake, outFile: outFile)
                    return
                case .key(let resolved):
                    key = resolved
            }
            let hash: String
            switch input.resolvedTool {
                case .cardanoCLI:
                    let cli = try await HashUtils.cardanoCLI()
                    hash = try await cli.stakeAddress.keyHash(arguments: input.cliArguments(key)).trimmed
                case .swiftCardano:
                    hash = try HashUtils.verificationKeyHash(payload: key.payload)
            }
            try HashUtils.emit(HashReport(
                title: "Stake Key Hash",
                summary: "Hashing a stake verification key",
                inputs: input.inputDetails(key),
                method: input.keyHashMethod(key),
                hash: hash, tool: input.resolvedTool, outFile: outFile
            ))
        }
    }

    struct DRepKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "drep-key",
            abstract: "Print the key hash or ID of a DRep verification key.",
            usage: """
            scm hash drep-key --drep-verification-key-file myDRep.drep.vkey
            scm hash drep-key --drep-verification-key drep_vk1… --output-cip129
            scm hash drep-key --drep-key-hash drep1… --output-hex
            """,
            discussion: """
            Equivalent to 'cardano-cli governance drep id'. Prints the key hash (hex) by
            default; --output-bech32 prints the CIP-105 DRep ID and --output-cip129 the
            CIP-129 DRep ID. --drep-key-hash converts between the formats.
            """,
            aliases: ["drep-id"]
        )

        enum OutputFormat: String, EnumerableFlag {
            case outputHex, outputBech32, outputCip129

            static func help(for value: OutputFormat) -> ArgumentHelp? {
                switch value {
                    case .outputHex: return "Output the key hash as hex (default)."
                    case .outputBech32: return "Output the CIP-105 DRep ID (drep1…)."
                    case .outputCip129: return "Output the CIP-129 DRep ID (drep1…)."
                }
            }
        }

        @Option(name: .customLong("drep-verification-key"), help: "DRep verification key (Bech32 drep_vk1…/drep_xvk1… or hex).")
        var verificationKey: String? = nil

        @Option(name: [.customShort("f"), .customLong("drep-verification-key-file")], help: "Filepath of the DRep verification key.")
        var verificationKeyFile: FilePath? = nil

        @Option(name: .customLong("drep-key-hash"), help: "DRep key hash (hex) or DRep ID (CIP-105 or CIP-129 drep1…).")
        var drepKeyHash: String? = nil

        @Option(name: .shortAndLong, help: "DRep name; hashes '<name>.drep.vkey' in the current directory.")
        var drepName: String? = nil

        @Flag var output: OutputFormat = .outputHex

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        mutating func run() async throws {
            var input = KeyHashInput(
                role: .drep,
                verificationKey: verificationKey, verificationKeyFile: verificationKeyFile,
                name: drepName, tool: tool,
                textFlag: "--drep-verification-key", fileFlag: "--drep-verification-key-file",
                nameFlag: "--drep-name", nameSuffix: ".drep.vkey",
                alternativeFlag: "--drep-key-hash", alternativeProvided: drepKeyHash != nil
            )

            let keyHash: Data
            var key: KeyHashInput.ResolvedKey? = nil
            do {
                if let drepKeyHash {
                    try input.checkSingleSource()
                    input.resolvedTool = try await resolveTool(tool)
                    keyHash = try HashUtils.drepKeyHash(from: drepKeyHash)
                } else {
                    let resolved = try await input.resolve()
                    key = resolved
                    keyHash = try Data(hexString: HashUtils.verificationKeyHash(payload: resolved.payload)) ?? Data()
                }
            } catch let error as ExitCode {
                throw error
            } catch {
                noora.error(.alert("Could not read the DRep key.", takeaways: ["\(error.localizedDescription)"]))
                throw ExitCode.failure
            }

            let ids = try HashUtils.drepIds(keyHash: keyHash)
            let value: String
            switch input.resolvedTool {
                case .cardanoCLI:
                    let cli = try await HashUtils.cardanoCLI()
                    let source = try key.map { try input.cliArguments($0) } ?? ["--drep-key-hash", keyHash.toHex]
                    let flag = "--" + [OutputFormat.outputHex: "output-hex", .outputBech32: "output-bech32", .outputCip129: "output-cip129"][output]!
                    value = try await cli.governance.drepId(arguments: source + [flag]).trimmed
                case .swiftCardano:
                    switch output {
                        case .outputHex: value = ids.hex
                        case .outputBech32: value = ids.cip105
                        case .outputCip129: value = ids.cip129
                    }
            }

            let label = [OutputFormat.outputHex: "DRep Key Hash", .outputBech32: "DRep ID (CIP-105)", .outputCip129: "DRep ID (CIP-129)"][output]!
            let encoding = [
                OutputFormat.outputHex: "hex",
                .outputBech32: "Bech32 drep1… (CIP-105: the key hash)",
                .outputCip129: "Bech32 drep1… (CIP-129: header byte 0x22 + the key hash)",
            ][output]!
            var inputs: [(String, String)]
            let method: String
            if let key {
                inputs = input.inputDetails(key)
                method = "\(input.keyHashMethod(key)), shown as \(encoding)"
            } else {
                inputs = [("DRep key hash or ID", drepKeyHash ?? "")]
                method = "Decoded to the 28-byte key hash, shown as \(encoding)"
            }
            try HashUtils.emit(HashReport(
                title: label,
                summary: key == nil ? "Converting a DRep key hash or ID" : "Hashing a DRep verification key",
                inputs: inputs,
                method: method,
                hash: value,
                related: [("DRep Key Hash", ids.hex), ("DRep ID (CIP-105)", ids.cip105), ("DRep ID (CIP-129)", ids.cip129)],
                tool: input.resolvedTool, outFile: outFile
            ))
        }
    }

    struct CommitteeKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "committee-key",
            abstract: "Print the hash of a constitutional committee hot or cold verification key.",
            usage: """
            scm hash committee-key --verification-key-file cc.hot.vkey
            scm hash committee-key --verification-key cc_cold_vk1…
            """,
            discussion: """
            Equivalent to 'cardano-cli governance committee key-hash'. The terminal output
            also shows the CIP-129 committee ID.
            """
        )

        @Option(name: .customLong("verification-key"), help: "Committee hot or cold verification key (Bech32 cc_hot_vk1…/cc_cold_vk1… or hex).")
        var verificationKey: String? = nil

        @Option(name: [.customShort("f"), .customLong("verification-key-file")], help: "Filepath of the committee hot or cold verification key.")
        var verificationKeyFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        mutating func run() async throws {
            var input = KeyHashInput(
                role: .committee,
                verificationKey: verificationKey, verificationKeyFile: verificationKeyFile,
                name: nil, tool: tool,
                textFlag: "--verification-key", fileFlag: "--verification-key-file"
            )
            let key = try await input.resolve()
            let hash: String
            switch input.resolvedTool {
                case .cardanoCLI:
                    let cli = try await HashUtils.cardanoCLI()
                    hash = try await cli.governance.committeeKeyHash(arguments: input.cliArguments(key)).trimmed
                case .swiftCardano:
                    hash = try HashUtils.verificationKeyHash(payload: key.payload)
            }

            var related: [(String, String)] = []
            if let hashData = Data(hexString: hash) {
                let keyHash = VerificationKeyHash(payload: hashData)
                if key.isCold {
                    related.append(("Committee Cold ID", try CommitteeColdCredential(credential: .verificationKeyHash(keyHash)).id()))
                } else if key.isHot {
                    related.append(("Committee Hot ID", try CommitteeHotCredential(credential: .verificationKeyHash(keyHash)).id()))
                }
            }
            try HashUtils.emit(HashReport(
                title: "Committee Key Hash",
                summary: "Hashing a constitutional committee \(key.isCold ? "cold" : key.isHot ? "hot" : "") verification key"
                    .replacingOccurrences(of: "  ", with: " "),
                inputs: input.inputDetails(key),
                method: input.keyHashMethod(key),
                hash: hash, related: related, tool: input.resolvedTool, outFile: outFile
            ))
        }
    }

    struct VRFKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "vrf-key",
            abstract: "Print the hash of a node's VRF verification key.",
            usage: """
            scm hash vrf-key --verification-key-file mypool.vrf.vkey
            scm hash vrf-key --verification-key vrf_vk1…
            """,
            discussion: """
            Equivalent to 'cardano-cli node key-hash-VRF'. Prints the 32-byte VRF key hash
            registered in the pool parameters.
            """
        )

        @Option(name: .customLong("verification-key"), help: "VRF verification key (Bech32 vrf_vk1… or hex).")
        var verificationKey: String? = nil

        @Option(name: [.customShort("f"), .customLong("verification-key-file")], help: "Filepath of the VRF verification key.")
        var verificationKeyFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Pool name; hashes '<name>.vrf.vkey' in the current directory.")
        var poolName: String? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        mutating func run() async throws {
            var input = KeyHashInput(
                role: .vrf,
                verificationKey: verificationKey, verificationKeyFile: verificationKeyFile,
                name: poolName, tool: tool,
                textFlag: "--verification-key", fileFlag: "--verification-key-file",
                nameFlag: "--pool-name", nameSuffix: ".vrf.vkey"
            )
            let key = try await input.resolve()
            let hash: String
            switch input.resolvedTool {
                case .cardanoCLI:
                    let cli = try await HashUtils.cardanoCLI()
                    // The utils wrapper only takes a file, so a key given as text goes through a temporary one.
                    let file = try key.file ?? HashUtils.temporaryKeyFile(type: "VrfVerificationKey_PraosVRF", payload: key.payload)
                    defer { if key.file == nil { try? FileManager.default.removeItem(atPath: file.string) } }
                    hash = try await cli.node.keyHashVRF(verificationKeyFile: file.string).trimmed
                case .swiftCardano:
                    hash = try HashUtils.verificationKeyHash(payload: key.payload, role: .vrf)
            }
            try HashUtils.emit(HashReport(
                title: "VRF Key Hash",
                summary: "Hashing a VRF verification key",
                inputs: input.inputDetails(key),
                method: "blake2b-256 of the 32-byte VRF verification key → 32-byte VRF key hash",
                hash: hash, tool: input.resolvedTool, outFile: outFile
            ))
        }
    }

    struct PoolId: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "pool-id",
            abstract: "Print the pool ID of a stake pool cold verification key.",
            usage: """
            scm hash pool-id --cold-verification-key-file mypool.node.vkey
            scm hash pool-id --stake-pool-verification-key pool_vk1… --output-hex
            scm hash pool-id --pool-name mypool
            """,
            discussion: """
            Equivalent to 'cardano-cli stake-pool id'. The pool ID is the hash of the
            cold verification key, printed as Bech32 (pool1…) by default.
            """,
            aliases: ["stake-pool-id"]
        )

        enum OutputFormat: String, EnumerableFlag {
            case outputBech32, outputHex

            static func help(for value: OutputFormat) -> ArgumentHelp? {
                switch value {
                    case .outputBech32: return "Output the pool ID as Bech32 (default)."
                    case .outputHex: return "Output the pool ID as hex."
                }
            }
        }

        @Option(name: .customLong("stake-pool-verification-key"), help: "Stake pool verification key (Bech32 pool_vk1… or hex).")
        var verificationKey: String? = nil

        @Option(name: .customLong("stake-pool-verification-extended-key"), help: "Stake pool verification extended key (Bech32 pool_xvk1… or hex).")
        var extendedVerificationKey: String? = nil

        @Option(name: [.customShort("f"), .customLong("cold-verification-key-file")], help: "Filepath of the stake pool cold verification key.")
        var verificationKeyFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Pool name; hashes '<name>.node.vkey' in the current directory.")
        var poolName: String? = nil

        @Flag var output: OutputFormat = .outputBech32

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        func validate() throws {
            if verificationKey != nil && extendedVerificationKey != nil {
                throw ValidationError("Provide only one of --stake-pool-verification-key or --stake-pool-verification-extended-key.")
            }
        }

        mutating func run() async throws {
            var input = KeyHashInput(
                role: .stakePool,
                verificationKey: verificationKey ?? extendedVerificationKey, verificationKeyFile: verificationKeyFile,
                name: poolName, tool: tool,
                textFlag: extendedVerificationKey != nil ? "--stake-pool-verification-extended-key" : "--stake-pool-verification-key",
                fileFlag: "--cold-verification-key-file",
                nameFlag: "--pool-name", nameSuffix: ".node.vkey"
            )
            let key = try await input.resolve()
            let keyHash = try HashUtils.verificationKeyHash(payload: key.payload)
            let ids = try HashUtils.poolIds(keyHash: Data(hexString: keyHash) ?? Data())

            let value: String
            switch input.resolvedTool {
                case .cardanoCLI:
                    let cli = try await HashUtils.cardanoCLI()
                    var arguments = try input.cliArguments(key)
                    if key.file == nil {
                        let flag = key.payload.count == 64 ? "--stake-pool-verification-extended-key" : "--stake-pool-verification-key"
                        arguments[0] = flag
                    }
                    arguments.append(output == .outputHex ? "--output-hex" : "--output-bech32")
                    value = try await cli.stakePool.id(arguments: arguments).trimmed
                case .swiftCardano:
                    value = output == .outputHex ? ids.hex : ids.bech32
            }
            try HashUtils.emit(HashReport(
                title: output == .outputHex ? "Pool ID (hex)" : "Pool ID",
                summary: "Hashing a stake pool cold verification key",
                inputs: input.inputDetails(key),
                method: "\(input.keyHashMethod(key)), shown as \(output == .outputHex ? "hex" : "Bech32 pool1…")",
                hash: value,
                related: [("Pool ID", ids.bech32), ("Pool ID (hex)", ids.hex)],
                tool: input.resolvedTool, outFile: outFile
            ))
        }
    }

    struct GenesisKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "genesis-key",
            abstract: "Print the hash of a genesis, genesis delegate or genesis UTxO verification key.",
            usage: """
            scm hash genesis-key --verification-key-file genesis1.vkey
            """,
            discussion: """
            Equivalent to 'cardano-cli genesis key-hash'.
            """
        )

        @Option(name: [.customShort("f"), .customLong("verification-key-file")], help: "Filepath of the genesis, genesis delegate or genesis UTxO verification key.")
        var verificationKeyFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        mutating func run() async throws {
            var input = KeyHashInput(
                role: .genesis,
                verificationKey: nil, verificationKeyFile: verificationKeyFile,
                name: nil, tool: tool,
                textFlag: nil, fileFlag: "--verification-key-file"
            )
            let key = try await input.resolve()
            let hash: String
            switch input.resolvedTool {
                case .cardanoCLI:
                    let cli = try await HashUtils.cardanoCLI()
                    hash = try await cli.genesis.keyHash(arguments: input.cliArguments(key)).trimmed
                case .swiftCardano:
                    hash = try HashUtils.verificationKeyHash(payload: key.payload)
            }
            try HashUtils.emit(HashReport(
                title: "Genesis Key Hash",
                summary: "Hashing a genesis verification key",
                inputs: input.inputDetails(key),
                method: input.keyHashMethod(key),
                hash: hash, tool: input.resolvedTool, outFile: outFile
            ))
        }
    }
}

/// Shared input handling for the key hash commands: exactly one of a key given as text,
/// a key file or a key base name, collected by a wizard when none is given.
struct KeyHashInput {
    struct ResolvedKey {
        let payload: Data
        /// Absolute key file path, when the key came from a file.
        let file: FilePath?
        /// The key exactly as typed, when it came from text.
        let text: String?
        let envelopeType: String?

        var isCold: Bool { envelopeType?.contains("Cold") ?? text?.hasPrefix("cc_cold") ?? false }
        var isHot: Bool { envelopeType?.contains("Hot") ?? text?.hasPrefix("cc_hot") ?? false }
    }

    let role: HashUtils.KeyRole
    var verificationKey: String?
    var verificationKeyFile: FilePath?
    var name: String?
    var tool: Tool?

    /// Flag names used in messages and cardano-cli arguments.
    var textFlag: String?
    var fileFlag: String
    var nameFlag: String? = nil
    var nameSuffix: String? = nil
    /// A further source a command offers (e.g. `--drep-key-hash`).
    var alternativeFlag: String? = nil
    var alternativeProvided = false
    /// An address to read the credential from, for commands that offer it.
    var address: String? = nil
    var addressFlag: String? = nil

    enum Source {
        case key(ResolvedKey)
        case address(String)
    }

    var resolvedTool: Tool = .swiftCardano

    private var flagList: String {
        ([textFlag, fileFlag, nameFlag, addressFlag, alternativeFlag].compactMap { $0 }).joined(separator: ", ")
    }

    private var providedCount: Int {
        [verificationKey != nil, verificationKeyFile != nil, name != nil, address != nil, alternativeProvided].filter { $0 }.count
    }

    func checkSingleSource() throws {
        if providedCount > 1 {
            noora.error(.alert(
                "Provide only one \(role.label) verification key source.",
                takeaways: ["Use one of \(flagList)."]
            ))
            throw ExitCode.validationFailure
        }
    }

    mutating func wizard() async throws {
        let keyFile = "Key file", keyText = "Bech32 or hex key", fromAddress = "Address"
        var options = [keyFile]
        if textFlag != nil { options.append(keyText) }
        if addressFlag != nil { options.append(fromAddress) }
        let choice = options.count == 1 ? keyFile : noora.singleChoicePrompt(
            title: "Verification Key",
            question: "How do you want to provide the \(role.label) \(addressFlag != nil ? "key or address" : "verification key")?",
            options: options
        )
        if choice == fromAddress {
            address = noora.textPrompt(
                title: "Address",
                prompt: "Enter the address, address file or address name:",
                description: role == .stake ? "A stake address (stake1…) or a base payment address (addr1…)." : "A payment address (addr1…).",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "The address cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if choice == keyFile {
            verificationKeyFile = try promptFilePath(
                title: "\(role.label.prefix(1).uppercased() + role.label.dropFirst()) Verification Key",
                question: "Select the \(role.label) verification key file:",
                matching: { $0.hasSuffix(".vkey") }
            )
        } else {
            verificationKey = noora.textPrompt(
                title: "Verification Key",
                prompt: "Enter the \(role.label) verification key:",
                description: "Bech32 (\(role.bech32Prefixes.map { "\($0)1…" }.joined(separator: ", "))) or hex.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "The key cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if tool == nil { tool = try await getToolToUse() }
    }

    /// Validate the input and load the key, so both tools report the same errors.
    mutating func resolve() async throws -> ResolvedKey {
        guard case .key(let key) = try await resolveSource() else {
            throw ExitCode.validationFailure
        }
        return key
    }

    /// Like `resolve()`, but also returns an address when one was given instead of a key.
    mutating func resolveSource() async throws -> Source {
        try checkSingleSource()
        if providedCount == 0 {
            guard isInteractiveSession() else {
                noora.error(.alert(
                    "Missing \(role.label) verification key.",
                    takeaways: ["Use one of \(flagList)."]
                ))
                throw ExitCode.validationFailure
            }
            try await wizard()
        }
        if let address {
            resolvedTool = try await resolveTool(tool)
            return .address(address)
        }
        if let name, let nameSuffix {
            verificationKeyFile = FilePath("\(name)\(nameSuffix)")
        }

        let key: ResolvedKey
        do {
            if let verificationKeyFile {
                let path = FileUtils.absolutePath(verificationKeyFile)
                let loaded = try HashUtils.verificationKeyFile(path, role: role)
                if !HashUtils.isExpectedKeyType(loaded.envelope.type, role: role) {
                    noora.warning(.alert(
                        "\(verificationKeyFile.string) is a \(loaded.envelope.type) key, not a \(role.label) key.",
                        takeaway: "The hash is computed anyway; make sure this is the key you meant."
                    ))
                }
                key = ResolvedKey(payload: loaded.payload, file: path, text: nil, envelopeType: loaded.envelope.type)
            } else {
                let text = (verificationKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let payload = try HashUtils.verificationKeyPayload(from: text, role: role)
                key = ResolvedKey(payload: payload, file: nil, text: text, envelopeType: nil)
            }
        } catch {
            noora.error(.alert("Could not read the \(role.label) verification key.", takeaways: ["\(error.localizedDescription)"]))
            throw ExitCode.failure
        }

        resolvedTool = try await resolveTool(tool)
        return .key(key)
    }

    /// Read the payment or stake credential from an address and print its hash.
    func emitAddressCredential(_ input: String, part: HashUtils.AddressPart, outFile: FilePath?) async throws {
        let bech32: String
        let credential: HashUtils.AddressCredential
        do {
            bech32 = try HashUtils.addressText(input, part: part)
            switch resolvedTool {
                case .cardanoCLI:
                    // cardano-cli has no command for this; its address info gives the raw address bytes.
                    let cli = try await HashUtils.cardanoCLI()
                    let info = try await cli.address.info(arguments: ["--address", bech32])
                    credential = try HashUtils.credential(fromAddressInfo: info, part: part)
                case .swiftCardano:
                    credential = try HashUtils.credential(fromAddressBytes: HashUtils.addressBytes(bech32: bech32), part: part)
            }
        } catch {
            noora.error(.alert("Could not read the \(part.label) credential from the address.", takeaways: ["\(error.localizedDescription)"]))
            throw ExitCode.failure
        }
        let kind = credential.isScript ? "Script" : "Key"
        let partName = part == .payment ? "Payment" : "Stake"
        try HashUtils.emit(HashReport(
            title: "\(partName) \(kind) Hash",
            summary: "Reading the \(part.label) credential from an address",
            inputs: [
                ("Address", bech32),
                ("Address type", "\(credential.addressType) (\(credential.network))"),
                ("\(partName) credential", credential.isScript ? "Script hash" : "Key hash"),
            ],
            method: "No hashing needed: the address stores the 28-byte \(part.label) \(kind.lowercased()) hash\(resolvedTool == .cardanoCLI ? " (address bytes from cardano-cli address info)" : "")",
            hash: credential.hash.toHex,
            tool: resolvedTool, outFile: outFile
        ))
    }

    /// Input details for the report: where the key came from, its type and size.
    func inputDetails(_ key: ResolvedKey) -> [(String, String)] {
        var details: [(String, String)] = []
        if key.file != nil {
            details.append(("Key file", verificationKeyFile?.string ?? key.file?.string ?? ""))
            if let type = key.envelopeType {
                details.append(("Key type", type))
            }
        } else if let text = key.text {
            details.append(("Verification key", text))
        }
        details.append(("Key size", key.payload.count == 64 ? "64 bytes (extended: public key + chain code)" : "32 bytes"))
        return details
    }

    /// How a key hash is computed from this key.
    func keyHashMethod(_ key: ResolvedKey) -> String {
        key.payload.count == 64
            ? "blake2b-224 of the 32-byte public key (chain code excluded) → 28-byte key hash"
            : "blake2b-224 of the 32-byte public key → 28-byte key hash"
    }

    /// cardano-cli arguments naming the key: the file, or the key as Bech32 (some
    /// cardano-cli commands only take Bech32, so hex input is re-encoded).
    func cliArguments(_ key: ResolvedKey) throws -> [String] {
        if let file = key.file {
            return [fileFlag, file.string]
        }
        guard let textFlag else {
            throw SwiftCardanoMultitoolError.valueError("A \(role.label) key file is required.")
        }
        if let text = key.text, role.bech32Prefixes.contains(where: { text.hasPrefix($0 + "1") }) {
            return [textFlag, text]
        }
        let prefixes = role.bech32Prefixes
        let hrp = key.payload.count == 64 ? (prefixes.first { $0.hasSuffix("xvk") } ?? prefixes[0]) : prefixes[0]
        guard let bech32 = Bech32().encode(hrp: hrp, witprog: key.payload) else {
            throw SwiftCardanoMultitoolError.valueError("Could not encode the \(role.label) verification key as Bech32.")
        }
        return [textFlag, bech32]
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
