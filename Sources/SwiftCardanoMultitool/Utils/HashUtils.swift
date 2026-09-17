import Foundation
import ArgumentParser
import SystemPackage
import SwiftCardanoCore
import CBORCodable
import SwiftNaCl
import SwiftCardanoUtils
import Noora
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Hash computations mirroring `cardano-cli hash …`, `address key-hash` and `stake-address key-hash`.
enum HashUtils {

    /// Which verification keys a key-hash command accepts.
    enum KeyRole: Sendable, CaseIterable {
        case payment
        case stake
        case drep
        case committee
        case vrf
        case stakePool
        case genesis

        var label: String {
            switch self {
                case .payment: return "payment"
                case .stake: return "stake"
                case .drep: return "DRep"
                case .committee: return "committee"
                case .vrf: return "VRF"
                case .stakePool: return "stake pool"
                case .genesis: return "genesis"
            }
        }

        /// Bech32 prefixes accepted for a key given as text; empty when only files are accepted.
        var bech32Prefixes: [String] {
            switch self {
                case .payment: return ["addr_vk", "addr_xvk"]
                case .stake: return ["stake_vk", "stake_xvk"]
                case .drep: return ["drep_vk", "drep_xvk"]
                case .committee: return ["cc_hot_vk", "cc_hot_xvk", "cc_cold_vk", "cc_cold_xvk"]
                case .vrf: return ["vrf_vk"]
                case .stakePool: return ["pool_vk", "pool_xvk"]
                case .genesis: return []
            }
        }

        /// Text envelope type prefixes of the key files used for this role.
        var envelopeTypePrefixes: [String] {
            switch self {
                case .payment: return ["PaymentVerificationKey", "PaymentExtendedVerificationKey", "GenesisUTxOVerificationKey"]
                case .stake: return ["StakeVerificationKey", "StakeExtendedVerificationKey"]
                case .drep: return ["DRepVerificationKey", "DRepExtendedVerificationKey"]
                case .committee: return [
                    "ConstitutionalCommitteeHotVerificationKey", "ConstitutionalCommitteeHotExtendedVerificationKey",
                    "ConstitutionalCommitteeColdVerificationKey", "ConstitutionalCommitteeColdExtendedVerificationKey",
                ]
                case .vrf: return ["VrfVerificationKey"]
                case .stakePool: return ["StakePoolVerificationKey", "StakePoolExtendedVerificationKey"]
                case .genesis: return ["GenesisVerificationKey", "GenesisDelegateVerificationKey", "GenesisUTxOVerificationKey"]
            }
        }

        /// Whether a key file of another type is an error (as in cardano-cli) rather than a warning.
        /// cardano-cli's address and stake-address key-hash accept any key.
        var requiresMatchingType: Bool {
            switch self {
                case .payment, .stake: return false
                default: return true
            }
        }

        /// VRF keys have no extended form.
        var allowsExtended: Bool { self != .vrf }
    }

    // MARK: - Primitives

    static func blake2b(_ data: Data, digestSize: Int) throws -> Data {
        try SwiftNaCl.Hash().blake2b(data: data, digestSize: digestSize, encoder: RawEncoder.self)
    }

    /// A text envelope file's fields, without interpreting its payload.
    struct Envelope: Sendable {
        let type: String
        let description: String
        let cborHex: String

        init(type: String, description: String, cborHex: String) {
            self.type = type
            self.description = description
            self.cborHex = cborHex
        }

        init(path: FilePath) throws {
            guard let data = FileManager.default.contents(atPath: path.string) else {
                throw SwiftCardanoMultitoolError.fileNotFound(path)
            }
            try self.init(json: data, source: path.string)
        }

        init(json data: Data, source: String) throws {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SwiftCardanoMultitoolError.valueError("\(source) is not a text envelope JSON file.")
            }
            guard let type = json["type"] as? String else {
                throw SwiftCardanoMultitoolError.valueError("\(source) has no 'type' field.")
            }
            guard let cborHex = json["cborHex"] as? String else {
                if json["encrHex"] != nil {
                    throw SwiftCardanoMultitoolError.valueError("\(source) is encrypted. Decrypt it first with 'scm protect decrypt'.")
                }
                throw SwiftCardanoMultitoolError.valueError("\(source) has no 'cborHex' field.")
            }
            self.type = type
            self.description = json["description"] as? String ?? ""
            self.cborHex = cborHex
        }

