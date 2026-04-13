import Foundation
import Command
import ArgumentParser

enum CertificateCommands: String, Subcommandable {
    case stakeDelegation
    case stakeRegistration
    case stakeDeregistration
    case poolRegistration
    case poolRetirement
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
    
    var description: String {
        switch self {
            case .stakeDelegation:
                return "Stake Delegation - Generates `name.deleg.cert to delegate a stake to a stakepool."
            case .stakeRegistration:
                return "Stake Address Registration - Generates `name.stake.cert` to register a stake address on the blockchain."
            case .stakeDeregistration:
                return "Stake Address Deregistration - Generates  `name.stake.dereg-cert` to deregister a stake address from the blockchain."
            case .poolRegistration:
                return "Pool Registration - Generates the certificate poolName.pool.cert to (re)register a stakepool on the blockchain."
            case .poolRetirement:
                return "Pool Retirement - Generates the certificate poolName.pool.dereg-cert to retire a stakepool from the blockchain."
            case .genesisKeyDelegation:
                return "Genesis Key Delegation - Generates the genesis key delegation certificate to delegate a genesis key to a stake pool."
            case .moveInstantaneousRewards:
                return "Move Instantaneous Rewards - Generates the move instantaneous rewards certificate."
            case .voteDelegate:
                return "Vote Delegate - Generates the vote delegation certificate."
            case .stakeVoteDelegate:
                return "Stake and Vote Delegate - Generates the stake and vote delegation certificate."
            case .stakeRegisterDelegate:
                return "Stake Register and Delegate - Generates the stake address registration and stake delegation certificate."
            case .voteRegisterDelegate:
                return "Vote Register and Delegate - Generates the stake registration and vote delegation certificate."
            case .stakeVoteRegisterDelegate:
                return "Stake and Vote Register and Delegate - Generates the stake address registration and vote delegation certificate."
            case .authCommitteeHot:
                return "Auth Committee Hot - Generates the constitutional committee hot key registration certificate."
            case .resignCommitteeCold:
                return "Resign Committee Cold - Generates the constitutional committee cold key resignation certificate."
            case .registerDRep:
                return "Register DRep - Generates the DRep registration certificate."
            case .unRegisterDRep:
                return "Unregister DRep - Generates the DRep retirement certificate."
            case .updateDRep:
                return "Update DRep - Generates the DRep update certificate."
            case .back:
                return "Back - Go back to the main menu."
            case .exit:
                return "Exit - Leave the program."
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
            case .poolRetirement:
                return CertificateMainCommand.StakePoolRegistrationCertificate.self
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

struct CertificateMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = CertificateCommands
    
    var name: String { "Certificate" }
    
    static let configuration = CommandConfiguration(
        commandName: "certificate",
        abstract: "Generate various certificate.",
        discussion: """
        Certificates are used to register stake addresses, delegate stake, 
        register stake pools, and more. This command provides a convenient 
        interface to generate all the necessary certificates for these 
        operations. Select the desired certificate type from the options to
        proceed with the generation process.
        """,
        subcommands: CertificateCommands.subcommands,
        aliases: ["cert"]
    )
}
