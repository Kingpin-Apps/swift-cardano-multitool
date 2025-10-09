import Foundation
import ArgumentParser

enum DeregisterCommands: String, CaseIterable, CustomStringConvertible {
    case stakePool = "stake-pool"
    case stakeAddress = "stake-address"
    case drep
    
    var description: String {
        switch self {
        case .stakePool: return "De-register a stake pool."
        case .stakeAddress: return "De-register a stake address."
        case .drep: return "De-register a DRep."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
        case .stakePool: return DeregisterMainCommand.StakePool.self
        case .stakeAddress: return DeregisterMainCommand.StakeAddress.self
        case .drep: return DeregisterMainCommand.Drep.self
        }
    }
}

struct DeregisterMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deregister",
        abstract: "De-Register various data on chain.",
        subcommands: DeregisterCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        print("Use 'deregister --help' to see available subcommands")
    }
}

extension DeregisterMainCommand {
    struct StakePool: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "De-register a stake pool.")
        func run() async throws { print("Deregister stake pool command not yet implemented") }
    }
    
    struct StakeAddress: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "De-register a stake address.")
        func run() async throws { print("Deregister stake address command not yet implemented") }
    }
    
    struct Drep: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "De-register a DRep.")
        func run() async throws { print("Deregister DRep command not yet implemented") }
    }
}
