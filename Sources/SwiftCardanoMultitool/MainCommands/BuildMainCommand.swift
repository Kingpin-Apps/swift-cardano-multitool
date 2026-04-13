import Foundation
import ArgumentParser
import Noora

enum BuildCommands: String, Subcommandable {
    case paymentAddress
    case stakeAddress
    case back
    case exit
    
    var description: String {
        switch self {
            case .paymentAddress:
                return "Payment Address - Build a Cardano payment address from the cli address key files."
            case .stakeAddress:
                return "Stake Address - Build a Cardano stake address from the stake verification key file."
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

struct BuildMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = BuildCommands
    
    var name: String { "Build" }
    
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build operations for Cardano addresses.",
        discussion: """
        Build various types of Cardano addresses from their corresponding 
        key files. For payment addresses, provide the payment verification 
        key file and optionally the stake verification key file to build a 
        base address. For stake addresses, provide the stake verification 
        key file to build a stake address.
        """,
        subcommands: BuildCommands.subcommands,
    )
}
