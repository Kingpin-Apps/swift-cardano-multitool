import Foundation
import ArgumentParser

enum GenerateCommands: String, Subcommandable {
    case nodeColdKeys = "node-cold-keys"
    case nodeKesKeys = "node-kes-keys"
    case nodeOperationalCertificate = "node-operational-certificate"
    case nodeVrfKeys = "node-vrf-keys"
    case paymentAddressOnly = "payment-address-only"
    case paymentAndStakeAddress = "payment-and-stake-address"
    case keyRotation = "key-rotation"
    case poolJSON = "pool-json"
    case back
    case exit
    
    var description: String {
        switch self {
            case .nodeColdKeys:
                return "Cold keys - Generate a new set of cold keys."
            case .nodeKesKeys:
                return "KES keys - Generate the node KES keys."
            case .nodeVrfKeys:
                return "VRF keys - Generate the node VRF keys."
            case .nodeOperationalCertificate:
                return "Operational Certificate - Generate the node operational certificate."
            case .paymentAddressOnly:
                return "Payment Address - Generate a payment address only."
            case .paymentAndStakeAddress:
                return "Payment and Stake Address - Generate a payment and stake address."
            case .keyRotation:
                return "Key Rotation - Rotate KES keys and generate a new operational certificate."
            case .poolJSON:
                return "Pool.json - Generate a new pool.json file."
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
            case .nodeColdKeys:
                return GenerateMainCommand.NodeColdKeys.self
            case .nodeKesKeys:
                return GenerateMainCommand.NodeKESKeys.self
            case .nodeVrfKeys:
                return GenerateMainCommand.NodeVRFKeys.self
            case .nodeOperationalCertificate:
                return GenerateMainCommand.NodeOperationalCertificate.self
            case .paymentAddressOnly:
                return GenerateMainCommand.PaymentAddressOnly.self
            case .paymentAndStakeAddress:
                return GenerateMainCommand.PaymentAndStakeAddress.self
            case .keyRotation:
                return GenerateMainCommand.KeyRotation.self
            case .poolJSON:
                return GenerateMainCommand.PoolJSON.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

struct GenerateMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = GenerateCommands
    
    var name: String { "Generate" }
    
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate various files.",
        discussion: """
        Generate various files needed for interacting with the Cardano 
        blockchain, such as keys, addresses, certificates and pool.json files. 
        Select the type of file you want to generate and follow the prompts.
        """,
        subcommands: GenerateCommands.subcommands,
        aliases: ["gen"]
    )
}
