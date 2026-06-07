import Foundation
import Noora
import SwiftCardanoChain
import SwiftCardanoCore
import SwiftCardanoNetwork

// MARK: - Voter Filter

/// Voter selected by the user as a filter target. `.none` means "show all voters".
enum VoterFilter: Sendable {
    case none
    case drep(DRep)
    case spo(PoolOperator)
    case ccCold(CommitteeColdCredential)
    case ccHot(CommitteeHotCredential)
    /// Raw 28-byte hash — probes DRep / SPO / CC-hot until one matches.
    case unknownHex(Data)
    /// Stake credential extracted from `stake1…` / `stake_test1…`. Matches the proposal's
    /// deposit-return address first; the caller can also use the credential to look up
    /// the delegated DRep and re-run with `.drep(...)` as a second pass.
    case stakeAddress(StakeCredential)

    public var isNone: Bool {
        if case .none = self { return true } else { return false }
    }
}

// MARK: - Tallies

/// DRep-side counts and power, plus the special `alwaysAbstain` / `alwaysNoConfidence`
/// buckets needed for Conway acceptance formulas.
struct DRepTally: Sendable {
    var yesCount: Int = 0
    var noCount: Int = 0
    var abstainCount: Int = 0
    var yesPower: UInt64 = 0
    var noPower: UInt64 = 0
    var abstainPower: UInt64 = 0
    /// Total power excluding `alwaysAbstain` and `alwaysNoConfidence` delegations.
    var activeTotal: UInt64 = 0
    var alwaysNCPower: UInt64 = 0
    var alwaysAbstainPower: UInt64 = 0
}

/// SPO-side counts and power. `totalPoolStake` is the sum of all pool entries —
/// non-voting pools count as NO under Conway, so the ratio uses
/// `yesPower / (totalPoolStake − abstainPower)`.
struct SPOTally: Sendable {
    var yesCount: Int = 0
    var noCount: Int = 0
    var abstainCount: Int = 0
    var yesPower: UInt64 = 0
    var noPower: UInt64 = 0
    var abstainPower: UInt64 = 0
    var totalPoolStake: UInt64 = 0
}

/// Committee tally — one-member-one-vote; `activeMembers` is the count of
/// `MemberAuthorized + status == .active` entries.
struct CommitteeTally: Sendable {
    var yesCount: Int = 0
    var noCount: Int = 0
    var abstainCount: Int = 0
    var activeMembers: Int = 0
}

// MARK: - Acceptance

/// Per-voter-class threshold and pass/fail verdict for a single action.
struct AcceptanceResult: Sendable {
    var drepPassed: Bool
    var drepThreshold: Double
    var drepRatio: Double
    var drepRequired: Bool
    var spoPassed: Bool
    var spoThreshold: Double
    var spoRatio: Double
    var spoRequired: Bool
    var committeePassed: Bool
    var committeeThreshold: Double
    var committeeRatio: Double
    var committeeRequired: Bool
    /// Reads as N/A in the "Full approval" row (e.g. Info actions are advisory).
    var advisoryOnly: Bool
    /// True when committee threshold == 0 (chain in committee-no-confidence state proxy).
    var committeeNoConfidenceState: Bool
}

// MARK: - Tally Computation

