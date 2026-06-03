import Foundation
import ArgumentParser
import Noora
import SwiftCardanoChain
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftNaCl
import SystemPackage

/// Print the three forms of a DRep identifier: Legacy (CIP-105) bech32, CIP-129 bech32, and the raw hex hash.
public func drepIdSummary(drep: DRep) throws {
    switch drep.credential {
        case .alwaysAbstain:
            noora.info(.alert(
                "DRep: \(.primary("ALWAYS ABSTAIN"))",
                takeaways: ["Protocol-level constant DRep — not registered on chain."]
            ))
        case .alwaysNoConfidence:
            noora.info(.alert(
                "DRep: \(.primary("ALWAYS NO CONFIDENCE"))",
                takeaways: ["Protocol-level constant DRep — not registered on chain."]
            ))
        case .verificationKeyHash, .scriptHash:
            let keyType: String = {
                switch drep.credential {
                    case .scriptHash: return "scriptHash"
                    default: return "keyHash"
                }
            }()
            noora.info(.alert(
                "DRep IDs:",
                takeaways: [
                    "Legacy CIP-105: \(.primary(try drep.id((.bech32, .cip105))))",
                    "CIP-129:        \(.primary(try drep.id((.bech32, .cip129))))",
                    "DRep HASH:      \(.primary(try drep.idHex(.cip105)))",
                    "Key Type:       \(.primary(keyType))",
                ]
            ))
    }
}

/// Print the on-chain status of a DRep using the data returned by `context.drepInfo(drep:)`.
///
/// Backend gaps surface as `N/A` plus a single `noora.warning` naming the active backend, per the
/// project's "show N/A + warn" policy:
/// - BlockFrost cannot report `deposit` or `expiry`.
/// - NodeSocket (Ogmios) cannot report `stake`.
public func drepInfoSummary(
    drep: DRep,
    info: DRepInfo,
    currentEpoch: Int,
    context: any ChainContext
) throws {
    // Status header
    switch info.status {
        case .notRegistered, .none:
            noora.error(.alert(
                "DRep Status: \(.danger("✗ Not registered on chain"))"
            ))
            return
        case .retired:
            spacedPrint("DRep Status: \(.danger("✗ Retired"))")
        case .registered:
            if let expiry = info.expiry, expiry < UInt64(currentEpoch) {
                spacedPrint(
                    "DRep Status: \(.success("✓ Registered")) — \(.danger("activity expired"))"
                )
            } else {
                spacedPrint("DRep Status: \(.success("✓ Registered"))")
            }
    }

    let depositDisplay: String
    if let deposit = info.deposit {
        depositDisplay = "\(lovelaceToAdaString(deposit)) (\(deposit) lovelaces)"
    } else {
        depositDisplay = "N/A"
    }
    spacedPrint("Deposit:        \(.primary(depositDisplay))")

    if let expiry = info.expiry {
        let expiryStyled: TerminalText = expiry < UInt64(currentEpoch)
            ? "\(.danger("\(expiry)"))"
            : "\(.success("\(expiry)"))"
        spacedPrint("Expire Epoch:   \(expiryStyled)")
    } else {
        spacedPrint("Expire Epoch:   \(.muted("N/A"))")
    }
    spacedPrint("Current Epoch:  \(.primary("\(currentEpoch)"))")

    if context is NodeSocketChainContext {
        spacedPrint("Delegated Stake: \(.muted("N/A"))")
    } else {
        spacedPrint(
            "Delegated Stake: \(.primary("\(lovelaceToAdaString(info.stake)) (\(info.stake) lovelaces)"))"
        )
    }

    if let anchor = info.anchor {
        spacedPrint("Anchor URL:     \(.link(title: anchor.anchorUrl.absoluteString, href: anchor.anchorUrl.absoluteString))")
        spacedPrint("Anchor HASH:    \(.primary(anchor.anchorDataHash.payload.toHex))")
    } else {
        spacedPrint("Anchor:         \(.muted("none published"))")
    }

    // Backend-gap warning
    let backendName = String(describing: type(of: context))
    var missing: [String] = []
    if info.deposit == nil { missing.append("deposit") }
    if info.expiry == nil { missing.append("expiry") }
    if context is NodeSocketChainContext { missing.append("delegatedStake") }

    if !missing.isEmpty {
        print()
        noora.warning(.alert(
            "Backend \(.primary(backendName)) does not report: \(.danger(missing.joined(separator: ", ")))",
            takeaway: "Switch to Koios or cardano-cli mode for full coverage."
        ))
    }
}

