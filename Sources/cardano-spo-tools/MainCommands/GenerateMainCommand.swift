import Foundation
import ArgumentParser

enum GenerateCommands: String, CaseIterable, CustomStringConvertible {
    case config = "config"
    case delegationCertificate = "delegation-certificate"
    case nodeColdKeys = "node-cold-keys"
    case nodeKesKeys = "node-kes-keys"
    case nodeOperationalCertificate = "node-operational-certificate"
    case nodeVrfKeys = "node-vrf-keys"
    case paymentAddressOnly = "payment-address-only"
    case paymentAndStakeAddress = "payment-and-stake-address"
    case keyRotation = "key-rotation"
    case stakeAddressRegistrationCertificate = "stake-address-registration-certificate"
    case stakepoolRegistrationCertificate = "stakepool-registration-certificate"
    case stakepoolDeregistrationCertificate = "stakepool-deregistration-certificate"
    
    var description: String {
        switch self {
        case .config:
            return "Generate a config.toml file."
        case .delegationCertificate:
            return "Generates the delegation certificate name.deleg.cert to delegate stake to a stakepool."
        case .nodeColdKeys:
            return "Generate the node cold keys."
        case .nodeKesKeys:
            return "Generate the node cold keys."
        case .nodeOperationalCertificate:
            return "Generate the node operational certificate."
        case .nodeVrfKeys:
            return "Generate the node vrf keys."
        case .paymentAddressOnly:
            return "Generate a payment address only."
        case .paymentAndStakeAddress:
            return "Generate a payment and stake address."
        case .keyRotation:
            return "Rotate KES Keys and Node Operational Certificate :param name: The name of the pools :param number_of_pools: The number of pools to rotate"
        case .stakeAddressRegistrationCertificate:
            return "Generates the registration certificate name.stake.cert to register a stake-address from the blockchain."
        case .stakepoolRegistrationCertificate:
            return "Generates the certificate poolName.pool.cert to (re)register a stakepool on the blockchain."
        case .stakepoolDeregistrationCertificate:
            return "Generates the certificate poolName.pool.dereg-cert to retire a stakepool from the blockchain."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
        case .config:
            return GenerateMainCommand.Config.self
        case .delegationCertificate:
            return GenerateMainCommand.DelegationCertificate.self
        case .nodeColdKeys:
            return GenerateMainCommand.NodeColdKeys.self
        case .nodeKesKeys:
            return GenerateMainCommand.NodeKesKeys.self
        case .nodeOperationalCertificate:
            return GenerateMainCommand.NodeOperationalCertificate.self
        case .nodeVrfKeys:
            return GenerateMainCommand.NodeVrfKeys.self
        case .paymentAddressOnly:
            return GenerateMainCommand.PaymentAddressOnly.self
        case .paymentAndStakeAddress:
            return GenerateMainCommand.PaymentAndStakeAddress.self
        case .keyRotation:
            return GenerateMainCommand.KeyRotation.self
        case .stakeAddressRegistrationCertificate:
            return GenerateMainCommand.StakeAddressRegistrationCertificate.self
        case .stakepoolRegistrationCertificate:
            return GenerateMainCommand.StakepoolRegistrationCertificate.self
        case .stakepoolDeregistrationCertificate:
            return GenerateMainCommand.StakepoolDeregistrationCertificate.self
        }
    }
}

struct GenerateMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate various files.",
        subcommands: GenerateCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        print("Use 'generate --help' to see available subcommands")
    }
}

extension GenerateMainCommand {
    struct Config: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a config.toml file."
        )
        
        func run() async throws {
            print("Generate config command not yet implemented")
        }
    }
    
    struct DelegationCertificate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generates the delegation certificate name.deleg.cert to delegate stake to a stakepool."
        )
        
        func run() async throws {
            print("Generate delegation certificate command not yet implemented")
        }
    }
    
    struct NodeColdKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate the node cold keys."
        )
        
        func run() async throws {
            print("Generate node cold keys command not yet implemented")
        }
    }
    
    struct NodeKesKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate the node KES keys."
        )
        
        func run() async throws {
            print("Generate node KES keys command not yet implemented")
        }
    }
    
    struct NodeOperationalCertificate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate the node operational certificate."
        )
        
        func run() async throws {
            print("Generate node operational certificate command not yet implemented")
        }
    }
    
    struct NodeVrfKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate the node VRF keys."
        )
        
        func run() async throws {
            print("Generate node VRF keys command not yet implemented")
        }
    }
    
    struct PaymentAddressOnly: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a payment address only."
        )
        
        func run() async throws {
            print("Generate payment address only command not yet implemented")
        }
    }
    
    struct PaymentAndStakeAddress: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a payment and stake address."
        )
        
        func run() async throws {
            print("Generate payment and stake address command not yet implemented")
        }
    }
    
    struct KeyRotation: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Rotate KES Keys and Node Operational Certificate."
        )
        
        func run() async throws {
            print("Key rotation command not yet implemented")
        }
    }
    
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