/// Build the three tallies. DRep and SPO power are sourced by looking up each voter's
/// stake in the corresponding distribution; voters whose stake is unknown
/// (distribution unavailable, or stake = 0) still contribute counts.
func tallyVotes(
    proposal: GovActionVotes,
    drepDistribution: [SwiftCardanoNetwork.DRepStakeEntry]?,
    spoDistribution: [SwiftCardanoNetwork.SPOStakeEntry]?,
    committee: CommitteeStateInfo?
) -> (drep: DRepTally, spo: SPOTally, committee: CommitteeTally) {
    var drep = DRepTally()
    var spo = SPOTally()
    var cc = CommitteeTally()

    // DRep — separate stake into active vs. alwaysAbstain vs. alwaysNoConfidence.
    var drepStakeMap: [String: UInt64] = [:]
    for entry in drepDistribution ?? [] {
        switch entry.drep.credential {
        case .alwaysAbstain:
            drep.alwaysAbstainPower &+= entry.stake
        case .alwaysNoConfidence:
            drep.alwaysNCPower &+= entry.stake
        case .verificationKeyHash, .scriptHash:
            drep.activeTotal &+= entry.stake
            drepStakeMap[drepStakeKey(entry.drep)] = entry.stake
        }
    }
    for v in proposal.dRepVotes {
        let key = drepStakeKey(DRep(credential: drepTypeFor(v.credential)))
        let power = drepStakeMap[key] ?? 0
        applyVote(v.vote, count: 1, yesCount: &drep.yesCount, noCount: &drep.noCount,
                  abstainCount: &drep.abstainCount, yesPower: &drep.yesPower,
                  noPower: &drep.noPower, abstainPower: &drep.abstainPower, power: power)
    }

    // SPO — flat distribution; total = sum of all entries.
    var spoStakeMap: [String: UInt64] = [:]
    for entry in spoDistribution ?? [] {
        spoStakeMap[poolStakeKey(entry.poolOperator)] = entry.stake
        spo.totalPoolStake &+= entry.stake
    }
    for v in proposal.stakePoolVotes {
        let key = poolStakeKey(v.poolOperator)
        let power = spoStakeMap[key] ?? 0
        applyVote(v.vote, count: 1, yesCount: &spo.yesCount, noCount: &spo.noCount,
                  abstainCount: &spo.abstainCount, yesPower: &spo.yesPower,
                  noPower: &spo.noPower, abstainPower: &spo.abstainPower, power: power)
    }

    // Committee — counts only (one-member-one-vote).
    cc.activeMembers = (committee?.members ?? []).filter { $0.status == .active }.count
    for v in proposal.committeeVotes {
        switch v.vote {
        case .yes:     cc.yesCount += 1
        case .no:      cc.noCount += 1
        case .abstain: cc.abstainCount += 1
        }
    }

    return (drep, spo, cc)
}

private func applyVote(
    _ vote: Vote,
    count: Int,
    yesCount: inout Int, noCount: inout Int, abstainCount: inout Int,
    yesPower: inout UInt64, noPower: inout UInt64, abstainPower: inout UInt64,
    power: UInt64
) {
    switch vote {
    case .yes:
        yesCount += count
        yesPower &+= power
    case .no:
        noCount += count
        noPower &+= power
    case .abstain:
        abstainCount += count
        abstainPower &+= power
    }
}

private func drepStakeKey(_ drep: DRep) -> String {
    switch drep.credential {
    case .verificationKeyHash(let h): return "kh-\(h.payload.toHex)"
    case .scriptHash(let h):          return "sh-\(h.payload.toHex)"
    case .alwaysAbstain:              return "aa"
    case .alwaysNoConfidence:         return "anc"
    }
}

private func drepTypeFor(_ cred: DRepCredential) -> DRepType {
    switch cred.credential {
    case .verificationKeyHash(let h): return .verificationKeyHash(h)
    case .scriptHash(let h):          return .scriptHash(h)
    }
}

private func poolStakeKey(_ pool: PoolOperator) -> String {
    return "pool-\(pool.poolKeyHash.payload.toHex)"
}

private func committeeHotKey(_ hot: CommitteeHotCredential) -> String {
    switch hot.credential {
    case .verificationKeyHash(let h): return "kh-\(h.payload.toHex)"
    case .scriptHash(let h):          return "sh-\(h.payload.toHex)"
    }
}

private func committeeColdKey(_ cold: CommitteeColdCredential) -> String {
    switch cold.credential {
    case .verificationKeyHash(let h): return "kh-\(h.payload.toHex)"
    case .scriptHash(let h):          return "sh-\(h.payload.toHex)"
    }
}