/// Download the anchor URL, verify the blake2b-256 hash matches the on-chain hash, then optionally
/// run `cardano-signer verify --cip100` for per-author CIP-100 JSON-LD signature verification.
///
/// Skips silently (with a `noora.warning`) when `cardano-signer` is not configured / installed.
public func verifyDRepAnchor(
    anchor: Anchor,
    config: MultitoolConfig
) async throws {
    // Rewrite ipfs:// URLs through the public ipfs.io gateway, mirroring the bash script.
    let originalUrl = anchor.anchorUrl.absoluteString
    let queryUrl: URL
    if originalUrl.hasPrefix("ipfs://") {
        let cid = String(originalUrl.dropFirst("ipfs://".count))
        guard let rewritten = URL(string: "https://ipfs.io/ipfs/\(cid)") else {
            noora.warning(.alert("Could not rewrite IPFS URL: \(.danger(originalUrl))"))
            return
        }
        queryUrl = rewritten
    } else {
        guard let url = URL(string: originalUrl) else {
            noora.warning(.alert("Anchor URL is not a valid URL: \(.danger(originalUrl))"))
            return
        }
        queryUrl = url
    }

    spacedPrint("Query URL:      \(.link(title: queryUrl.absoluteString, href: queryUrl.absoluteString))")

    // Download
    let downloadedData: Data
    do {
        downloadedData = try await noora.progressStep(
            message: "Downloading anchor content...",
            successMessage: "Anchor content downloaded.",
            errorMessage: "Failed to download anchor content.",
            showSpinner: true
        ) { _ in
            let (data, _) = try await URLSession.shared.data(from: queryUrl)
            return data
        }
    } catch {
        noora.warning(.alert(
            "Anchor STATUS: \(.danger("download failed"))",
            takeaway: "\(error)"
        ))
        return
    }

    // JSON sanity-check
    guard (try? JSONSerialization.jsonObject(with: downloadedData)) != nil else {
        noora.warning(.alert("Anchor STATUS: \(.danger("not valid JSON"))"))
        return
    }

    // Blake2b-256 hash compare
    let computedHash: Data
    do {
        computedHash = try SwiftNaCl.Hash().blake2b(
            data: downloadedData,
            digestSize: 32,
            encoder: RawEncoder.self
        )
    } catch {
        noora.warning(.alert(
            "Anchor Status: \(.danger("could not compute blake2b hash: \(error)"))"
        ))
        return
    }

    if computedHash == anchor.anchorDataHash.payload {
        spacedPrint("Anchor Status:  \(.success("✓ File-Content-HASH is OK"))")
    } else {
        noora.warning(.alert(
            "Anchor Status: \(.danger("✗ HASH does not match!"))",
            takeaway: "On-chain: \(.muted(anchor.anchorDataHash.payload.toHex)) / Computed: \(.muted(computedHash.toHex))"
        ))
        return
    }

    // Write to a temp file so cardano-signer can read it.
    let tmpDir = FileManager.default.temporaryDirectory
    let tmpFile = tmpDir.appendingPathComponent("DRepAnchorURLContent-\(UUID().uuidString).tmp")
    do {
        try downloadedData.write(to: tmpFile)
    } catch {
        noora.warning(.alert(
            "Could not write anchor content to temp file: \(.danger("\(error)"))",
            takeaway: "Skipping CIP-100 signature verification."
        ))
        return
    }
    defer { try? FileManager.default.removeItem(at: tmpFile) }

    // CIP-100 verify via cardano-signer.
    //
    // We resolve the binary path from config directly and exec it via Process rather than going
    // through `CardanoSigner(configuration:)`. The high-level wrapper's `version()` call runs
    // `cardano-signer help`, which exits with code 1 in current builds (even when the help screen
    // prints fine) — that throws during init and we never reach `verify`. This bypass avoids the
    // upstream bug; consider PRing swift-cardano-utils to use `--version` instead of `help`.
    let signerPath = config.cardano?.signer
    guard let signerPath, FileManager.default.isExecutableFile(atPath: signerPath.string) else {
        noora.warning(.alert(
            "CIP-100 verify skipped: \(.danger("cardano-signer not configured or not executable"))",
            takeaway: "Set `cardano.signer` in your config to a working cardano-signer binary (e.g. `scm install cardano-signer`)."
        ))
        return
    }

    let rawOutput: String
    do {
        rawOutput = try await noora.progressStep(
            message: "Running cardano-signer verify --cip100...",
            successMessage: "CIP-100 verification complete.",
            errorMessage: "CIP-100 verification failed.",
            showSpinner: true
        ) { _ in
            try runSignerVerifyCIP100(signerPath: signerPath, dataFile: tmpFile)
        }
    } catch {
        noora.warning(.alert(
            "Anchor Data: \(.danger("✗ \(error)"))"
        ))
        return
    }
    print()

    // Parse the JSON-extended response. cardano-signer emits a JSON object with optional
    // `errorMsg` and an `authors` array of `{name, valid}` entries.
    guard let jsonData = rawOutput.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
        noora.warning(.alert(
            "Anchor Data: \(.danger("could not parse cardano-signer JSON output"))"
        ))
        return
    }

    spacedPrint("Anchor Data:    \(.success("✓ JSONLD structure is ok"))")

    let authors = (json["authors"] as? [[String: Any]]) ?? []
    let errorMsg = (json["errorMsg"] as? String) ?? ""

    if authors.isEmpty {
        // CIP-100 author signatures are optional. cardano-signer reports `errorMsg: "missing
        // authors field"` (or similar) when none are declared — that's normal for unsigned
        // governance metadata, not a verification failure.
        spacedPrint("Author Sigs:    \(.muted("none declared (CIP-100 authors are optional)"))")
    } else {
        var lines: [TerminalText] = []
        for author in authors {
            let name = (author["name"] as? String) ?? "(unnamed)"
            let valid = (author["valid"] as? Bool) ?? false
            let icon: TerminalText = valid
                ? "\(.success("✓"))"
                : "\(.danger("✗"))"
            lines.append("Signature: \(icon) \(.primary(name))")
        }
        noora.info(.alert(
            "Author Signatures:",
            takeaways: lines
        ))

        // Surface any errorMsg only when authors were actually declared — at that point a
        // non-empty errorMsg signals a real verification problem (bad signature, malformed
        // entry, etc.), not just "nothing was signed".
        if !errorMsg.isEmpty {
            noora.warning(.alert(
                "Author verification: \(.danger(errorMsg))"
            ))
        }
    }
}

/// Run `cardano-signer verify --cip100 --data-file <path> --json-extended` directly via Process
/// and return stdout. `cardano-signer` exits 0 when verification succeeds and 1 when it fails;
/// both produce valid JSON on stdout describing the per-author results, so non-zero exit is
/// expected on a failing verify and is NOT treated as an error here.
private func runSignerVerifyCIP100(signerPath: SystemPackage.FilePath, dataFile: URL) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: signerPath.string)
    process.arguments = [
        "verify",
        "--cip100",
        "--data-file", dataFile.path,
        "--json-extended",
    ]

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()
    process.waitUntilExit()

    let outData = stdout.fileHandleForReading.readDataToEndOfFile()
    return String(data: outData, encoding: .utf8) ?? ""
}
