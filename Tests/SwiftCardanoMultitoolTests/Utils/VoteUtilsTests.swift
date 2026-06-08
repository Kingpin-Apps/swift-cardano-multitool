import Foundation
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("VoteUtils")
struct VoteUtilsTests {

    // MARK: - VoterFilter.isNone

    @Test("VoterFilter.none.isNone is true")
    func noneIsNone() {
        let filter: VoterFilter = .none
        #expect(filter.isNone == true)
    }

    @Test("VoterFilter.unknownHex(...) is not 'none'")
    func unknownHexIsNotNone() {
        let filter: VoterFilter = .unknownHex(Data([0x01, 0x02, 0x03]))
        #expect(filter.isNone == false)
    }

    // MARK: - rewardAccountCredentialHash

    @Test("rewardAccountCredentialHash returns Data() for short accounts")
    func shortAccount() {
        let acct = Data([0xE0, 0x01, 0x02]) // 3 bytes — too short
        #expect(rewardAccountCredentialHash(acct).isEmpty)
    }

    @Test("rewardAccountCredentialHash strips the 1-byte header from a 29-byte account")
    func headerStripped() {
        var acct = Data([0xE0]) // 1-byte header
        let hash = Data(repeating: 0xAB, count: 28)
        acct.append(hash)
        let extracted = rewardAccountCredentialHash(acct)
        #expect(extracted == hash)
    }

    // MARK: - matchesActionType

    @Test("matchesActionType: nil filter matches everything")
    func nilFilterMatches() {
        let action: GovAction = .infoAction(InfoAction())
        #expect(matchesActionType(action, filter: nil) == true)
    }

    @Test("matchesActionType: .any filter matches everything")
    func anyFilterMatches() {
        let action: GovAction = .infoAction(InfoAction())
        #expect(matchesActionType(action, filter: .any) == true)
    }

    @Test("matchesActionType: matching filter returns true")
    func matchingFilter() {
        let action: GovAction = .infoAction(InfoAction())
        #expect(matchesActionType(action, filter: .infoAction) == true)
    }

    @Test("matchesActionType: non-matching filter returns false")
    func nonMatchingFilter() {
        let action: GovAction = .infoAction(InfoAction())
        #expect(matchesActionType(action, filter: .parameterChange) == false)
        #expect(matchesActionType(action, filter: .treasuryWithdrawal) == false)
        #expect(matchesActionType(action, filter: .noConfidence) == false)
    }
}