private func credentialPayload(_ cred: CredentialType) -> Data {
    switch cred {
    case .verificationKeyHash(let h): return h.payload
    case .scriptHash(let h):          return h.payload
    }
}

// MARK: - Parameter-change group introspection

/// Which DRep voting-threshold group(s) a `ProtocolParamUpdate` touches. Bash takes
/// the MAX threshold across involved groups; if SECURITY is touched, SPOs vote on
/// `pvt.ppSecurityGroup`.
struct ParameterChangeGroups {
    var network: Bool = false
    var economic: Bool = false
    var technical: Bool = false
    var governance: Bool = false
    var security: Bool = false
}

private func groupsTouched(by update: ProtocolParamUpdate) -> ParameterChangeGroups {
    var g = ParameterChangeGroups()

    // NETWORK
    if update.maxBlockBodySize != nil { g.network = true; g.security = true }
    if update.maxTransactionSize != nil { g.network = true; g.security = true }
    if update.maxBlockHeaderSize != nil { g.network = true; g.security = true }
    if update.maxValueSize != nil { g.network = true; g.security = true }
    if update.maxBlockExUnits != nil { g.network = true; g.security = true }
    if update.maxTxExUnits != nil { g.network = true }
    if update.maxCollateralInputs != nil { g.network = true }

    // ECONOMIC
    if update.minFeeA != nil { g.economic = true; g.security = true }
    if update.minFeeB != nil { g.economic = true; g.security = true }
    if update.keyDeposit != nil { g.economic = true }
    if update.poolDeposit != nil { g.economic = true }
    if update.expansionRate != nil { g.economic = true }
    if update.treasuryGrowthRate != nil { g.economic = true }
    if update.minPoolCost != nil { g.economic = true }
    if update.adaPerUtxoByte != nil { g.economic = true; g.security = true }
    if update.executionCosts != nil { g.economic = true }

    // TECHNICAL
    if update.poolPledgeInfluence != nil { g.technical = true }
    if update.maximumEpoch != nil { g.technical = true }
    if update.nOpt != nil { g.technical = true }
    if update.costModels != nil { g.technical = true }
    if update.collateralPercentage != nil { g.technical = true }

    // GOVERNANCE
    if update.governanceActionValidityPeriod != nil { g.governance = true }
    if update.governanceActionDeposit != nil { g.governance = true; g.security = true }
    if update.drepDeposit != nil { g.governance = true }
    if update.drepInactivityPeriod != nil { g.governance = true }
    if update.minCommitteeSize != nil { g.governance = true }
    if update.committeeTermLimit != nil { g.governance = true }
    if update.poolVotingThresholds != nil { g.governance = true }
    if update.drepVotingThresholds != nil { g.governance = true }

    // SECURITY (additional, not already captured above)
    if update.minFeeRefScriptCoinsPerByte != nil { g.security = true }

    return g
}

// MARK: - Acceptance Computation

