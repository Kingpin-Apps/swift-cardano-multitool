import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoChain
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftKoios

extension QueryMainCommand {
    struct PoolCalidusKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "calidus-key",
            abstract: "Query on-chain CIP-88 Calidus pool-key registrations via Koios.",
            usage: """
            scm query calidus-key all
            scm query calidus-key pool1abc…
            scm query calidus-key calidus1abc…
            scm query calidus-key <calidusKeyName>
            scm query calidus-key <poolNodeName>
            """,
            discussion: """
            Lists registered Calidus pool keys (CIP-88) and filters by:
              • 'all' (or no filter) — every registered calidus key
              • pool1… bech32 — match the pool ID
              • calidus1… bech32 — match the Calidus ID
              • 64-char hex — match the calidus public key
              • A file path or bare name — resolved against
                <name>.calidus.id, <name>.calidus.vkey, <name>.node.vkey,
                or any standard pool/calidus key file in the working directory.
            """
        )

        @Argument(help: "Filter: 'all', pool/calidus bech32, calidus pub-key hex, file path, or bare name.")
        var filter: String? = nil

        mutating func wizard() async throws {
            filter = noora.textPrompt(
                title: "Calidus Key Filter",
                prompt: "Enter 'all', pool1…/calidus1… bech32, calidus pub-key hex, or a key name:",
                description: "Looks up CIP-88 Calidus key registrations on Koios.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Filter cannot be empty (use 'all' for no filter).")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        mutating func run() async throws {
            if filter == nil {
                try await wizard()
            }
            guard let raw = filter?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)

            try await printContextInfo(config: config)

            guard config.mode != .offline else {
                noora.error(.alert(
                    "This command requires online mode.",
                    takeaways: [
                        "Set mode to 'online', 'lite', or 'auto' in your config.",
                        "Koios is queried directly — a synced local node is not required."
                    ]
                ))
                throw ExitCode.failure
            }

            let resolved = try resolveFilter(raw)
            printFilterSummary(resolved)

            let koiosContext = try await KoiosChainContext(
                apiKey: config.koiosApiKey,
                network: cardanoConfig.network
            )

            let allRows = try await noora.progressStep(
                message: "Querying Koios pool_calidus_keys...",
                successMessage: "Successfully retrieved Calidus key registrations.",
                errorMessage: "Failed to retrieve Calidus key registrations.",
                showSpinner: true
            ) { _ in
                let response = try await koiosContext.api.client.poolCalidusKeys()
                return try response.ok.body.json
            }

            let matched = allRows.filter { resolved.matches($0) }

            print()
            if matched.isEmpty {
                noora.warning(.alert(
                    "No Calidus key registrations matched.",
                    takeaway: "Try 'all' to list every registration, or double-check the filter."
                ))
                return
            }

            try render(rows: matched, totalRows: allRows, config: config, cardanoConfig: cardanoConfig)
        }

        // MARK: - Filter resolution

        private enum ResolvedFilter {
            case all
            case poolIdBech32(String)
            case calidusIdBech32(String)
            case calidusPubKeyHex(String)

            func matches(_ row: SwiftKoios.Components.Schemas.PoolCalidusKeysPayload) -> Bool {
                switch self {
                case .all:
                    return true
                case .poolIdBech32(let target):
                    return (row.poolIdBech32?.value as? String)?.caseInsensitiveCompare(target) == .orderedSame
                case .calidusIdBech32(let target):
                    return row.calidusIdBech32?.caseInsensitiveCompare(target) == .orderedSame
                case .calidusPubKeyHex(let target):
                    return row.calidusPubKey?.caseInsensitiveCompare(target) == .orderedSame
                }
            }
        }

        private func resolveFilter(_ input: String) throws -> ResolvedFilter {
            if input.lowercased() == "all" {
                return .all
            }
            if input.lowercased().hasPrefix("calidus1") {
                return .calidusIdBech32(input)
            }
            if input.lowercased().hasPrefix("pool1") {
                return .poolIdBech32(input)
            }
            if isHexKey(input) {
                return .calidusPubKeyHex(input.lowercased())
            }

            // File or bare-name resolution
            let fileManager = FileManager.default
            let cwd = FilePath(fileManager.currentDirectoryPath)

            if fileManager.fileExists(atPath: input) {
                return try resolveFromFile(FilePath(input))
            }

            let candidates = [
                cwd.appending("\(input).calidus.id"),
                cwd.appending("\(input).calidus.vkey"),
                cwd.appending("\(input).node.vkey"),
            ]
            for candidate in candidates where fileManager.fileExists(atPath: candidate.string) {
                return try resolveFromFile(candidate)
            }

            if let pool = PoolOperator(argument: input) {
                let bech = try pool.toBech32()
                return .poolIdBech32(bech)
            }

            noora.error(.alert(
                "Could not interpret filter: \(.primary(input))",
                takeaways: [
                    "Use 'all' to list every registration.",
                    "Bech32 IDs (pool1…, calidus1…) and 64-char hex public keys are accepted.",
                    "Bare names look up <name>.calidus.id, <name>.calidus.vkey, <name>.node.vkey in the current directory.",
                ]
            ))
            throw ExitCode.validationFailure
        }

        private func resolveFromFile(_ path: FilePath) throws -> ResolvedFilter {
            let name = path.string.lowercased()
            if name.hasSuffix(".calidus.id") {
                let contents = try String(contentsOfFile: path.string, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !contents.isEmpty else {
                    throw ValidationError("File \(path.string) is empty.")
                }
                return try resolveFilter(contents)
            }
            if name.hasSuffix(".calidus.vkey") {
                let raw = try SignerUtils.resolveRawKey(path.string)
                return .calidusPubKeyHex(raw.toHex.lowercased())
            }
            if name.hasSuffix(".node.vkey") {
                let vkey = try StakePoolVerificationKey.load(from: path.string)
                let poolKeyHash = try vkey.poolKeyHash()
                let bech = try PoolOperator(poolKeyHash: poolKeyHash).toBech32()
                return .poolIdBech32(bech)
            }
            // Fall back: treat file contents as a bech32 / hex string
            let contents = try String(contentsOfFile: path.string, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !contents.isEmpty else {
                throw ValidationError("File \(path.string) is empty.")
            }
            return try resolveFilter(contents)
        }

        private func isHexKey(_ input: String) -> Bool {
            guard input.count == 64 else { return false }
            let hexSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
            return input.unicodeScalars.allSatisfy { hexSet.contains($0) }
        }

        // MARK: - Rendering

        private func printFilterSummary(_ resolved: ResolvedFilter) {
            switch resolved {
            case .all:
                spacedPrint("Filter: \(.primary("all"))")
            case .poolIdBech32(let v):
                spacedPrint("Filter: pool-id \(.primary(v))")
            case .calidusIdBech32(let v):
                spacedPrint("Filter: calidus-id \(.primary(v))")
            case .calidusPubKeyHex(let v):
                spacedPrint("Filter: calidus pub-key \(.primary(v))")
            }
        }

        private func render(
            rows: [SwiftKoios.Components.Schemas.PoolCalidusKeysPayload],
            totalRows: [SwiftKoios.Components.Schemas.PoolCalidusKeysPayload],
            config: MultitoolConfig,
            cardanoConfig: CardanoConfig
        ) throws {
            let explorer = config.blockchainExplorer.explorer(network: cardanoConfig.network)

            for (index, row) in rows.enumerated() {
                let header: TerminalText = "\(.primary("Entry \(index + 1) of \(rows.count)"))"
                spacedPrint(header)

                let poolId = (row.poolIdBech32?.value as? String) ?? "—"
                let poolStatus = (row.poolStatus?.value as? String) ?? "—"
                let calidusId = row.calidusIdBech32 ?? "—"
                let calidusPubKey = row.calidusPubKey ?? "—"
                let nonce = row.calidusNonce.map { String(Int64($0)) } ?? "—"
                let registered = row.registered.map { $0 ? "yes" : "no" } ?? "—"
                let txHash = (row.txHash?.value as? String) ?? "—"
                let epoch = anyValueString(row.epochNo?.value)
                let blockHeight = anyValueString(row.blockHeight?.value)
                let blockTime = blockTimeString(row.blockTime?.value)

                print(noora.format("  Pool ID:        \(.primary(poolId))"))
                print(noora.format("  Pool Status:    \(.primary(poolStatus))"))
                print(noora.format("  Calidus ID:     \(.primary(calidusId))"))
                print(noora.format("  Calidus PubKey: \(.primary(calidusPubKey))"))
                print(noora.format("  Nonce:          \(.primary(nonce))"))
                print(noora.format("  Registered:     \(.primary(registered))"))
                print(noora.format("  Epoch:          \(.primary(epoch))"))
                print(noora.format("  Block Height:   \(.primary(blockHeight))"))
                print(noora.format("  Block Time:     \(.primary(blockTime))"))
                print(noora.format("  Tx Hash:        \(.primary(txHash))"))

                if txHash != "—",
                   let txData = Optional(txHash.hexStringToData),
                   txData.count == 32,
                   let url = try? explorer.viewTransaction(
                    transactionId: TransactionId(payload: txData)
                   ) {
                    spacedPrint("  \(.link(title: url.absoluteString, href: url.absoluteString))")
                } else {
                    print()
                }
            }

            let uniqueCalidusKeys = Set(totalRows.compactMap { $0.calidusPubKey?.lowercased() }).count
            let uniquePools = Set(totalRows.compactMap { ($0.poolIdBech32?.value as? String)?.lowercased() }).count
            let matchWord = rows.count == 1 ? "match" : "matches"
            let keyWord = uniqueCalidusKeys == 1 ? "key" : "keys"
            let poolWord = uniquePools == 1 ? "pool" : "pools"
            spacedPrint(
                "\(.success("\(rows.count) \(matchWord)")) (\(uniqueCalidusKeys) unique Calidus \(keyWord) across \(uniquePools) \(poolWord) on chain)"
            )
        }

        private func anyValueString(_ any: Any?) -> String {
            guard let any = any else { return "—" }
            if let s = any as? String { return s }
            if let i = any as? Int { return String(i) }
            if let d = any as? Double { return String(Int64(d)) }
            return String(describing: any)
        }

        private func blockTimeString(_ any: Any?) -> String {
            guard let any = any else { return "—" }
            let seconds: TimeInterval?
            if let d = any as? Double { seconds = d }
            else if let i = any as? Int { seconds = TimeInterval(i) }
            else { seconds = nil }
            guard let seconds = seconds else { return anyValueString(any) }
            let date = Date(timeIntervalSince1970: seconds)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.string(from: date)
        }
    }
}
