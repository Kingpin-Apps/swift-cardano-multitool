import Foundation
import ArgumentParser

enum QueryCommands: String, CaseIterable, CustomStringConvertible {
    case address
    case epoch
    case era
    case kesPeriodInfo = "kes-period-info"
    case leadershipSchedule = "leadership-schedule"
    case protocolParameters = "protocol-parameters"
    case stakeDistribution = "stake-distribution"
    case stakePool = "stake-pool"
    case tip
    case back
    case exit
    
    var description: String {
        switch self {
            case .address: return "Address - Query an address."
            case .epoch: return "Epoch - Query information about a specific epoch."
            case .era: return "Era - Query information about a specific era."
            case .kesPeriodInfo: return "KES Period Info - Check a node opcert KES period information."
            case .leadershipSchedule: return "Leadership Schedule - Query leadership schedule."
            case .protocolParameters: return "Protocol Parameters - Query protocol parameters."
            case .stakeDistribution: return "Query stake distribution."
            case .stakePool: return "Query stake pool information."
            case .tip: return "Tip - Query the tip of the blockchain."
            case .back: return "Go back to the main menu."
            case .exit: return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .address: return QueryMainCommand.Address.self
            case .epoch: return QueryMainCommand.Epoch.self
            case .era: return QueryMainCommand.Era.self
            case .kesPeriodInfo: return QueryMainCommand.KesPeriodInfo.self
            case .leadershipSchedule: return QueryMainCommand.LeadershipSchedule.self
            case .protocolParameters: return QueryMainCommand.ProtocolParameters.self
            case .stakeDistribution: return QueryMainCommand.StakeDistribution.self
            case .stakePool: return QueryMainCommand.StakePool.self
            case .tip: return QueryMainCommand.Tip.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct QueryMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Query various data from cardano-node.",
        subcommands: QueryCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        let selectedOption: QueryCommands = noora.singleChoicePrompt(
            title: "Select Query Command",
            question: "Select the operation that you would like to perform.",
            description: "Query various data from the Cardano blockchain."
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}

extension QueryMainCommand {    
    struct StakeDistribution: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query stake distribution.")
        func run() async throws { print("Query stake distribution command not yet implemented") }
    }
    
    struct LeadershipSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query leadership schedule.")
        func run() async throws { print("Query leadership schedule command not yet implemented") }
    }
}