/// Apply Conway acceptance rules. Mirrors `24c_queryVote.sh`. Two known approximations
/// vs. the reference are documented inline because the SDK doesn't surface the data:
///
///  * SPO formulas can't separate pools delegating to `drep-alwaysAbstain` /
///    `drep-alwaysNoConfidence` because `SPOStakeEntry` doesn't carry the delegated
///    DRep. Non-voting pools default to NO, which slightly overcounts the denominator.
///  * Committee "no-confidence state" detection has no SDK equivalent — we proxy on
///    `CommitteeStateInfo.threshold == 0`.
func computeAcceptance(
    proposal: GovActionVotes,
    drepTally: DRepTally,
    spoTally: SPOTally,
    committeeTally: CommitteeTally,
    pp: ProtocolParameters,
    committee: CommitteeStateInfo?
) -> AcceptanceResult {
    let dvt = pp.dRepVotingThresholds
    let pvt = pp.poolVotingThresholds
    let protocolMajor = pp.protocolVersion.major

    let committeeThreshold = committee?.threshold ?? 0
    let committeeNoConfidenceState = (committee != nil) && committeeThreshold <= 0

    var drepThreshold: Double = 0
    var spoThreshold: Double = 0
    var drepRequired = true
    var spoRequired = true
    var committeeRequired = true
    var advisoryOnly = false

    switch proposal.govAction {
    case .noConfidence:
        drepThreshold = dvt.motionNoConfidence
        spoThreshold = pvt.motionNoConfidence
        committeeRequired = false
    case .updateCommittee:
        if committeeNoConfidenceState {
            drepThreshold = dvt.committeeNoConfidence
            spoThreshold = pvt.committeeNoConfidence
        } else {
            drepThreshold = dvt.committeeNormal
            spoThreshold = pvt.committeeNormal
        }
        committeeRequired = false
    case .newConstitution:
        drepThreshold = dvt.updateToConstitution
        spoRequired = false
    case .hardForkInitiationAction:
        // Bash gates the DRep check on protocolVersion.major ≥ 10 (Chang-2).
        if protocolMajor >= 10 {
            drepThreshold = dvt.hardForkInitiation
        } else {
            drepRequired = false
        }
        spoThreshold = pvt.hardForkInitiation
    case .parameterChangeAction(let action):
        let groups = groupsTouched(by: action.protocolParamUpdate)
        var dt: Double = 0
        if groups.network { dt = max(dt, dvt.ppNetworkGroup) }
        if groups.economic { dt = max(dt, dvt.ppEconomicGroup) }
        if groups.technical { dt = max(dt, dvt.ppTechnicalGroup) }
        if groups.governance { dt = max(dt, dvt.ppGovGroup) }
        drepThreshold = dt
        if groups.security {
            spoThreshold = pvt.ppSecurityGroup
        } else {
            spoRequired = false
        }
    case .treasuryWithdrawalsAction:
        drepThreshold = dvt.treasuryWithdrawal
        spoRequired = false
    case .infoAction:
        // Info actions are advisory under Conway — neither DRep nor SPO can ratify.
        drepRequired = false
        spoRequired = false
        advisoryOnly = true
    }

    if committeeNoConfidenceState {
        committeeRequired = false
    }

    // DRep ratio
    let drepRatio: Double
    let drepDenom = Int64(drepTally.activeTotal) &+ Int64(drepTally.alwaysNCPower) &- Int64(drepTally.abstainPower)
    let drepNumerator: UInt64 = {
        if case .noConfidence = proposal.govAction {
            return drepTally.yesPower &+ drepTally.alwaysNCPower
        }
        return drepTally.yesPower
    }()
    if drepDenom > 0 {
        drepRatio = Double(drepNumerator) / Double(drepDenom)
    } else {
        drepRatio = 0
    }

    // SPO ratio — non-voting pools count as NO; alwaysAbstain-delegating non-voters
    // can't be removed (see note above), so this is a slight overcount.
    let spoDenomI = Int64(spoTally.totalPoolStake) &- Int64(spoTally.abstainPower)
    let spoRatio: Double = spoDenomI > 0
        ? Double(spoTally.yesPower) / Double(spoDenomI)
        : 0

    // Committee ratio (one-member-one-vote)
    let ccDenom = committeeTally.activeMembers - committeeTally.abstainCount
    let committeeRatio: Double = ccDenom > 0
        ? Double(committeeTally.yesCount) / Double(ccDenom)
        : 0

    let drepPassed = !drepRequired || drepRatio >= drepThreshold
    let spoPassed = !spoRequired || spoRatio >= spoThreshold
    let committeePassed = !committeeRequired || committeeRatio >= committeeThreshold

    return AcceptanceResult(
        drepPassed: drepPassed,
        drepThreshold: drepThreshold,
        drepRatio: drepRatio,
        drepRequired: drepRequired,
        spoPassed: spoPassed,
        spoThreshold: spoThreshold,
        spoRatio: spoRatio,
        spoRequired: spoRequired,
        committeePassed: committeePassed,
        committeeThreshold: committeeThreshold,
        committeeRatio: committeeRatio,
        committeeRequired: committeeRequired,
        advisoryOnly: advisoryOnly,
        committeeNoConfidenceState: committeeNoConfidenceState
    )
}

