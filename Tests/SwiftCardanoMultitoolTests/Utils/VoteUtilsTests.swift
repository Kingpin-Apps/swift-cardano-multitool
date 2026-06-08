import Foundation
import Testing
import SwiftCardanoCore
import SwiftCardanoChain
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

// MARK: - Test fixtures

private enum VoteFixtures {
    static let txHashHex = String(repeating: "a", count: 64)

    static func sampleGovActionID() -> GovActionID {
        GovActionID(
            transactionID: TransactionId(payload: txHashHex.hexStringToData),
            govActionIndex: 0
        )
    }

    static func sampleRewardAccount() -> RewardAccount {
        // 1-byte header + 28-byte credential hash.
        var data = Data([0xE0])
        data.append(Data(repeating: 0xAB, count: 28))
        return RewardAccount(data)
    }

    /// Build a minimal `GovActionVotes` proposal with no votes recorded.
    static func emptyProposal(
        proposedIn: UInt64? = nil,
        expiresAfter: UInt64? = nil,
        enactedEpoch: UInt64? = nil,
        ratifiedEpoch: UInt64? = nil,
        droppedEpoch: UInt64? = nil,
        expiredEpoch: UInt64? = nil
    ) -> GovActionVotes {
        GovActionVotes(
            govActionId: sampleGovActionID(),
            govAction: .infoAction(InfoAction()),
            committeeVotes: [],
            dRepVotes: [],
            stakePoolVotes: [],
            deposit: 1_000_000,
            depositReturnAddr: sampleRewardAccount(),
            anchor: nil,
            proposedIn: proposedIn,
            expiresAfter: expiresAfter,
            ratifiedEpoch: ratifiedEpoch,
            enactedEpoch: enactedEpoch,
            droppedEpoch: droppedEpoch,
            expiredEpoch: expiredEpoch
        )
    }
}

// MARK: - isActive

@Suite("VoteUtils.isActive")
struct VoteUtilsIsActiveTests {

    @Test("returns true when no terminal status and no expiry")
    func activeWithoutExpiry() {
        let proposal = VoteFixtures.emptyProposal()
        #expect(isActive(proposal, currentEpoch: 100) == true)
    }

    @Test("returns true when current epoch is before expiry")
    func activeBeforeExpiry() {
        let proposal = VoteFixtures.emptyProposal(expiresAfter: 200)
        #expect(isActive(proposal, currentEpoch: 100) == true)
    }

    @Test("returns false when current epoch is past expiry")
    func inactivePastExpiry() {
        let proposal = VoteFixtures.emptyProposal(expiresAfter: 50)
        #expect(isActive(proposal, currentEpoch: 100) == false)
    }

    @Test("returns false once a terminal-status epoch is set (enactedEpoch)")
    func inactiveOnceEnacted() {
        let proposal = VoteFixtures.emptyProposal(enactedEpoch: 99)
        #expect(isActive(proposal, currentEpoch: 100) == false)
    }

    @Test("returns false once droppedEpoch is set")
    func inactiveOnceDropped() {
        let proposal = VoteFixtures.emptyProposal(droppedEpoch: 99)
        #expect(isActive(proposal, currentEpoch: 100) == false)
    }
}

// MARK: - voterParticipated (.none)

@Suite("VoteUtils.voterParticipated")
struct VoteUtilsVoterParticipatedTests {

    @Test(".none filter always returns true (no filtering)")
    func noneFilterAlwaysTrue() {
        let proposal = VoteFixtures.emptyProposal()
        #expect(voterParticipated(in: proposal, voter: .none, committee: nil) == true)
    }
}

// MARK: - tallyVotes (empty case)

@Suite("VoteUtils.tallyVotes")
struct VoteUtilsTallyVotesTests {

    @Test("empty proposal + nil distributions + nil committee = zero tallies")
    func emptyTally() {
        let proposal = VoteFixtures.emptyProposal()
        let (drep, spo, committee) = tallyVotes(
            proposal: proposal,
            drepDistribution: nil,
            spoDistribution: nil,
            committee: nil
        )

        #expect(drep.yesCount == 0)
        #expect(drep.noCount == 0)
        #expect(drep.abstainCount == 0)
        #expect(drep.yesPower == 0)
        #expect(drep.noPower == 0)
        #expect(drep.abstainPower == 0)
        #expect(drep.activeTotal == 0)
        #expect(drep.alwaysAbstainPower == 0)
        #expect(drep.alwaysNCPower == 0)

        #expect(spo.yesCount == 0)
        #expect(spo.noCount == 0)
        #expect(spo.abstainCount == 0)
        #expect(spo.totalPoolStake == 0)

        #expect(committee.yesCount == 0)
        #expect(committee.noCount == 0)
        #expect(committee.abstainCount == 0)
        #expect(committee.activeMembers == 0)
    }
}

// MARK: - buildStakeAddress

@Suite("VoteUtils.buildStakeAddress")
struct VoteUtilsBuildStakeAddressTests {

    @Test("key-hash credential on mainnet returns a stake1… bech32")
    func keyHashMainnet() throws {
        let hash = Data(repeating: 0xAB, count: 28)
        let credential = StakeCredential(credential: .verificationKeyHash(VerificationKeyHash(payload: hash)))
        let bech32 = try buildStakeAddress(credential: credential, network: .mainnet)
        #expect(bech32.hasPrefix("stake1"))
    }

    @Test("script-hash credential on mainnet returns a stake1… bech32")
    func scriptHashMainnet() throws {
        let hash = Data(repeating: 0xCD, count: 28)
        let credential = StakeCredential(credential: .scriptHash(ScriptHash(payload: hash)))
        let bech32 = try buildStakeAddress(credential: credential, network: .mainnet)
        #expect(bech32.hasPrefix("stake1"))
    }

    @Test("key-hash credential on a testnet returns a stake_test1… bech32")
    func keyHashTestnet() throws {
        let hash = Data(repeating: 0xAB, count: 28)
        let credential = StakeCredential(credential: .verificationKeyHash(VerificationKeyHash(payload: hash)))
        let bech32 = try buildStakeAddress(credential: credential, network: .preprod)
        #expect(bech32.hasPrefix("stake_test1"))
    }
}

// MARK: - rewardAccountBech32

@Suite("VoteUtils.rewardAccountBech32")
struct VoteUtilsRewardAccountBech32Tests {

    @Test("returns nil for an empty account")
    func emptyAccountReturnsNil() {
        #expect(rewardAccountBech32(Data()) == nil)
    }

    @Test("returns a bech32 string for a valid 29-byte mainnet account")
    func validMainnetAccount() {
        // Header 0xE1 = key-hash reward, mainnet (low nibble 1).
        var data = Data([0xE1])
        data.append(Data(repeating: 0xAB, count: 28))
        let acct: RewardAccount = data
        let bech32 = rewardAccountBech32(acct)
        #expect(bech32?.hasPrefix("stake1") == true)
    }
}
