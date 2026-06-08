import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("DRepUtils")
struct DRepUtilsTests {

    @Test("AnchorKind raw values match the cardano-signer cip100 namespace strings")
    func anchorKindRawValues() {
        #expect(AnchorKind.drepRegistration.rawValue == "DRepAnchor")
        #expect(AnchorKind.voteRationale.rawValue == "VoteAnchor")
        #expect(AnchorKind.committeeMetadata.rawValue == "CommitteeAnchor")
        #expect(AnchorKind.governanceAction.rawValue == "GovActionAnchor")
    }
}