// MARK: - Status Filter

/// True when a proposal is still alive: no terminal epoch and the current
/// epoch hasn't crossed its `expiresAfter`.
func isActive(_ proposal: GovActionVotes, currentEpoch: UInt64) -> Bool {
    if proposal.status != nil { return false }
    if let expires = proposal.expiresAfter, currentEpoch > expires { return false }
    return true
}

// MARK: - Action-Type Filter

/// Match the proposal's action variant against a user filter. `.any` and `nil` both match all.
func matchesActionType(_ action: GovAction, filter: VoteActionTypeFilter?) -> Bool {
    guard let filter, filter != .any else { return true }
    switch (action, filter) {
    case (.parameterChangeAction, .parameterChange):    return true
    case (.hardForkInitiationAction, .hardFork):        return true
    case (.treasuryWithdrawalsAction, .treasuryWithdrawal): return true
    case (.noConfidence, .noConfidence):                return true
    case (.updateCommittee, .updateCommittee):          return true
    case (.newConstitution, .newConstitution):          return true
    case (.infoAction, .infoAction):                    return true
    default: return false
    }
}

// MARK: - Voter Filter Match

/// True when the proposal has any vote from the targeted voter. For `.stakeAddress`
/// matches the deposit-return address; the run() caller should re-run with the
/// delegated DRep as a fallback when this returns no matches.
func voterParticipated(
    in proposal: GovActionVotes,
    voter: VoterFilter,
    committee: CommitteeStateInfo? = nil
) -> Bool {
    switch voter {
    case .none:
        return true
    case .drep(let drep):
        let target = drepStakeKey(drep)
        return proposal.dRepVotes.contains { v in
            drepStakeKey(DRep(credential: drepTypeFor(v.credential))) == target
        }
    case .spo(let pool):
        let target = poolStakeKey(pool)
        return proposal.stakePoolVotes.contains { poolStakeKey($0.poolOperator) == target }
    case .ccCold(let cold):
        guard let hot = lookupHotForCold(cold, in: committee) else { return false }
        return proposal.committeeVotes.contains { committeeHotKey($0.credential) == committeeHotKey(hot) }
    case .ccHot(let hot):
        return proposal.committeeVotes.contains { committeeHotKey($0.credential) == committeeHotKey(hot) }
    case .unknownHex(let hash):
        if proposal.dRepVotes.contains(where: { credentialPayload($0.credential.credential) == hash }) {
            return true
        }
        if proposal.stakePoolVotes.contains(where: { $0.poolOperator.poolKeyHash.payload == hash }) {
            return true
        }
        if proposal.committeeVotes.contains(where: { credentialPayload($0.credential.credential) == hash }) {
            return true
        }
        return false
    case .stakeAddress(let stake):
        return rewardAccountCredentialHash(proposal.depositReturnAddr) == credentialPayload(stake.credential)
    }
}

/// Resolve a cold committee credential to its current hot credential using the
/// already-fetched committee state.
func lookupHotForCold(
    _ cold: CommitteeColdCredential,
    in committee: CommitteeStateInfo?
) -> CommitteeHotCredential? {
    guard let committee else { return nil }
    let key = committeeColdKey(cold)
    return committee.members.first { committeeColdKey($0.coldCredential) == key }?.hotCredential
}

// MARK: - Reward-account helpers

/// Pull the 28-byte credential hash from a reward account. The high nibble of the
/// header byte encodes key (0xE) vs. script (0xF); the low nibble is the network.
func rewardAccountCredentialHash(_ acct: RewardAccount) -> Data {
    guard acct.count >= 29 else { return Data() }
    return acct.suffix(28)
}

