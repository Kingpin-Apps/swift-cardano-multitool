import Foundation
import ArgumentParser
import Noora

enum CheckCommands: String, CaseIterable, CustomStringConvertible {
    case nodeOperationalCertificate
    case stakepool
    case stakeAddress
    case back
    case exit
    
    var description: String {
        switch self {
            case .nodeOperationalCertificate:
                return "Check the operational certificate of the node."
            case .stakepool:
                return "Check the stakepool information on chain."
            case .stakeAddress:
                return "Check a stake address information on chain."
            case .back:
                return "Go back to the main menu."
            case .exit:
                return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .nodeOperationalCertificate:
                return CheckMainCommand.NodeOperationalCertificate.self
            case .stakepool:
                return CheckMainCommand.Stakepool.self
            case .stakeAddress:
                return CheckMainCommand.StakeAddress.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

struct CheckMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check various data on chain.",
        subcommands: CheckCommands.allCases.map { $0.command() },
    )
    
    func run() async throws {
    }
}


extension CheckMainCommand {
    struct NodeOperationalCertificate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check the operational certificate of the node."
        )
        
        func run() async throws {
        }
    }
    struct Stakepool: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check the stakepool information on chain."
        )
        
        func run() async throws {
        }
    }
    struct StakeAddress: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Check a stake address information on chain."
        )
        
        func run() async throws {
        }
    }
    
}
