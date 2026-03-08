import Foundation
import ArgumentParser

enum CertificateCommands: String, CaseIterable, CustomStringConvertible {
    case stakeRegistration
    case stakeDeregistration
    case stakeDelegation
    case poolRegistration
    case poolRetirement
    case genesisKeyDelegation
    case moveInstantaneousRewards
    case unregister
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
            case .stakeRegistration:
                return "Stake Address Registration - Generates `name.stake.cert` to register a stake address on the blockchain."
            case .stakeDeregistration:
                return "Stake Address Deregistration - Generates  `name.stake.dereg-cert` to deregister a stake address from the blockchain."
            case .stakeDelegation:
                return "Stake Delegation - Generates `name.deleg.cert to delegate a stake to a stakepool."
            case .poolRegistration:
                return "Generates the certificate poolName.pool.cert to (re)register a stakepool on the blockchain."
            case .poolRetirement:
                return "Generates the certificate poolName.pool.dereg-cert to retire a stakepool from the blockchain."
            case .genesisKeyDelegation:
                return "Generates the genesis key delegation certificate."
            case .moveInstantaneousRewards:
                return "Generates the move instantaneous rewards certificate."
            case .unregister:
                return "Generates the stake address retirement certificate."
            case .voteDelegate:
                return "Generates the vote delegation certificate."
            case .stakeVoteDelegate:
                return "Generates the stake and vote delegation certificate."
            case .stakeRegisterDelegate:
                return "Generates the stake address registration and stake delegation certificate."
            case .voteRegisterDelegate:
                return "Generates the stake registration and vote delegation certificate."
            case .stakeVoteRegisterDelegate:
                return "Generates the stake address registration and vote delegation certificate."
            case .authCommitteeHot:
                return "Generates the constitutional committee hot key registration certificate."
            case .resignCommitteeCold:
                return "Generates the constitutional committee cold key resignation certificate."
            case .registerDRep:
                return "Generates the DRep registration certificate."
            case .unRegisterDRep:
                return "Generates the DRep retirement certificate."
            case .updateDRep:
                return "Generates the DRep update certificate."
            case .back:
                return "Back - Go back to the main menu."
            case .exit:
                return "Exit - Leave the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .stakeRegistration:
                return CertificateMainCommand.StakeRegistration.self
            case .stakeDelegation:
                return CertificateMainCommand.StakeDelegation.self
            case .stakeDeregistration:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .poolRegistration:
                return CertificateMainCommand.StakepoolRegistrationCertificate.self
            case .poolRetirement:
                return CertificateMainCommand.StakepoolDeregistrationCertificate.self
            case .genesisKeyDelegation:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .moveInstantaneousRewards:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .unregister:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .voteDelegate:
                return CertificateMainCommand.VoteDelegation.self
            case .stakeVoteDelegate:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .stakeRegisterDelegate:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .voteRegisterDelegate:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .stakeVoteRegisterDelegate:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .authCommitteeHot:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .resignCommitteeCold:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .registerDRep:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .unRegisterDRep:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .updateDRep:
                return CertificateMainCommand.StakeAddressRegistrationCertificate.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

struct CertificateMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "certificate",
        abstract: "Generate various certificate.",
        subcommands: CertificateCommands.allCases.map { $0.command() },
        aliases: ["cert"]
    )
    
    func run() async throws {
        let selectedOption: CertificateCommands = noora.singleChoicePrompt(
            title: "Select Certificate Command",
            question: "Select the operation that you would like to perform.",
            description: "Available commands:" ,
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}

extension CertificateMainCommand {
    
    struct StakeAddressRegistrationCertificate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generates the registration certificate name.stake.cert to register a stake-address from the blockchain."
        )
        
        func run() async throws {
            print("Generate stake address registration certificate command not yet implemented")
        }
    }
    
    struct StakepoolRegistrationCertificate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generates the certificate poolName.pool.cert to (re)register a stakepool on the blockchain."
        )
        
        func run() async throws {
            print("Generate stakepool registration certificate command not yet implemented")
        }
    }
    
    struct StakepoolDeregistrationCertificate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generates the certificate poolName.pool.dereg-cert to retire a stakepool from the blockchain."
        )
        
        func run() async throws {
            print("Generate stakepool deregistration certificate command not yet implemented")
        }
    }
}