        var cborData: Data {
            get throws {
                guard let data = Data(hexString: cborHex) else {
                    throw SwiftCardanoMultitoolError.invalidHex("cborHex")
                }
                return data
            }
        }

        /// The raw bytes wrapped by a key envelope's CBOR byte string.
        var keyPayload: Data {
            get throws {
                let cbor = try CBORDecoder().decode(CBOR.self, from: try cborData)
                guard case let .byteString(payload) = cbor else {
                    throw SwiftCardanoMultitoolError.valueError("The '\(type)' payload is not a CBOR byte string.")
                }
                return payload
            }
        }
    }

    // MARK: - Key hashes

    /// Blake2b-224 of an Ed25519 public key. Extended keys (64 bytes) hash only the
    /// 32-byte public key, matching cardano-cli.
    static func verificationKeyHash(payload: Data, role: KeyRole) throws -> String {
        guard role == .vrf else { return try verificationKeyHash(payload: payload) }
        guard payload.count == 32 else {
            throw SwiftCardanoMultitoolError.valueError("Expected a 32-byte VRF verification key, got \(payload.count) bytes.")
        }
        // VRF key hashes are blake2b-256 of the whole key.
        return try blake2b(payload, digestSize: 32).toHex
    }

    static func verificationKeyHash(payload: Data) throws -> String {
        guard payload.count == 32 || payload.count == 64 else {
            throw SwiftCardanoMultitoolError.valueError(
                "Expected a 32-byte or 64-byte (extended) verification key, got \(payload.count) bytes."
            )
        }
        return try blake2b(payload.prefix(32), digestSize: 28).toHex
    }

    /// The key payload of a verification key given as Bech32 (`addr_vk1…`, `stake_xvk1…`) or hex.
    static func verificationKeyPayload(from text: String, role: KeyRole) throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let separator = trimmed.lastIndex(of: "1"),
           role.bech32Prefixes.contains(String(trimmed[..<separator])) {
            guard let payload = Bech32().decode(addr: trimmed) else {
                throw SwiftCardanoMultitoolError.valueError("Invalid Bech32 \(role.label) verification key: \(trimmed)")
            }
            return payload
        }
        let hex = trimmed.hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed
        if let payload = Data(hexString: hex), payload.count == 32 || (role.allowsExtended && payload.count == 64) {
            return payload
        }
        throw SwiftCardanoMultitoolError.valueError(
            "Expected a Bech32 (\(role.bech32Prefixes.map { "\($0)1…" }.joined(separator: ", "))) or hex \(role.label) verification key."
        )
    }

    /// Load a verification key file for a role. Keys of another type are rejected when the
    /// role requires a matching type, as cardano-cli does.
    static func verificationKeyFile(_ path: FilePath, role: KeyRole) throws -> (envelope: Envelope, payload: Data) {
        let loaded = try verificationKeyFile(path)
        if role.requiresMatchingType, !isExpectedKeyType(loaded.envelope.type, role: role) {
            throw SwiftCardanoMultitoolError.valueError(
                "\(path.string) is a \(loaded.envelope.type) key, not a \(role.label) verification key."
            )
        }
        if loaded.payload.count != 32, !(role.allowsExtended && loaded.payload.count == 64) {
            throw SwiftCardanoMultitoolError.valueError(
                "\(path.string) has an unexpected key size of \(loaded.payload.count) bytes."
            )
        }
        return loaded
    }

    /// Load a verification key file and return its envelope and key payload.
    ///
    /// Signing keys are rejected so a secret is never hashed by mistake.
    static func verificationKeyFile(_ path: FilePath) throws -> (envelope: Envelope, payload: Data) {
        let envelope = try Envelope(path: path)
        guard !envelope.type.contains("SigningKey") else {
            throw SwiftCardanoMultitoolError.valueError(
                "\(path.string) is a signing key (\(envelope.type)). Pass the verification key file instead."
            )
        }
        guard envelope.type.contains("VerificationKey") else {
            throw SwiftCardanoMultitoolError.valueError(
                "\(path.string) is not a verification key file (type: \(envelope.type))."
            )
        }
        return (envelope, try envelope.keyPayload)
    }

    /// True when the envelope type is one normally used for the given role.
    static func isExpectedKeyType(_ type: String, role: KeyRole) -> Bool {
        role.envelopeTypePrefixes.contains { type.hasPrefix($0) }
    }

    // MARK: - Script hash

    /// Hash of a native script JSON file or a Plutus script text envelope.
    static func scriptHash(scriptFile path: FilePath) throws -> (kind: String, hash: String) {
        guard let data = FileManager.default.contents(atPath: path.string) else {
            throw SwiftCardanoMultitoolError.fileNotFound(path)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SwiftCardanoMultitoolError.valueError("\(path.string) is not a script JSON file.")
        }

        if json["cborHex"] != nil {
            let envelope = try Envelope(json: data, source: path.string)
            return try plutusScriptHash(envelope: envelope)
        }

        let script = try nativeScript(fromJSON: json)
        return ("Native script", try script.scriptHash().payload.toHex)
    }

    /// Parse a cardano-cli simple script JSON object.
    static func nativeScript(fromJSON json: [String: Any]) throws -> NativeScript {
        let data = try JSONSerialization.data(withJSONObject: json)
        return try NativeScript.fromJSON(String(decoding: data, as: UTF8.self))
    }

    /// Hash of a Plutus script text envelope (`PlutusScriptV1`/`V2`/`V3`).
    static func plutusScriptHash(envelope: Envelope) throws -> (kind: String, hash: String) {
        let version: UInt8
        switch envelope.type {
            case "PlutusScriptV1": version = 1
            case "PlutusScriptV2": version = 2
            case "PlutusScriptV3": version = 3
            default:
                throw SwiftCardanoMultitoolError.valueError(
                    "Unsupported script type '\(envelope.type)'. Expected a native script or PlutusScriptV1/V2/V3."
                )
        }
        // The envelope holds the CBOR-wrapped flat script; the hash covers the language tag
        // followed by the flat script bytes.
        let flat = try envelope.keyPayload
        return ("Plutus V\(version) script", try blake2b(Data([version]) + flat, digestSize: 28).toHex)
    }

    // MARK: - Address credentials

    /// Which credential of an address to read.
    enum AddressPart: Sendable {
        case payment
        case stake

        var label: String { self == .payment ? "payment" : "stake" }
    }

    /// A credential hash read from an address.
    struct AddressCredential: Equatable, Sendable {
        let hash: Data
        let isScript: Bool
        /// e.g. "Base address", "Stake address".
        var addressType: String = ""
        /// "Mainnet" or "Testnet".
        var network: String = ""

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.hash == rhs.hash && lhs.isScript == rhs.isScript
        }
    }

    /// The address given as Bech32 (`addr1…`, `stake1…`), a path to an address file, or
    /// an address name (`owner` → `owner.payment.addr` / `owner.addr`, or `owner.stake.addr`).
    static func addressText(_ input: String, part: AddressPart, directory: FilePath = FilePath(FileManager.default.currentDirectoryPath)) throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if isBech32Address(trimmed) {
            return trimmed
        }
        var candidates = [FileUtils.absolutePath(FilePath(trimmed))]
        switch part {
            case .payment:
                if let resolved = PaymentAddressFiles.resolve(name: trimmed, in: directory) {
                    candidates.append(resolved)
                }
            case .stake:
                let stem = PaymentAddressFiles.stem(of: trimmed)
                candidates.append(directory.appending("\(stem).stake.addr"))
                if let resolved = PaymentAddressFiles.resolve(name: trimmed, in: directory) {
                    candidates.append(resolved)
                }
        }
        for candidate in candidates {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: candidate.string, isDirectory: &isDirectory), !isDirectory.boolValue,
                  let contents = try? String(contentsOfFile: candidate.string, encoding: .utf8) else { continue }
            let address = contents.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isBech32Address(address) else {
                throw SwiftCardanoMultitoolError.valueError("\(candidate.string) does not contain a Bech32 address.")
            }
            return address
        }
        throw SwiftCardanoMultitoolError.valueError(
            "Expected a Bech32 address (addr1…, stake1…), an address file or an address name: \(trimmed)"
        )
    }

    private static func isBech32Address(_ text: String) -> Bool {
        ["addr1", "addr_test1", "stake1", "stake_test1"].contains { text.hasPrefix($0) }
            && Bech32().decode(addr: text) != nil
    }

    /// The raw bytes of a Bech32 Shelley address.
    static func addressBytes(bech32 address: String) throws -> Data {
        guard let bytes = Bech32().decode(addr: address) else {
            throw SwiftCardanoMultitoolError.valueError("Invalid Bech32 address: \(address)")
        }
        return bytes
    }

    /// Read the payment or stake credential from raw address bytes (CIP-19).
    ///
    /// Base addresses carry both; enterprise and pointer addresses only a payment
    /// credential; stake (reward) addresses only a stake credential.
    static func credential(fromAddressBytes bytes: Data, part: AddressPart) throws -> AddressCredential {
        guard let header = bytes.first else {
            throw SwiftCardanoMultitoolError.valueError("The address is empty.")
        }
        let type = header >> 4
        let network = header & 0x0f == 1 ? "Mainnet" : "Testnet"
        let addressType: String
        switch type {
            case 0...3: addressType = "Base address"
            case 4, 5: addressType = "Pointer address"
            case 6, 7: addressType = "Enterprise address"
            case 14, 15: addressType = "Stake address"
            default: addressType = "Address type \(type)"
        }
        let body = bytes.dropFirst()
        func hash(at offset: Int) throws -> Data {
            guard body.count >= offset + 28 else {
                throw SwiftCardanoMultitoolError.valueError("The address is too short for its type.")
            }
            let start = body.startIndex + offset
            return Data(body[start ..< start + 28])
        }

        switch (part, type) {
            case (.payment, 0...7):
                // Types 1, 3, 5 and 7 have a script payment credential.
                return AddressCredential(hash: try hash(at: 0), isScript: type & 1 == 1, addressType: addressType, network: network)
            case (.payment, 14), (.payment, 15):
                throw SwiftCardanoMultitoolError.valueError("A stake address has no payment credential. Use 'scm hash stake-key' instead.")
            case (.stake, 0...3):
                // Types 2 and 3 have a script stake credential.
                return AddressCredential(hash: try hash(at: 28), isScript: type & 2 == 2, addressType: addressType, network: network)
            case (.stake, 14), (.stake, 15):
                return AddressCredential(hash: try hash(at: 0), isScript: type == 15, addressType: addressType, network: network)
            case (.stake, 4), (.stake, 5):
                throw SwiftCardanoMultitoolError.valueError("A pointer address has no stake credential hash, only a pointer to a stake registration.")
            case (.stake, 6), (.stake, 7):
                throw SwiftCardanoMultitoolError.valueError("An enterprise address has no stake credential.")
            case (_, 8):
                throw SwiftCardanoMultitoolError.valueError("Byron addresses have no \(part.label) credential hash.")
            default:
                throw SwiftCardanoMultitoolError.valueError("Unsupported address type \(type).")
        }
    }

    /// Read the credential from the `base16` field of `cardano-cli address info` output.
    static func credential(fromAddressInfo json: String, part: AddressPart) throws -> AddressCredential {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base16 = object["base16"] as? String,
              let bytes = Data(hexString: base16) else {
            throw SwiftCardanoMultitoolError.valueError("Unexpected cardano-cli address info output.")
        }
        return try credential(fromAddressBytes: bytes, part: part)
    }

    // MARK: - DRep and pool identifiers

    /// The DRep key hash from `--drep-key-hash`: hex, a CIP-105 `drep1…`/`drep_vkh1…`
    /// ID, or a CIP-129 `drep1…` key ID.
    static func drepKeyHash(from text: String) throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed
        if let data = Data(hexString: hex), data.count == 28 {
            return data
        }
        if trimmed.hasPrefix("drep"), let data = Bech32().decode(addr: trimmed) {
            if data.count == 28 {
                return data
            }
            // CIP-129: header 0x22 is a DRep key hash, 0x23 a script hash.
            if data.count == 29, data.first == 0x22 {
                return data.dropFirst()
            }
            if data.count == 29, data.first == 0x23 {
                throw SwiftCardanoMultitoolError.valueError("\(trimmed) is a DRep script ID, not a key ID.")
            }
        }
        throw SwiftCardanoMultitoolError.valueError("Expected a 28-byte hex DRep key hash or a drep1… ID: \(trimmed)")
    }

    /// DRep identifiers for a key hash.
    static func drepIds(keyHash: Data) throws -> (hex: String, cip105: String, cip129: String) {
        let hash = VerificationKeyHash(payload: keyHash)
        return (
            keyHash.toHex,
            try DRep(credential: .verificationKeyHash(hash)).id(),
            try DRepCredential(credential: .verificationKeyHash(hash)).id()
        )
    }

    /// Pool IDs for a pool key hash.
    static func poolIds(keyHash: Data) throws -> (hex: String, bech32: String) {
        (keyHash.toHex, try PoolOperator(poolKeyHash: PoolKeyHash(payload: keyHash)).toBech32())
    }

    // MARK: - Metadata

    /// Validate stake pool metadata the way cardano-cli does before hashing it:
    /// at most 512 bytes and a JSON object with string `name` (≤ 50 characters),
    /// `description` (≤ 255), `ticker` (3–5) and `homepage`. Other fields are allowed.
    static func validatePoolMetadata(_ data: Data) throws {
        guard data.count <= 512 else {
            throw SwiftCardanoMultitoolError.valueError(
                "Stake pool metadata must consist of at most 512 bytes, but it consists of \(data.count) bytes."
            )
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw SwiftCardanoMultitoolError.valueError("Stake pool metadata is not valid JSON.")
        }
        guard let object = json as? [String: Any] else {
            throw SwiftCardanoMultitoolError.valueError("Stake pool metadata must be a JSON object.")
        }
        func text(_ key: String) throws -> String {
            guard let value = object[key] else {
                throw SwiftCardanoMultitoolError.valueError("Stake pool metadata is missing \"\(key)\".")
            }
            guard let string = value as? String else {
                throw SwiftCardanoMultitoolError.valueError("Stake pool metadata \"\(key)\" must be a string.")
            }
            return string
        }
        // Lengths count Unicode code points, like cardano-cli.
        let name = try text("name").unicodeScalars.count
        guard name <= 50 else {
            throw SwiftCardanoMultitoolError.valueError("\"name\" must have at most 50 characters, but it has \(name) characters.")
        }
        let description = try text("description").unicodeScalars.count
        guard description <= 255 else {
            throw SwiftCardanoMultitoolError.valueError("\"description\" must have at most 255 characters, but it has \(description) characters.")
        }
        let ticker = try text("ticker").unicodeScalars.count
        guard (3...5).contains(ticker) else {
            throw SwiftCardanoMultitoolError.valueError("\"ticker\" must have at least 3 and at most 5 characters, but it has \(ticker) characters.")
        }
        _ = try text("homepage")
    }

    /// Download metadata from a URL (HTTP(S) or IPFS).
    static func downloadMetadata(_ url: String) async throws -> Data {
        try await downloadAnchorData(url)
    }

    // MARK: - Anchor data / genesis

    /// Blake2b-256 of anchor data, as used by governance anchors.
    static func anchorDataHash(_ data: Data) throws -> String {
        try blake2b(data, digestSize: 32).toHex
    }

    /// Blake2b-256 of a genesis file's exact bytes, as written in the node configuration.
    static func genesisFileHash(_ path: FilePath) throws -> String {
        guard let data = FileManager.default.contents(atPath: path.string) else {
            throw SwiftCardanoMultitoolError.fileNotFound(path)
        }
        return try blake2b(data, digestSize: 32).toHex
    }

    /// A 32-byte hash given as hex, normalized to lowercase.
    static func normalizedHash32(_ text: String) -> String? {
        let hex = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard hex.count == 64, Data(hexString: hex) != nil else { return nil }
        return hex
    }

    /// The HTTP(S) URL to download for an anchor URL. `ipfs://` URLs go through the
    /// gateway in `IPFS_GATEWAY_URI` (as cardano-cli does), defaulting to ipfs.io.
    static func anchorDownloadURL(_ url: String) throws -> URL {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("ipfs://") {
            let cid = String(trimmed.dropFirst("ipfs://".count))
            var gateway = ProcessInfo.processInfo.environment["IPFS_GATEWAY_URI"] ?? "https://ipfs.io/"
            if !gateway.hasSuffix("/") { gateway += "/" }
            guard let resolved = URL(string: "\(gateway)ipfs/\(cid)") else {
                throw SwiftCardanoMultitoolError.valueError("Invalid IPFS URL: \(trimmed)")
            }
            return resolved
        }
        guard let resolved = URL(string: trimmed),
              let scheme = resolved.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw SwiftCardanoMultitoolError.valueError("Only HTTP(S) and IPFS URLs are supported: \(trimmed)")
        }
        return resolved
    }

    static func downloadAnchorData(_ url: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: try anchorDownloadURL(url))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SwiftCardanoMultitoolError.valueError("Download failed with HTTP status \(http.statusCode): \(url)")
        }
        return data
    }

    // MARK: - Output

}

