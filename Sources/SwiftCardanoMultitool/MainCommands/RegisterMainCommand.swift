import Foundation
import ArgumentParser

enum RegisterCommands: String, CaseIterable, CustomStringConvertible {
    case stakePool = "stake-pool"
    case stakeAddress = "stake-address"
    case drep
    case back
    case exit
    
    var description: String {
        switch self {
            case .stakePool: return "Register a stake pool."
            case .stakeAddress: return "Register a stake address."
            case .drep: return "Register a DRep."
            case .back: return "Go back to the main menu."
            case .exit: return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .stakePool: return RegisterMainCommand.StakePool.self
            case .stakeAddress: return RegisterMainCommand.StakeAddress.self
            case .drep: return RegisterMainCommand.Drep.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct RegisterMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "register",
        abstract: "Register data on the blockchain.",
        subcommands: RegisterCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        print("Use 'register --help' to see available subcommands")
    }
}

extension RegisterMainCommand {
    struct StakePool: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Register a stake pool.")
        func run() async throws { print("Register stake pool command not yet implemented") }
    }
    
    struct StakeAddress: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Register a stake address.")
        func run() async throws { print("Register stake address command not yet implemented") }
    }
    
    struct Drep: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Register a DRep.")
        func run() async throws { print("Register DRep command not yet implemented") }
    }
}
