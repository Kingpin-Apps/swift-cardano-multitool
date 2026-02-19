import Foundation
import ArgumentParser

enum GenerateCommands: String, CaseIterable, CustomStringConvertible {
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
                return "Generate the node cold keys."
            case .nodeKesKeys:
                return "Generate the node KES keys."
            case .nodeVrfKeys:
                return "Generate the node vrf keys."
            case .nodeOperationalCertificate:
                return "Generate the node operational certificate."
            case .paymentAddressOnly:
                return "Generate a payment address only."
            case .paymentAndStakeAddress:
                return "Generate a payment and stake address."
            case .keyRotation:
                return "Key Rotation - Rotate KES keys and generate a new operational certificate."
            case .poolJSON:
                return "Pool.json - Generate a new pool.json file."
            case .back:
                return "Go back to the main menu."
            case .exit: 
                return "Exit the program."
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

struct GenerateMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate various files.",
        subcommands: GenerateCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        let selectedOption: GenerateCommands = noora.singleChoicePrompt(
            title: "Select Generate Command",
            question: "Select the operation that you would like to perform.",
            description: "Available commands:" ,
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}
