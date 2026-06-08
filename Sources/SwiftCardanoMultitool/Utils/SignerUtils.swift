import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoCIPs
import SwiftCardanoSigner

/// Output format for signer subcommands, mirroring cardano-signer.js CLI flags.
public enum SignerOutputFormat: String, ExpressibleByArgument, CaseIterable {
    case plain
    case json
    case jsonExtended = "json-extended"
}

/// Shared option group for sign / verify subcommands.
public struct SignerOutputOptions: ParsableArguments {
    @Flag(name: .long, help: "Output as JSON.")
    public var json: Bool = false

    @Flag(name: .customLong("json-extended"), help: "Output as extended JSON (includes work mode, hex payloads, derived fields).")
    public var jsonExtended: Bool = false

    @Flag(name: .customLong("include-secret"), help: "Include the secret key in extended JSON output. Has no effect without --json-extended.")
    public var includeSecret: Bool = false

    @Option(name: [.customShort("o"), .customLong("out-file")], help: "Write the primary output to a file instead of stdout.")
    public var outFile: FilePath? = nil

    public init() {}

    public var format: SignerOutputFormat {
        if jsonExtended { return .jsonExtended }
        if json { return .json }
        return .plain
    }
}

/// Shared resolvers for signer subcommands.
public enum SignerUtils {

    // MARK: - Data input

    /// Resolve a payload from the three mutually-exclusive cardano-signer input flags.
    /// Exactly one of `text` / `hex` / `file` must be non-nil.
    public static func resolveData(
        text: String?,
        hex: String?,
        file: FilePath?
    ) throws -> Data {
        let provided = [text != nil, hex != nil, file != nil].filter { $0 }.count
        guard provided == 1 else {
            throw ValidationError("Provide exactly one of --data, --data-hex, or --data-file.")
        }
        if let text = text {
            return Data(text.utf8)
        }
        if let hex = hex {
            guard let data = Data(hexString: hex) else {
                throw ValidationError("--data-hex must be valid hex.")
            }
            return data
        }
        if let file = file {
            guard let data = FileManager.default.contents(atPath: file.string) else {
                throw ValidationError("Could not read --data-file at \(file.string).")
            }
            return data
        }
        // Unreachable due to the count check above.
        throw ValidationError("No data provided.")
    }

    // MARK: - Key inputs

    /// Resolve a signing key from a file path or raw hex.
    /// Bech32 (`ed25519_sk…`) is not yet supported — pass the `.skey` file or hex instead.
    public static func resolveSecretKey(_ input: String) throws -> SigningKeyType {
        if FileManager.default.fileExists(atPath: input) {
            return try SigningKeyType.load(from: input)
        }
        if let data = Data(hexString: input) {
            if data.count == 32 {
                return .signingKey(try SigningKey(payload: data))
            }
            // 64-byte extended (xprv), 96-byte (xprv + chain), 128-byte (xprv + pub + chain)
            return .extendedSigningKey(try ExtendedSigningKey(payload: data))
        }
        throw ValidationError("--secret-key must be a file path or raw hex.")
    }

    /// Resolve a verification key from a file path or raw hex.
    public static func resolvePublicKey(_ input: String) throws -> VerificationKeyType {
        if FileManager.default.fileExists(atPath: input) {
            return try VerificationKeyType.load(from: input)
        }
        if let data = Data(hexString: input) {
            if data.count == 32 {
                return .verificationKey(try VerificationKey(payload: data))
            } else if data.count == 64 {
                return .extendedVerificationKey(try ExtendedVerificationKey(payload: data))
            }
        }
        throw ValidationError("--public-key must be a file path or raw hex (32 or 64 bytes).")
    }

    /// Resolve raw key bytes from a `.vkey` TextEnvelope file or raw hex string.
    /// For TextEnvelope files, the inner CBOR byte string is unwrapped.
    public static func resolveRawKey(_ input: String) throws -> Data {
        if FileManager.default.fileExists(atPath: input) {
            let vk = try VerificationKeyType.load(from: input)
            switch vk {
            case .verificationKey(let k): return k.payload
            case .extendedVerificationKey(let k): return k.payload
            }
        }
        if let data = Data(hexString: input) {
            return data
        }
        throw ValidationError("Expected a TextEnvelope vkey file path or raw hex.")
    }

    /// Resolve a signature from hex.
    public static func resolveSignature(_ input: String) throws -> Data {
        if let data = Data(hexString: input) {
            return data
        }
        throw ValidationError("--signature must be hex-encoded.")
    }

