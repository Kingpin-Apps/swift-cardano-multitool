import Foundation
import ArgumentParser
import Noora
import SwiftCardanoChain
import SwiftCardanoCore

/// Print the resolved committee credential in its three identifier forms (legacy CIP-105 bech32,
/// CIP-129 bech32, and hex hash) plus the key type. For ambiguous-hex input the caller hasn't
/// resolved cold vs hot yet — show the raw hex and a note that both lookups will be attempted.
public func committeeMemberIdSummary(input: CommitteeMemberCredential) throws {
    switch input {
        case .cold(let cold):
            let keyType: String = {
                switch cold.credential {
                    case .scriptHash: return "scriptHash"
                    case .verificationKeyHash: return "keyHash"
                }
            }()
            noora.info(.alert(
                "Committee Cold Credential:",
                takeaways: [
                    "Legacy CIP-105: \(.primary(try cold.id((.bech32, .cip105))))",
                    "CIP-129:        \(.primary(try cold.id((.bech32, .cip129))))",
                    "Cold HASH:      \(.primary(cold.credential.payload.toHex))",
                    "Key Type:       \(.primary(keyType))",
                ]
            ))
        case .hot(let hot):
            let keyType: String = {
                switch hot.credential {
                    case .scriptHash: return "scriptHash"
                    case .verificationKeyHash: return "keyHash"
                }
            }()
            noora.info(.alert(
                "Committee Hot Credential:",
                takeaways: [
                    "Legacy CIP-105: \(.primary(try hot.id((.bech32, .cip105))))",
                    "CIP-129:        \(.primary(try hot.id((.bech32, .cip129))))",
                    "Hot HASH:       \(.primary(hot.credential.payload.toHex))",
                    "Key Type:       \(.primary(keyType))",
                ]
            ))
        case .ambiguousHash(let data):
            noora.info(.alert(
                "Committee Credential (ambiguous):",
                takeaways: [
                    "Raw HASH:       \(.primary(data.toHex))",
                    "Lookup:         will try cold first, then fall back to hot.",
                ]
            ))
    }
}

/// Print the on-chain state for a committee member: status, cold credential block, hot
/// credential block (or "not authorized"), expiration vs current epoch. Surfaces a BlockFrost
/// notImplemented warning when applicable.
public func committeeMemberInfoSummary(
    info: CommitteeMemberInfo,
    currentEpoch: Int,
    context: any ChainContext
) throws {
    // Status header
    switch info.status {
        case .active:
            spacedPrint("Status:         \(.success("✓ Active"))")
        case .expired:
            spacedPrint("Status:         \(.danger("✗ Expired"))")
        case .unrecognized:
            spacedPrint("Status:         \(.danger("⚠ Unrecognized"))")
        case .none:
            spacedPrint("Status:         \(.muted("unknown"))")
    }

    // Cold credential — always present on CommitteeMemberInfo.
    let coldKeyType: String = {
        switch info.coldCredential.credential {
            case .scriptHash: return "scriptHash"
            case .verificationKeyHash: return "keyHash"
        }
    }()
    noora.info(.alert(
        "Cold Credential:",
        takeaways: [
            "Legacy CIP-105: \(.primary(try info.coldCredential.id((.bech32, .cip105))))",
            "CIP-129:        \(.primary(try info.coldCredential.id((.bech32, .cip129))))",
            "Cold HASH:      \(.primary(info.coldCredential.credential.payload.toHex))",
            "Key Type:       \(.primary(coldKeyType))",
        ]
    ))
    print()

    // Hot credential — optional.
    if let hot = info.hotCredential {
        let hotKeyType: String = {
            switch hot.credential {
                case .scriptHash: return "scriptHash"
                case .verificationKeyHash: return "keyHash"
            }
        }()
        noora.info(.alert(
            "Hot Credential:",
            takeaways: [
                "Legacy CIP-105: \(.primary(try hot.id((.bech32, .cip105))))",
                "CIP-129:        \(.primary(try hot.id((.bech32, .cip129))))",
                "Hot HASH:       \(.primary(hot.credential.payload.toHex))",
                "Key Type:       \(.primary(hotKeyType))",
            ]
        ))
        print()
    } else {
        spacedPrint("Hot Credential: \(.muted("not authorized"))")
    }

    // Expiration vs current epoch.
    if let expiration = info.expiration {
        let expVal = Int(expiration)
        let styled: TerminalText = expVal < currentEpoch
            ? "\(.danger("\(expVal)"))"
            : "\(.success("\(expVal)"))"
        spacedPrint("Expiration:     \(styled)")
    } else {
        spacedPrint("Expiration:     \(.muted("N/A"))")
    }
    spacedPrint("Current Epoch:  \(.primary("\(currentEpoch)"))")
}
