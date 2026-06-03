import Foundation
import ArgumentParser
import Noora
import SwiftCardanoChain
import SwiftCardanoCore

/// Human-readable label for each variant of the on-chain `GovAction` enum.
private func govActionTypeLabel(_ action: GovAction) -> String {
    switch action {
        case .parameterChangeAction:    return "Parameter Change"
        case .hardForkInitiationAction: return "Hard-Fork Initiation"
        case .treasuryWithdrawalsAction: return "Treasury Withdrawal"
        case .noConfidence:             return "No Confidence"
        case .updateCommittee:          return "Update Committee"
        case .newConstitution:          return "New Constitution"
        case .infoAction:               return "Info"
    }
}

/// Print the two forms of a governance-action identifier: bech32 (CIP-129) and hex (txhash#index).
public func govActionIdSummary(govActionID: GovActionID) throws {
    let bech32 = try govActionID.id(.bech32)
    let hex = try govActionID.toBytes().toHex
    let txHashHex = govActionID.transactionID.payload.toHex
    let index = govActionID.govActionIndex

    noora.info(.alert(
        "Governance Action ID:",
        takeaways: [
            "Bech32 (CIP-129): \(.primary(bech32))",
            "Raw bytes (hex):  \(.primary(hex))",
            "Tx#Index:         \(.primary("\(txHashHex)#\(index)"))",
        ]
    ))
}

/// Print on-chain state for a governance action: status (enacted/ratified/dropped/expired/in
/// progress), action type, key epochs, anchor URL/hash if present.
public func govActionInfoSummary(
    info: GovActionInfo,
    currentEpoch: Int,
    context: any ChainContext
) throws {
    // Status header
    switch info.status {
        case .enacted:
            spacedPrint("Status:          \(.success("✓ Enacted"))")
        case .ratified:
            spacedPrint("Status:          \(.success("✓ Ratified"))")
        case .dropped:
            spacedPrint("Status:          \(.danger("✗ Dropped"))")
        case .expired:
            spacedPrint("Status:          \(.danger("✗ Expired"))")
        case .none:
            // No terminal epoch yet → still alive on the chain awaiting votes.
            if let expires = info.expiresAfter, Int(expires) < currentEpoch {
                spacedPrint("Status:          \(.danger("✗ Expired (no terminal epoch reported)"))")
            } else {
                spacedPrint("Status:          \(.primary("⌛ In progress (awaiting votes)"))")
            }
    }

    spacedPrint("Action Type:     \(.primary(govActionTypeLabel(info.govAction)))")

    if let proposed = info.proposedIn {
        spacedPrint("Proposed In:     \(.primary("\(proposed)"))")
    } else {
        spacedPrint("Proposed In:     \(.muted("N/A"))")
    }

    if let expires = info.expiresAfter {
        let styled: TerminalText = Int(expires) < currentEpoch
            ? "\(.danger("\(expires)"))"
            : "\(.success("\(expires)"))"
        spacedPrint("Expires After:   \(styled)")
    } else {
        spacedPrint("Expires After:   \(.muted("N/A"))")
    }
    spacedPrint("Current Epoch:   \(.primary("\(currentEpoch)"))")

    // Terminal epochs — surface whichever applies (or muted N/A blocks for unset).
    if let enacted = info.enactedEpoch {
        spacedPrint("Enacted Epoch:   \(.success("\(enacted)"))")
    }
    if let ratified = info.ratifiedEpoch {
        spacedPrint("Ratified Epoch:  \(.success("\(ratified)"))")
    }
    if let dropped = info.droppedEpoch {
        spacedPrint("Dropped Epoch:   \(.danger("\(dropped)"))")
    }
    if let expired = info.expiredEpoch {
        spacedPrint("Expired Epoch:   \(.danger("\(expired)"))")
    }

    // Backend-gap warning if a backend doesn't report key epochs (informational only).
    let backendName = String(describing: type(of: context))
    var missing: [String] = []
    if info.proposedIn == nil  { missing.append("proposedIn") }
    if info.expiresAfter == nil { missing.append("expiresAfter") }
    if !missing.isEmpty {
        print()
        noora.warning(.alert(
            "Backend \(.primary(backendName)) does not report: \(.danger(missing.joined(separator: ", ")))",
            takeaway: "Switch to Koios or cardano-cli mode for full coverage."
        ))
    }
}
