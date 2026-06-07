import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoTokenRegistry

// MARK: - Asset subject resolution

/// Resolve user input to a hex asset subject. Mirrors the bash logic in
/// `12b_checkAssetMetaServer.sh`: try as a file path first (a .asset JSON file
/// carrying a top-level `subject` field), then fall back to interpreting the input
/// as a direct hex subject.
func resolveAssetSubject(input: String) throws -> String {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

    if FileManager.default.fileExists(atPath: trimmed) {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: trimmed))
        } catch {
            noora.error(.alert(
                "Could not read asset file at \(.danger(trimmed)): \(error.localizedDescription)"
            ))
            throw ExitCode.failure
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            noora.error(.alert(
                "Asset file \(.danger(trimmed)) is not a valid JSON object.",
                takeaways: ["Expected an object with a top-level `subject` field."]
            ))
            throw ExitCode.failure
        }

        guard let subject = json["subject"] as? String else {
            noora.error(.alert(
                "Asset file \(.danger(trimmed)) is missing a `subject` field.",
                takeaways: ["Expected a top-level `subject` field containing the policyId || assetNameHex."]
            ))
            throw ExitCode.failure
        }

        let normalized = subject.lowercased()
        guard isValidAssetSubject(normalized) else {
            noora.error(.alert(
                "The `subject` field in \(.danger(trimmed)) is not a valid asset subject.",
                takeaways: ["Expected 56-120 hex characters."]
            ))
            throw ExitCode.failure
        }

        noora.info(.alert("Using local Asset-File: \(.primary(trimmed))"))
        return normalized
    }

    let normalized = trimmed.lowercased()
    if isValidAssetSubject(normalized) {
        return normalized
    }

    noora.error(.alert(
        "The provided input is not a valid asset file or asset subject.",
        takeaways: [
            "Pass a path to a .asset JSON file with a top-level `subject` field, OR",
            "Pass a 56-120 character hex string (policyId || assetNameHex)."
        ]
    ))
    throw ExitCode.failure
}

/// `true` when the string contains only hex characters and is 56-120 chars long.
/// Matches the bash regex `[!:xdigit:]` length check.
func isValidAssetSubject(_ value: String) -> Bool {
    guard (56...120).contains(value.count) else { return false }
    return value.allSatisfy { $0.isHexDigit }
}

// MARK: - HTTP fetch

/// Fetch and decode asset metadata from `<registryURL>/<subject>`. Returns the decoded
/// entry and the raw response bytes; nil metadata signals an empty body (the registry's
/// "no data found" convention).
func fetchAssetMetadata(subject: String, registryURL: URL) async throws -> (GoguenRegistryEntry?, Data) {
    let fullURL = registryURL.appendingPathComponent(subject)

    let (data, _) = try await URLSession.shared.data(from: fullURL)

    let trimmed = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed?.isEmpty ?? true {
        return (nil, data)
    }

    let entry = try JSONDecoder().decode(GoguenRegistryEntry.self, from: data)
    return (entry, data)
}

// MARK: - Display

/// Render the registry entry in the same shape as the bash script:
/// label + value + optional `(Seq: N)`. Decodes the logo PNG to a temp file so the
/// user can inspect it. Surfaces a single validation summary line after the fields.
func printAssetMetadata(_ entry: GoguenRegistryEntry, subject: String) throws {
    spacedPrint("Server Response: \(.success("✓ Valid JSON"))")

    printAttested(label: "       Name", attested: entry.name) {
        "\(.primary($0.value))"
    }
    printAttested(label: "Description", attested: entry.description) {
        "\(.primary($0.value))"
    }
    printAttested(label: "     Ticker", attested: entry.ticker) {
        "\(.primary($0.value))"
    }
    printAttested(label: "        URL", attested: entry.url) {
        "\(.link(title: $0.value.absoluteString, href: $0.value.absoluteString))"
    }
    printAttested(label: "   Decimals", attested: entry.decimals) {
        "\(.primary("\($0.value)"))"
    }
    printLogoProperty(entry.logo, subject: subject)
    printValidationStatus(entry)
}

