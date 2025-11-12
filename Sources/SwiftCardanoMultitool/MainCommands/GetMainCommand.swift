import Foundation
import ArgumentParser

enum GetCommands: String, CaseIterable, CustomStringConvertible {
    case era
    case epoch
    case protocolParameters = "protocol-parameters"
    case leadershipSchedule = "leadership-schedule"
    case version
    case back
    case exit
    
    var description: String {
        switch self {
            case .era: return "Get current era."
            case .epoch: return "Get current epoch."
            case .protocolParameters: return "Get protocol parameters."
            case .leadershipSchedule: return "Get leadership schedule."
            case .version: return "Get node version."
            case .back: return "Go back to the main menu."
            case .exit: return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .era: return GetMainCommand.Era.self
            case .epoch: return GetMainCommand.Epoch.self
            case .protocolParameters: return GetMainCommand.ProtocolParameters.self
            case .leadershipSchedule: return GetMainCommand.LeadershipSchedule.self
            case .version: return GetMainCommand.Version.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct GetMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get various data from cardano-node.",
        subcommands: GetCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        print("Use 'get --help' to see available subcommands")
    }
}

extension GetMainCommand {
    struct Era: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get current era.")
        func run() async throws { print("Get era command not yet implemented") }
    }
    
    struct Epoch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get current epoch.")
        func run() async throws { print("Get epoch command not yet implemented") }
    }
    
    struct ProtocolParameters: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get protocol parameters.")
        func run() async throws { print("Get protocol parameters command not yet implemented") }
    }
    
    struct LeadershipSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get leadership schedule.")
        func run() async throws { print("Get leadership schedule command not yet implemented") }
    }
    
    struct Version: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get node version.")
        func run() async throws { print("Get version command not yet implemented") }
    }
}
