import Foundation
import Command
import ArgumentParser

enum CertificateCommands: String, Subcommandable, AlignedChoiceDescribable {
    case stakeDelegation
    case stakeRegistration
    case stakeDeregistration
    case poolRegistration
    case poolDeregistration
    case genesisKeyDelegation
    case moveInstantaneousRewards
    case voteDelegate
    case stakeVoteDelegate
    case stakeRegisterDelegate
    case voteRegisterDelegate
    case stakeVoteRegisterDelegate
    case authCommitteeHot
    case resignCommitteeCold
    case registerDRep
    case unRegisterDRep
    case updateDRep
    case back
    case exit

    var name: String {
        switch self {
            case .stakeDelegation: return "Stake Delegation"
            case .stakeRegistration: return "Stake Address Registration"
            case .stakeDeregistration: return "Stake Address Deregistration"
            case .poolRegistration: return "Pool Registration"
            case .poolDeregistration: return "Pool Deregistration"
            case .genesisKeyDelegation: return "Genesis Key Delegation"
            case .moveInstantaneousRewards: return "Move Instantaneous Rewards"
            case .voteDelegate: return "Vote Delegate"
            case .stakeVoteDelegate: return "Stake and Vote Delegate"
            case .stakeRegisterDelegate: return "Stake Register and Delegate"
            case .voteRegisterDelegate: return "Vote Register and Delegate"
            case .stakeVoteRegisterDelegate: return "Stake and Vote Register and Delegate"
            case .authCommitteeHot: return "Auth Committee Hot"
            case .resignCommitteeCold: return "Resign Committee Cold"
            case .registerDRep: return "Register DRep"
            case .unRegisterDRep: return "Unregister DRep"
            case .updateDRep: return "Update DRep"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .stakeDelegation: return "Generates `name.deleg.cert` to delegate a stake to a stakepool."
            case .stakeRegistration: return "Generates `name.stake.cert` to register a stake address on the blockchain."
            case .stakeDeregistration: return "Generates `name.stake.dereg-cert` to deregister a stake address from the blockchain."
            case .poolRegistration: return "Generates the certificate poolName.pool.cert to (re)register a stakepool on the blockchain."
            case .poolDeregistration: return "Generates the certificate poolName.pool.dereg-cert to retire a stakepool from the blockchain."
            case .genesisKeyDelegation: return "Generates the genesis key delegation certificate to delegate a genesis key to a stake pool."
            case .moveInstantaneousRewards: return "Generates the move instantaneous rewards certificate."
            case .voteDelegate: return "Generates the vote delegation certificate."
            case .stakeVoteDelegate: return "Generates the stake and vote delegation certificate."
            case .stakeRegisterDelegate: return "Generates the stake address registration and stake delegation certificate."
            case .voteRegisterDelegate: return "Generates the stake registration and vote delegation certificate."
            case .stakeVoteRegisterDelegate: return "Generates the stake address registration and vote delegation certificate."
            case .authCommitteeHot: return "Generates the constitutional committee hot key registration certificate."
            case .resignCommitteeCold: return "Generates the constitutional committee cold key resignation certificate."
            case .registerDRep: return "Generates the DRep registration certificate."
            case .unRegisterDRep: return "Generates the DRep retirement certificate."
            case .updateDRep: return "Generates the DRep update certificate."
            case .back: return "Go back to the main menu."
            case .exit: return "Leave the program."
        }
    }
    
    static var subcommands: [any AsyncParsableCommand.Type] {
        return Self.allCases.compactMap {
            switch $0 {
                case .back, .exit:
                    return .none
                default:
                    return $0.command()
            }
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .stakeRegistration:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .stakeDelegation:
                return CertificateMainCommand.StakeAddressDelegationCertificate.self
            case .stakeDeregistration:
                return CertificateMainCommand.StakeAddressDeregistrationCertificate.self
            case .poolRegistration:
                return CertificateMainCommand.StakePoolRegistrationCertificate.self
            case .poolDeregistration:
                return CertificateMainCommand.StakePoolDeregistrationCertificate.self
            case .genesisKeyDelegation:
                return CertificateMainCommand.GenesisKeyDelegationCertificate.self
            case .moveInstantaneousRewards:
                return CertificateMainCommand.MoveInstantaneousRewardsCertificate.self
            case .voteDelegate:
                return CertificateMainCommand.VoteDelegationCertificate.self
            case .stakeVoteDelegate:
                return CertificateMainCommand.StakeVoteDelegateCertificate.self
            case .stakeRegisterDelegate:
                return CertificateMainCommand.StakeRegisterDelegateCertificate.self
            case .voteRegisterDelegate:
                return CertificateMainCommand.VoteRegisterDelegateCertificate.self
            case .stakeVoteRegisterDelegate:
                return CertificateMainCommand.StakeVoteRegisterDelegateCertificate.self
            case .authCommitteeHot:
                return CertificateMainCommand.AuthCommitteeHotCertificate.self
            case .resignCommitteeCold:
                return CertificateMainCommand.ResignCommitteeColdCertificate.self
            case .registerDRep:
                return CertificateMainCommand.RegisterDRepCertificate.self
            case .unRegisterDRep:
                return CertificateMainCommand.UnRegisterDRepCertificate.self
            case .updateDRep:
                return CertificateMainCommand.UpdateDRepCertificate.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

/// Generates all Cardano certificate types.
///
/// Covers stake registration/delegation/deregistration, pool registration and
/// retirement, Conway-era governance (DRep, committee), and legacy genesis
/// certificates. See <doc:CertificatesCommand> for full documentation.
struct CertificateMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = CertificateCommands

    var name: String { "Certificate" }

    static let configuration = CommandConfiguration(
        commandName: "certificate",
        abstract: "Generate Cardano certificates for stake, pools, and governance.",
        discussion: """
        Create certificate files for on-chain registration and delegation actions:
        stake address registration/delegation/deregistration, pool registration
        and retirement, Conway-era vote delegation, DRep registration/update,
        and constitutional committee authorization/resignation.
        """,
        subcommands: CertificateCommands.subcommands,
        aliases: ["cert"]
    )
}