private func printAttested<P: WellKnownProperty>(
    label: String,
    attested: Attested<P>?,
    show: (P) -> TerminalText
) {
    guard let attested = attested else {
        spacedPrint("\(.muted("\(label):"))")
        return
    }
    let valueText = show(attested.value)
    spacedPrint("\(.muted("\(label):")) \(valueText) \(.muted("(Seq: \(attested.sequenceNumber.value))"))")
}

private func printLogoProperty(_ attested: Attested<WellKnown.Logo>?, subject: String) {
    guard let attested = attested else {
        spacedPrint("\(.muted("    LogoPNG:"))")
        return
    }

    let pngData = attested.value.data
    let tmpFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("scm-asset-logo-\(subject.prefix(16))-\(UUID().uuidString).png")
    do {
        try pngData.write(to: tmpFile)
    } catch {
        spacedPrint("\(.muted("    LogoPNG:")) \(.primary("\(pngData.count) bytes")) \(.danger("(could not write to temp file: \(error.localizedDescription))"))")
        return
    }

    spacedPrint("\(.muted("    LogoPNG:")) \(.primary("\(pngData.count) bytes")) \(.muted("(Seq: \(attested.sequenceNumber.value), extracted to \(tmpFile.path))"))")
}

private func printValidationStatus(_ entry: GoguenRegistryEntry) {
    let issues = entry.validate(options: .lenient)
    if issues.isEmpty {
        spacedPrint(" Validation: \(.success("✓ all attestations + policy match"))")
        return
    }
    spacedPrint(" Validation: \(.danger("\(issues.count) issue(s)"))")
    for issue in issues {
        spacedPrint("             \(.muted("•")) \(.danger("\(issue.description)"))")
    }
}

// MARK: - Asset name parsing

/// Parse a user-supplied asset name. Accepts either:
///   - ASCII alphanumeric (`MyToken`) — encoded as UTF-8 bytes,
///   - or a `{<hex>}` literal — the hex inside the braces is taken verbatim.
/// Returns the display name (for the sidecar `name` field) and the lowercase
/// hex bytes to concatenate into the asset subject. Asset name bytes must not
/// exceed 32 (CIP-14 max).
func parseAssetName(_ raw: String) throws -> (display: String, hex: String) {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
        return ("", "")
    }

    if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
        let hex = String(trimmed.dropFirst().dropLast()).lowercased()
        guard hex.count % 2 == 0, hex.allSatisfy({ $0.isHexDigit }) else {
            noora.error(.alert(
                "Invalid hex inside asset name braces: \(.danger(trimmed))",
                takeaways: ["Use even-length hex digits (0-9, a-f) between '{' and '}'."]
            ))
            throw ExitCode.validationFailure
        }
        guard hex.count <= 64 else {
            noora.error(.alert(
                "Asset name too long: \(hex.count / 2) bytes",
                takeaways: ["Cardano asset names are limited to 32 bytes (64 hex chars)."]
            ))
            throw ExitCode.validationFailure
        }
        let display: String
        if let bytes = Data(hexString: hex), let utf8 = String(data: bytes, encoding: .utf8) {
            display = utf8
        } else {
            display = trimmed
        }
        return (display, hex)
    }

    let allowedScalars: (Character) -> Bool = {
        $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "."
    }
    guard trimmed.allSatisfy(allowedScalars) else {
        noora.error(.alert(
            "Invalid characters in asset name: \(.danger(trimmed))",
            takeaways: [
                "Use letters, digits, '_', '-', or '.' for plain names.",
                "Use the \"{hex}\" form (e.g. \"{4d79546f6b656e}\") for arbitrary bytes."
            ]
        ))
        throw ExitCode.validationFailure
    }
    let bytes = Data(trimmed.utf8)
    guard bytes.count <= 32 else {
        noora.error(.alert(
            "Asset name too long: \(bytes.count) bytes",
            takeaways: ["Cardano asset names are limited to 32 bytes."]
        ))
        throw ExitCode.validationFailure
    }
    return (trimmed, bytes.toHex)
}

