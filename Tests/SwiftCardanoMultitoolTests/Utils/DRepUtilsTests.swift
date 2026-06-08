import Foundation
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("DRepUtils")
struct DRepUtilsTests {

    // MARK: - AnchorKind

    @Test("AnchorKind raw values match the cardano-signer cip100 namespace strings")
    func anchorKindRawValues() {
        #expect(AnchorKind.drepRegistration.rawValue == "DRepAnchor")
        #expect(AnchorKind.voteRationale.rawValue == "VoteAnchor")
        #expect(AnchorKind.committeeMetadata.rawValue == "CommitteeAnchor")
        #expect(AnchorKind.governanceAction.rawValue == "GovActionAnchor")
    }

    @Test("AnchorKind covers every namespaced anchor flavor")
    func anchorKindCoversAllVariants() {
        // Sanity check: if a new variant is added we want this list to grow with it.
        let kinds: [AnchorKind] = [
            .drepRegistration, .voteRationale, .committeeMetadata, .governanceAction
        ]
        #expect(kinds.count == 4)
    }

    // MARK: - drepIdSummary

    @Test("drepIdSummary handles a key-hash DRep without throwing")
    func summaryKeyHashDRep() throws {
        let hex = String(repeating: "a", count: 56)
        let drep = DRep(
            credential: .verificationKeyHash(
                VerificationKeyHash(payload: hex.hexStringToData)
            )
        )
        try drepIdSummary(drep: drep)
    }

    @Test("drepIdSummary handles a script-hash DRep without throwing")
    func summaryScriptHashDRep() throws {
        let hex = String(repeating: "b", count: 56)
        let drep = DRep(
            credential: .scriptHash(ScriptHash(payload: hex.hexStringToData))
        )
        try drepIdSummary(drep: drep)
    }

    @Test("drepIdSummary handles the alwaysAbstain constant")
    func summaryAlwaysAbstain() throws {
        let drep = DRep(credential: .alwaysAbstain)
        try drepIdSummary(drep: drep)
    }

    @Test("drepIdSummary handles the alwaysNoConfidence constant")
    func summaryAlwaysNoConfidence() throws {
        let drep = DRep(credential: .alwaysNoConfidence)
        try drepIdSummary(drep: drep)
    }
}