/// What was hashed, how, and the result, for the hash commands' output.
struct HashReport {
    /// The result name, e.g. "Payment Key Hash".
    var title: String
    /// One line on what is being hashed, e.g. "Hashing a payment verification key".
    var summary: String
    /// Details of the input, shown in order.
    var inputs: [(String, String)] = []
    /// How the result is produced, e.g. "blake2b-224 of the 32-byte public key → 28-byte key hash".
    var method: String
    var hash: String
    /// Other forms of the same result (IDs, formats), shown under the hash.
    var related: [(String, String)] = []
    var tool: Tool? = nil
    var outFile: FilePath? = nil
    /// Compared with the result; a mismatch fails the command.
    var expectedHash: String? = nil
}

extension HashUtils {
    /// Print a hash report. Piped output gets only the hash so it can be captured
    /// (`HASH=$(scm hash script …)`); a terminal gets the details and the result.
    static func emit(_ report: HashReport) throws {
        if let outFile = report.outFile {
            try report.hash.write(toFile: FileUtils.absolutePath(outFile).string, atomically: true, encoding: .utf8)
        }

        let terminal = isatty(FileHandle.standardOutput.fileDescriptor) != 0
        guard terminal else {
            print(report.hash)
            try checkExpectedHash(report.expectedHash, computed: report.hash, terminal: false)
            return
        }

        print()
        if let tool = report.tool {
            spacedPrint("Using \(.primary(tool == .cardanoCLI ? "cardano-cli" : "SwiftCardano")) to compute the \(report.title)")
        }

        var takeaways: [TerminalText] = report.inputs.map { label, value in "\(label): \(.primary(value))" }
        takeaways.append("Method: \(.accent(report.method))")
        noora.info(.alert("\(report.summary)", takeaways: takeaways))
        print()

        print(noora.format("\(report.title): \(.primary(report.hash))"))
        for (label, value) in report.related where value != report.hash {
            print(noora.format("\(label): \(.primary(value))"))
        }
        print()

        if let outFile = report.outFile {
            spacedPrint("Saved to: \(pathComponent(outFile.string))")
        }

        if report.expectedHash != nil {
            try checkExpectedHash(report.expectedHash, computed: report.hash, terminal: true)
        } else {
            noora.success(.alert("\(report.title) computed."))
        }
    }