// MARK: - Policy loading

/// All of the on-disk artifacts a generate-asset-meta run needs from a policy.
struct LoadedAssetPolicy {
    let policyId: String
    let nativeScript: NativeScript
    let skeyPath: FilePath
    /// `nil` for sig-only policies; set when the script contains an `invalidBefore` clause.
    let validBeforeSlot: UInt64?
}

/// Read `<name>.policy.id`, `.policy.script`, and `.policy.skey` from `dir`. Rejects
/// hardware-wallet policies (`.hwsfile` only) — the Token Registry requires a software
/// Ed25519 signature.
func loadPolicyForAssetMeta(name: String, in dir: FilePath) throws -> LoadedAssetPolicy {
    let idFile = dir.appending("\(name).policy.id")
    let scriptFile = dir.appending("\(name).policy.script")
    let skeyFile = dir.appending("\(name).policy.skey")
    let hwsFile = dir.appending("\(name).policy.hwsfile")

    do {
        try FileUtils.checkFileExists(idFile)
        try FileUtils.checkFileExists(scriptFile)
    } catch {
        noora.error(.alert(
            "Policy files for '\(.primary(name))' not found in current directory.",
            takeaways: [
                "Expected: \(name).policy.id, \(name).policy.script, \(name).policy.skey",
                "Generate a policy first with 'scm generate policy'."
            ]
        ))
        throw ExitCode.failure
    }

    let hasSkey = FileManager.default.fileExists(atPath: skeyFile.string)
    let hasHws = FileManager.default.fileExists(atPath: hwsFile.string)
    if !hasSkey {
        if hasHws {
            noora.error(.alert(
                "Policy '\(.primary(name))' uses a hardware-wallet signing key.",
                takeaways: [
                    "Hardware-signed Token Registry metadata is not supported.",
                    "The registry requires a software Ed25519 signature."
                ]
            ))
        } else {
            noora.error(.alert(
                "Missing signing key file: \(.path(try .init(validating: skeyFile.string)))",
                takeaways: ["Expected \(name).policy.skey alongside the .policy.id and .policy.script files."]
            ))
        }
        throw ExitCode.failure
    }

    let policyId = try FileUtils.loadFile(idFile)
    let nativeScript = try NativeScript.loadJSON(from: scriptFile.string)

    var validBeforeSlot: UInt64? = nil
    if case .scriptAll(let all) = nativeScript {
        for child in all.scripts {
            if case .invalidBefore(let before) = child {
                validBeforeSlot = before.slot
                break
            }
        }
    } else if case .invalidBefore(let before) = nativeScript {
        validBeforeSlot = before.slot
    }

    return LoadedAssetPolicy(
        policyId: policyId,
        nativeScript: nativeScript,
        skeyPath: skeyFile,
        validBeforeSlot: validBeforeSlot
    )
}

// MARK: - Signer

/// Wraps a loaded software signing key with closures that sign each `Attested<P>` flavour,
/// so the call site doesn't have to branch on standard-vs-extended key types.
/// Mirrors the pattern used inside swift-cardano-token-registry's own `token-metadata`
/// CLI (`KeyLoader.Signer`).
struct AssetMetaSigner {
    let signName:        (inout Attested<WellKnown.Name>,        Subject) throws -> Void
    let signDescription: (inout Attested<WellKnown.Description>, Subject) throws -> Void
    let signTicker:      (inout Attested<WellKnown.Ticker>,      Subject) throws -> Void
    let signUrl:         (inout Attested<WellKnown.Url>,         Subject) throws -> Void
    let signLogo:        (inout Attested<WellKnown.Logo>,        Subject) throws -> Void
    let signDecimals:    (inout Attested<WellKnown.Decimals>,    Subject) throws -> Void
}

