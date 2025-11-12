import Foundation
import ArgumentParser
import Noora

enum BuildCommands: String, CaseIterable, CustomStringConvertible {
    case paymentAddress
    case stakeAddress
    case back
    case exit
    
    var description: String {
        switch self {
            case .paymentAddress:
                return "Payment Address - Build a Cardano payment address from the Cardano-cli address key files."
            case .stakeAddress:
                return "Stake Address - Build a Cardano stake address from the stake verification key file."
            case .back:
                return "Go back to the main menu."
            case .exit:
                return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .paymentAddress:
                return BuildMainCommand.PaymentAddress.self
            case .stakeAddress:
                return BuildMainCommand.StakeAddress.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

struct BuildMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build operations",
        subcommands: BuildCommands.allCases.map { $0.command() },
    )
    
    func run() async throws {                
        let selectedOption: BuildCommands = noora.singleChoicePrompt(
            title: "Select Build Command",
            question: "Select the operation that you would like to perform.",
            description: "Build Commands to build addresses.",
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}