/// Render a `RewardAccount` as bech32 (`stake1…` / `stake_test1…`).
func rewardAccountBech32(_ acct: RewardAccount) -> String? {
    do {
        let addr = try Address(from: .bytes(acct))
        return try addr.toBech32()
    } catch {
        return nil
    }
}

/// Build a bech32 stake address (`stake1…` / `stake_test1…`) from a stake credential
/// for the given network — used to look up the delegated DRep via stakeAddressInfo.
func buildStakeAddress(credential: StakeCredential, network: Network) throws -> String {
    let staking: StakingPart
    switch credential.credential {
    case .verificationKeyHash(let h): staking = .verificationKeyHash(h)
    case .scriptHash(let h):          staking = .scriptHash(h)
    }
    let addr = try Address(paymentPart: nil, stakingPart: staking, network: network.networkId)
    return try addr.toBech32()
}

// MARK: - Display: voter-answer banner

/// Render the bash-style "Voting-Answer of the selected XX-Voter is: YES/NO/ABSTAIN"
/// banner. Returns `nil` when the voter filter is `.none` or the proposal has no
/// matching vote.
func voterAnswerBanner(
    voter: VoterFilter,
    in votes: GovActionVotes,
    committee: CommitteeStateInfo?
) -> TerminalText? {
    let answer: Vote?
    let voterLabel: String

    switch voter {
    case .none:
        return nil
    case .drep(let drep):
        let target = drepStakeKey(drep)
        answer = votes.dRepVotes.first { v in
            drepStakeKey(DRep(credential: drepTypeFor(v.credential))) == target
        }?.vote
        voterLabel = "DRep"
    case .spo(let pool):
        let target = poolStakeKey(pool)
        answer = votes.stakePoolVotes.first { poolStakeKey($0.poolOperator) == target }?.vote
        voterLabel = "StakePool"
    case .ccHot(let hot):
        let key = committeeHotKey(hot)
        answer = votes.committeeVotes.first { committeeHotKey($0.credential) == key }?.vote
        voterLabel = "Committee-Hot"
    case .ccCold(let cold):
        guard let hot = lookupHotForCold(cold, in: committee) else {
            return "\(.muted("Cold→hot resolution unavailable for this voter."))"
        }
        let key = committeeHotKey(hot)
        answer = votes.committeeVotes.first { committeeHotKey($0.credential) == key }?.vote
        voterLabel = "Committee-Cold"
    case .unknownHex(let hash):
        if let v = votes.dRepVotes.first(where: { credentialPayload($0.credential.credential) == hash }) {
            answer = v.vote; voterLabel = "DRep"
        } else if let v = votes.stakePoolVotes.first(where: { $0.poolOperator.poolKeyHash.payload == hash }) {
            answer = v.vote; voterLabel = "StakePool"
        } else if let v = votes.committeeVotes.first(where: { credentialPayload($0.credential.credential) == hash }) {
            answer = v.vote; voterLabel = "Committee-Hot"
        } else {
            return nil
        }
    case .stakeAddress:
        // Stake addresses are matched against the deposit-return addr — no vote of
        // their own. The deposit-return-addr line in the per-action header carries
        // the equivalent info.
        return nil
    }

    guard let answer else { return nil }
    let badge: TerminalText
    switch answer {
    case .yes:     badge = "\(.success(" YES "))"
    case .no:      badge = "\(.danger(" NO "))"
    case .abstain: badge = "\(.muted(" ABSTAIN "))"
    }
    return "Voting-Answer of the selected \(.primary(voterLabel))-Voter is: \(badge)"
}

// MARK: - Display: per-class table

