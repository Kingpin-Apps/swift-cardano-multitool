import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner

extension SignMainCommand {

    struct SignCIP88: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cip88",
            abstract: "Build a CIP-88 / CIP-151 Calidus pool-key registration.",
            usage: """
            scm sign cip88 \\
                --calidus-public-key calidus.vkey \\
                --secret-key pool.cold.skey
            """
        )

        @Option(name: .customLong("calidus-public-key"), help: "Calidus public key (path to .vkey or raw hex).")
        var calidusPublicKey: String? = nil

        @Option(name: [.customShort("s"), .customLong("secret-key")], help: "Pool cold signing key — path to a .skey file or raw hex.")
        var secretKey: String? = nil

        @Option(name: .long, help: "Monotonic nonce. Defaults to the current mainnet slot height if omitted.")
        var nonce: UInt64? = nil

        @Flag(name: .customLong("meta-json"), help: "Emit cardano-cli detailed-schema JSON metadata (for --metadata-json-file) instead of CBOR-hex auxdata.")
        var metaJson: Bool = false

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            calidusPublicKey = noora.textPrompt(
                title: "Calidus Public Key",
                prompt: "Enter the path to the Calidus .vkey or raw hex:",
                validationRules: [NonEmptyValidationRule(error: "Calidus key cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            secretKey = SignerUtils.promptSecretKeyPath(
                title: "Pool Cold Signing Key",
                prompt: "Enter the path to the pool cold .skey file:"
            )
            if noora.yesOrNoChoicePrompt(
                title: "Nonce",
                question: "Override the auto-computed mainnet-slot nonce?",
                defaultAnswer: false
            ) {
                nonce = UInt64(noora.textPrompt(
                    title: "Nonce",
                    prompt: "Enter the nonce:",
                    validationRules: [NonEmptyValidationRule(error: "Nonce cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        mutating func run() async throws {
            if calidusPublicKey == nil || secretKey == nil {
                try await wizard()
            }
            var calidusBytes = try SignerUtils.resolveRawKey(calidusPublicKey!)
            // Extended vkeys (xpub) are 64 bytes: 32-byte ed25519 pubkey + 32-byte chain code.
            // CIP-88 registers the 32-byte ed25519 public key only.
            if calidusBytes.count == 64 {
                calidusBytes = calidusBytes.prefix(32)
            }
            let poolKey = try SignerUtils.resolveSecretKey(secretKey!)
            let resolvedNonce = nonce ?? SignerUtils.currentMainnetSlotNonce()

            let aux = try Signer.CIP88.makeCalidusRegistration(
                calidusPublicKey: calidusBytes,
                poolSigningKey: poolKey,
                nonce: resolvedNonce
            )

            if metaJson {
                let metadata = try Self.extractMetadata(from: aux)
                let json = try Self.metadataToDetailedSchemaJSON(metadata)
                let data = try JSONSerialization.data(
                    withJSONObject: json,
                    options: [.prettyPrinted, .sortedKeys]
                )
                let rendered = String(data: data, encoding: .utf8) ?? "{}"
                try await SignerUtils.emit(rendered, to: output.outFile)
                return
            }

            let cborHex = try aux.toCBORHex()
            let rendered: String
            switch output.format {
            case .plain:
                rendered = cborHex
            case .json:
                rendered = try SignerUtils.jsonString(["cborHex": cborHex])
            case .jsonExtended:
                rendered = try SignerUtils.jsonString([
                    "workMode": "sign-cip88",
                    "cborHex": cborHex,
                    "nonce": String(resolvedNonce),
                ])
            }
            try await SignerUtils.emit(rendered, to: output.outFile)
        }

        // MARK: - Detailed-schema JSON conversion

        private static func extractMetadata(from aux: AuxiliaryData) throws -> Metadata {
            switch aux.data {
            case .metadata(let m):
                return m
            case .shelleyMaryMetadata(let s):
                return s.metadata
            case .alonzoMetadata(let a):
                guard let m = a.metadata else {
                    throw ValidationError("CIP-88 auxiliary data has no metadata to serialize.")
                }
                return m
            }
        }

        private static func metadataToDetailedSchemaJSON(_ metadata: Metadata) throws -> [String: Any] {
            var top: [String: Any] = [:]
            for (label, value) in metadata.data {
                top[String(label)] = metadatumToDetailedSchema(value)
            }
            return top
        }

        private static func metadatumToDetailedSchema(_ m: TransactionMetadatum) -> Any {
            switch m {
            case .int(let n):
                return ["int": NSNumber(value: n)]
            case .bytes(let d):
                return ["bytes": d.toHex]
            case .text(let s):
                return ["string": s]
            case .list(let xs):
                return ["list": xs.map { metadatumToDetailedSchema($0) }]
            case .map(let pairs):
                let entries = pairs.map { (key, value) -> [String: Any] in
                    [
                        "k": metadatumToDetailedSchema(key),
                        "v": metadatumToDetailedSchema(value),
                    ]
                }
                return ["map": entries]
            }
        }
    }
}