    /// Resolve a Cardano address from a file (.addr), bech32, or hex.
    public static func resolveAddress(_ input: String) throws -> Address {
        if FileManager.default.fileExists(atPath: input) {
            let contents = try String(contentsOfFile: input, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return try Address(from: .string(contents))
        }
        return try Address(from: .string(input))
    }

    // MARK: - Mainnet slot nonce

    /// Compute a CIP-36 / CIP-88 nonce from the current wall clock as the mainnet slot height.
    public static func currentMainnetSlotNonce() -> UInt64 {
        let now = Int64(Date().timeIntervalSince1970)
        return SlotNonce.mainnetSlot(at: now)
    }

    // MARK: - Output emission

    /// Emit `text` to stdout — or to a file if `outFile` is set.
    public static func emit(_ text: String, to outFile: FilePath?) async throws {
        if let outFile = outFile {
            try await FileUtils.dumpLockedFile(outFile, data: text)
            print(noora.format(
                "Output written to: \(.primary("\(outFile.string)"))"
            ))
        } else {
            print(text)
        }
    }

    /// Serialize a `SignatureResult` per cardano-signer's output flags.
    public static func renderDefaultSign(
        _ result: SignatureResult,
        payload: Data,
        signingKey: SigningKeyType,
        format: SignerOutputFormat,
        includeSecret: Bool,
        extras: [(key: String, value: String)] = []
    ) throws -> String {
        switch format {
        case .plain:
            var parts: [String] = ["\(result.signature.toHex)", "\(result.publicKey.toHex)"]
            parts.append(contentsOf: extras.map { $0.value })
            return parts.joined(separator: " ")
        case .json:
            var dict: [String: String] = [
                "signature": result.signature.toHex,
                "publicKey": result.publicKey.toHex,
            ]
            if includeSecret {
                dict["secretKey"] = try keyToHex(signingKey)
            }
            for (k, v) in extras { dict[k] = v }
            return try jsonString(dict)
        case .jsonExtended:
            var dict: [String: String] = [
                "workMode": "sign",
                "signDataHex": payload.toHex,
                "signature": result.signature.toHex,
                "publicKey": result.publicKey.toHex,
            ]
            if includeSecret {
                dict["secretKey"] = try keyToHex(signingKey)
            }
            for (k, v) in extras { dict[k] = v }
            return try jsonString(dict)
        }
    }

    /// Serialize a default-mode verify result.
    public static func renderDefaultVerify(
        valid: Bool,
        payload: Data,
        signature: Data,
        verificationKey: VerificationKeyType,
        format: SignerOutputFormat
    ) throws -> String {
        switch format {
        case .plain:
            return valid ? "true" : "false"
        case .json:
            return try jsonString([
                "result": valid ? "true" : "false"
            ])
        case .jsonExtended:
            return try jsonString([
                "workMode": "verify",
                "result": valid ? "true" : "false",
                "verifyDataHex": payload.toHex,
                "signature": signature.toHex,
                "publicKey": verificationKeyHex(verificationKey),
            ])
        }
    }

    /// Serialize a CIP-8/CIP-30 signed message.
    public static func renderSignedMessage(
        _ signed: SignedMessage,
        workMode: String,
        payload: Data,
        format: SignerOutputFormat
    ) throws -> String {
        switch format {
        case .plain:
            // cardano-signer prints the COSE_Sign1 hex followed by the COSE_Key hex.
            if let key = signed.key {
                return "\(signed.signature) \(key)"
            }
            return signed.signature
        case .json, .jsonExtended:
            var dict: [String: String] = [
                "signature": signed.signature
            ]
            if let key = signed.key {
                dict["key"] = key
            }
            if format == .jsonExtended {
                dict["workMode"] = workMode
                dict["signDataHex"] = payload.toHex
            }
            return try jsonString(dict)
        }
    }

    /// Serialize a CIP-8 / CIP-30 verification result.
    public static func renderVerificationResult(
        _ result: SwiftCardanoCIPs.VerificationResult,
        workMode: String,
        format: SignerOutputFormat
    ) throws -> String {
        let valid = result.verified ? "true" : "false"
        switch format {
        case .plain:
            return valid
        case .json:
            return try jsonString(["result": valid])
        case .jsonExtended:
            return try jsonString([
                "workMode": workMode,
                "result": valid,
                "signingAddress": result.signingAddress.description,
                "message": result.message,
            ])
        }
    }

    // MARK: - JSON helper

    public static func jsonString(_ dict: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: - Key serialization

    private static func keyToHex(_ key: SigningKeyType) throws -> String {
        switch key {
        case .signingKey(let k): return k.payload.toHex
        case .extendedSigningKey(let k): return k.payload.toHex
        }
    }

    private static func verificationKeyHex(_ key: VerificationKeyType) -> String {
        switch key {
        case .verificationKey(let k): return k.payload.toHex
        case .extendedVerificationKey(let k): return k.payload.toHex
        }
    }
}

// MARK: - Wizard helpers

public enum SignerDataSource: String, CaseIterable, CustomStringConvertible {
    case text = "Plain text"
    case hex = "Hex string"
    case file = "File path"

    public var description: String { rawValue }
}

extension SignerUtils {

    /// Walk the user through choosing a data source and gathering the payload.
    /// Mutates the matching field via the supplied closures.
    public static func promptDataSource(
        title: String = "Data to sign"
    ) -> SignerDataSource {
        return noora.singleChoicePrompt(
            title: TerminalText(stringLiteral: title),
            question: "How will you provide the data?",
            options: SignerDataSource.allCases,
            description: "Pick the input form. Equivalent to cardano-signer's --data / --data-hex / --data-file."
        )
    }

    public static func promptSecretKeyPath(
        title: String = "Secret Key",
        prompt: String = "Enter the path to the signing key (.skey) file:"
    ) -> String {
        return noora.textPrompt(
            title: TerminalText(stringLiteral: title),
            prompt: TerminalText(stringLiteral: prompt),
            collapseOnAnswer: true,
            validationRules: [NonEmptyValidationRule(error: "Path cannot be empty.")]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func promptPublicKeyPath(
        title: String = "Public Key",
        prompt: String = "Enter the path, hex, or bech32 of the verification key:"
    ) -> String {
        return noora.textPrompt(
            title: TerminalText(stringLiteral: title),
            prompt: TerminalText(stringLiteral: prompt),
            collapseOnAnswer: true,
            validationRules: [NonEmptyValidationRule(error: "Public key cannot be empty.")]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func promptAddress(
        title: String = "Address",
        prompt: String = "Enter the bech32 address (or path to .addr file):"
    ) -> String {
        return noora.textPrompt(
            title: TerminalText(stringLiteral: title),
            prompt: TerminalText(stringLiteral: prompt),
            collapseOnAnswer: true,
            validationRules: [NonEmptyValidationRule(error: "Address cannot be empty.")]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