    /// Short description of a byte count, e.g. "1,024 bytes".
    static func byteCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "\(formatter.string(from: NSNumber(value: count)) ?? String(count)) byte\(count == 1 ? "" : "s")"
    }
}

/// The tool passed on the command line, or the configured/prompted default.
func resolveTool(_ tool: Tool?) async throws -> Tool {
    if let tool { return tool }
    return try await getToolToUse()
}

extension HashUtils {
    /// A cardano-cli wrapper for the active configuration, quiet when output is piped.
    static func cardanoCLI() async throws -> CardanoCLI {
        let config = try await MultitoolConfig.load(quiet: isatty(FileHandle.standardOutput.fileDescriptor) == 0)
        return try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig())
    }

    /// Compare a computed hash with `--expected-hash`, failing when they differ.
    static func checkExpectedHash(_ expectedHash: String?, computed hash: String, terminal: Bool) throws {
        guard let expectedHash, let expected = normalizedHash32(expectedHash) else { return }
        guard expected == hash.lowercased() else {
            noora.error(.alert(
                "Hashes do not match.",
                takeaways: [
                    "Expected: \(.danger(expected))",
                    "Computed: \(.primary(hash))",
                ]
            ))
            throw ExitCode.failure
        }
        if terminal {
            noora.success(.alert("The hash matches the expected hash."))
        }
    }

    /// Write a verification key to a temporary text envelope file for tools that only take files.
    static func temporaryKeyFile(type: String, payload: Data) throws -> FilePath {
        let cbor = (payload.count < 24 ? Data([0x40 + UInt8(payload.count)]) : Data([0x58, UInt8(payload.count)])) + payload
        let json = #"{"type": "\#(type)", "description": "", "cborHex": "\#(cbor.toHex)"}"#
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scm-\(UUID().uuidString).vkey")
        try json.write(to: url, atomically: true, encoding: .utf8)
        return FilePath(url.path)
    }
}
