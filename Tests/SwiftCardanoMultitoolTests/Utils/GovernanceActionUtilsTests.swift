import Foundation
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("GovernanceActionUtils")
struct GovernanceActionUtilsTests {

    @Test("govActionIdSummary prints summary for a valid GovActionID without throwing")
    func summaryDoesNotThrow() throws {
        let txHashHex = String(repeating: "a", count: 64)
        guard let id = GovActionID(argument: "\(txHashHex)#0") else {
            Issue.record("Failed to build GovActionID from test fixture")
            return
        }
        try govActionIdSummary(govActionID: id)
    }

    @Test("govActionIdSummary handles a non-zero index")
    func summaryHandlesNonZeroIndex() throws {
        let txHashHex = String(repeating: "b", count: 64)
        guard let id = GovActionID(argument: "\(txHashHex)#42") else {
            Issue.record("Failed to build GovActionID from test fixture")
            return
        }
        try govActionIdSummary(govActionID: id)
    }
}