/// Print the bash-style vote tally table for a proposal, the voter-answer banner
/// (when relevant), the "Full approval" verdict, and a "No Confidence" notice.
func printVoteTally(
    votes: GovActionVotes,
    pp: ProtocolParameters,
    drepDistr: [SwiftCardanoNetwork.DRepStakeEntry]?,
    spoDistr: [SwiftCardanoNetwork.SPOStakeEntry]?,
    committee: CommitteeStateInfo?,
    voterHighlight: VoterFilter
) throws {
    let (drep, spo, cc) = tallyVotes(
        proposal: votes,
        drepDistribution: drepDistr,
        spoDistribution: spoDistr,
        committee: committee
    )
    let acceptance = computeAcceptance(
        proposal: votes,
        drepTally: drep,
        spoTally: spo,
        committeeTally: cc,
        pp: pp,
        committee: committee
    )

    if let banner = voterAnswerBanner(voter: voterHighlight, in: votes, committee: committee) {
        spacedPrint(banner)
    }

    printTallyTable(drep: drep, spo: spo, committee: cc, acceptance: acceptance)

    // Backend-gap warnings — surface when distributions weren't returned.
    var gaps: [TerminalText] = []
    if drepDistr == nil { gaps.append("DRep stake distribution unavailable — DRep power columns show 0.") }
    if spoDistr == nil { gaps.append("SPO stake distribution unavailable — SPO power columns show 0.") }
    if committee == nil { gaps.append("Committee state unavailable — committee row may be inaccurate.") }
    if !gaps.isEmpty {
        noora.info(.alert("Backend coverage gaps:", takeaways: gaps))
    }

    if acceptance.committeeNoConfidenceState {
        spacedPrint("\(.danger("We are currently in the 'No Confidence' state!"))")
    }
}

// MARK: - Table renderer

/// Render the per-class tally as a noora.table, then print the "Full approval" verdict
/// underneath. Each voter class gets two rows in the table: counts in the first row
/// (with threshold / live-pct / accept icon), and stake-weighted power values in the
/// second row.
private func printTallyTable(
    drep: DRepTally,
    spo: SPOTally,
    committee: CommitteeTally,
    acceptance: AcceptanceResult
) {
    let columns = [
        TableColumn(title: "Current Votes", width: .auto, alignment: .left),
        TableColumn(title: "Yes",           width: .auto, alignment: .right),
        TableColumn(title: "No",            width: .auto, alignment: .right),
        TableColumn(title: "Abstain",       width: .auto, alignment: .right),
        TableColumn(title: "AlwNoConfi",    width: .auto, alignment: .right),
        TableColumn(title: "Threshold",     width: .auto, alignment: .right),
        TableColumn(title: "Live-Pct",      width: .auto, alignment: .right),
        TableColumn(title: "Accept",        width: .auto, alignment: .center),
    ]

    var rows: [TableRow] = []
    rows.append(contentsOf: classRows(
        label: "DReps",
        counts: (drep.yesCount, drep.noCount, drep.abstainCount),
        powers: (drep.yesPower, drep.noPower, drep.abstainPower),
        alwPower: drep.alwaysNCPower,
        ratio: acceptance.drepRatio,
        threshold: acceptance.drepThreshold,
        passed: acceptance.drepPassed,
        required: acceptance.drepRequired
    ))
    rows.append(contentsOf: classRows(
        label: "StakePools",
        counts: (spo.yesCount, spo.noCount, spo.abstainCount),
        powers: (spo.yesPower, spo.noPower, spo.abstainPower),
        alwPower: nil,
        ratio: acceptance.spoRatio,
        threshold: acceptance.spoThreshold,
        passed: acceptance.spoPassed,
        required: acceptance.spoRequired
    ))
    rows.append(committeeRow(
        counts: (committee.yesCount, committee.noCount, committee.abstainCount),
        ratio: acceptance.committeeRatio,
        threshold: acceptance.committeeThreshold,
        passed: acceptance.committeePassed,
        required: acceptance.committeeRequired
    ))

    print()
    noora.table(TableData(columns: columns, rows: rows))

    // Full-approval verdict line — kept outside the table because it spans the row.
    let acceptCell: TerminalText
    if acceptance.advisoryOnly {
        acceptCell = "\(.muted("N/A"))"
    } else {
        let pass = acceptance.drepPassed && acceptance.spoPassed && acceptance.committeePassed
        acceptCell = pass ? "\(.success("✅"))" : "\(.danger("❌"))"
    }
    spacedPrint("\(.primary("Full approval of the proposal:")) \(acceptCell)")
}