/// Load a policy signing key from disk for token-registry signing. Auto-decrypts
/// encrypted skeys via the existing `TextEnvelope.load` flow (prompts for password
/// or uses `CARDANO_MULTITOOL_DECRYPT_PASSWORD`). Dispatches on the envelope's
/// `type` to load either a standard or extended Ed25519 signing key.
func loadAssetMetaSigner(skeyPath: FilePath) async throws -> AssetMetaSigner {
    let envelope = try await TextEnvelope.load(from: skeyPath)

    guard let envType = envelope.type, let cborHex = envelope.cborHex else {
        noora.error(.alert(
            "Invalid signing key envelope at \(.path(try .init(validating: skeyPath.string))).",
            takeaways: [
                "Expected a cardano-cli text envelope with `type` and `cborHex` fields.",
                "If the key is encrypted, decryption must have succeeded before this point."
            ]
        ))
        throw ExitCode.failure
    }

    let tmpPath = FilePath(FileManager.default.temporaryDirectory.path)
        .appending("scm-asset-meta-skey-\(UUID().uuidString).json")
    let tmpJSON = """
    {
        "type": "\(envType)",
        "description": "\(envelope.description ?? "")",
        "cborHex": "\(cborHex)"
    }
    """
    try tmpJSON.write(toFile: tmpPath.string, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(atPath: tmpPath.string) }

    if envType.contains("Extended") {
        let key = try PaymentExtendedSigningKey.load(from: tmpPath.string)
        return AssetMetaSigner(
            signName:        { try $0.sign(subject: $1, with: key) },
            signDescription: { try $0.sign(subject: $1, with: key) },
            signTicker:      { try $0.sign(subject: $1, with: key) },
            signUrl:         { try $0.sign(subject: $1, with: key) },
            signLogo:        { try $0.sign(subject: $1, with: key) },
            signDecimals:    { try $0.sign(subject: $1, with: key) }
        )
    } else {
        let key = try PaymentSigningKey.load(from: tmpPath.string)
        return AssetMetaSigner(
            signName:        { try $0.sign(subject: $1, with: key) },
            signDescription: { try $0.sign(subject: $1, with: key) },
            signTicker:      { try $0.sign(subject: $1, with: key) },
            signUrl:         { try $0.sign(subject: $1, with: key) },
            signLogo:        { try $0.sign(subject: $1, with: key) },
            signDecimals:    { try $0.sign(subject: $1, with: key) }
        )
    }
}

// MARK: - Sidecar (.asset) file

/// Local state file written alongside the canonical registry JSON. Keeps the
/// metadata fields the user typed (so they can be reused on re-runs), the
/// policy + asset identifiers, and a sequence-number / last-update audit trail.
/// Compatible with `scm query asset-meta <path>` via the top-level `subject` field.
struct AssetSidecar: Codable, Sendable {
    var metaName: String
    var metaDescription: String
    var metaTicker: String?
    var metaUrl: String?
    var metaDecimals: Int?
    var metaLogoPNG: String?
    var name: String
    var hexname: String
    var policyID: String
    var policyValidBeforeSlot: String
    var subject: String
    var sequenceNumber: Int
    var lastUpdate: String
    var lastAction: String
}

func loadAssetSidecar(at path: FilePath) -> AssetSidecar? {
    guard FileManager.default.fileExists(atPath: path.string) else { return nil }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path.string)) else { return nil }
    return try? JSONDecoder().decode(AssetSidecar.self, from: data)
}

func writeAssetSidecar(_ sidecar: AssetSidecar, to path: FilePath) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
    let data = try encoder.encode(sidecar)
    try data.write(to: URL(fileURLWithPath: path.string), options: .atomic)
}

/// RFC 2822 timestamp for the sidecar's `lastUpdate` field (matches the bash format).
func rfc2822Timestamp(_ date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return formatter.string(from: date)
}