/// Two table rows for a stake-weighted voter class (DReps / StakePools):
/// the count row carries threshold / live-pct / accept; the power row carries
/// the lovelace-denominated values underneath each count cell.
private func classRows(
    label: String,
    counts: (Int, Int, Int),
    powers: (UInt64, UInt64, UInt64),
    alwPower: UInt64?,
    ratio: Double,
    threshold: Double,
    passed: Bool,
    required: Bool
) -> [TableRow] {
    if required {
        let icon: TerminalText = passed ? "\(.success("✅"))" : "\(.danger("❌"))"
        let countRow: TableRow = [
            "\(.primary(label))",
            "\(.primary("\(counts.0)"))",
            "\(.primary("\(counts.1)"))",
            "\(.primary("\(counts.2)"))",
            alwPower.map { "\(.primary(formatShortAda($0)))" } ?? "\(.muted("—"))",
            "\(.muted(formatPct(threshold)))",
            "\(.primary(formatPct(ratio)))",
            icon,
        ]
        let powerRow: TableRow = [
            "",
            "\(.muted(formatShortAda(powers.0)))",
            "\(.muted(formatShortAda(powers.1)))",
            "\(.muted(formatShortAda(powers.2)))",
            alwPower.map { "\(.muted(formatShortAda($0)))" } ?? "",
            "", "", "",
        ]
        return [countRow, powerRow]
    } else {
        let row: TableRow = [
            "\(.muted(label))",
            "\(.muted("\(counts.0)"))",
            "\(.muted("\(counts.1)"))",
            "\(.muted("\(counts.2)"))",
            "\(.muted("—"))",
            "\(.muted("n/a"))",
            "\(.muted("n/a"))",
            "\(.muted("—"))",
        ]
        return [row]
    }
}

/// Single table row for the committee (one-member-one-vote — no power row).
private func committeeRow(
    counts: (Int, Int, Int),
    ratio: Double,
    threshold: Double,
    passed: Bool,
    required: Bool
) -> TableRow {
    if required {
        let icon: TerminalText = passed ? "\(.success("✅"))" : "\(.danger("❌"))"
        return [
            "\(.primary("Committee"))",
            "\(.primary("\(counts.0)"))",
            "\(.primary("\(counts.1)"))",
            "\(.primary("\(counts.2)"))",
            "\(.muted("—"))",
            "\(.muted(formatPct(threshold)))",
            "\(.primary(formatPct(ratio)))",
            icon,
        ]
    } else {
        return [
            "\(.muted("Committee"))",
            "\(.muted("\(counts.0)"))",
            "\(.muted("\(counts.1)"))",
            "\(.muted("\(counts.2)"))",
            "\(.muted("—"))",
            "\(.muted("n/a"))",
            "\(.muted("n/a"))",
            "\(.muted("—"))",
        ]
    }
}

// MARK: - Formatting

private func formatPct(_ ratio: Double) -> String {
    return String(format: "%.2f %%", ratio * 100)
}

private func formatShortAda(_ lovelace: UInt64) -> String {
    let ada = Double(lovelace) / 1_000_000.0
    let abs = Swift.abs(ada)
    if abs >= 1_000_000_000 {
        return String(format: "%.2fB ₳", ada / 1_000_000_000)
    } else if abs >= 1_000_000 {
        return String(format: "%.2fM ₳", ada / 1_000_000)
    } else if abs >= 1_000 {
        return String(format: "%.2fK ₳", ada / 1_000)
    } else if abs > 0 {
        return String(format: "%.2f ₳", ada)
    } else {
        return "0 ₳"
    }
}
