import Foundation
import ArgumentParser

enum QueryCommands: String, CaseIterable, CustomStringConvertible {
    case tip
    case balance
    case utxo
    case protocolParameters = "protocol-parameters"
    case stakePool = "stake-pool"
    case stakeDistribution = "stake-distribution"
    case leadershipSchedule = "leadership-schedule"
    case kesPeriodInfo = "kes-period-info"
    
    var description: String {
        switch self {
        case .tip: return "Query the tip of the blockchain."
        case .balance: return "Query balance of an address."
        case .utxo: return "Query UTXOs of an address."
        case .protocolParameters: return "Query protocol parameters."
        case .stakePool: return "Query stake pool information."
        case .stakeDistribution: return "Query stake distribution."
        case .leadershipSchedule: return "Query leadership schedule."
        case .kesPeriodInfo: return "Query KES period information."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
        case .tip: return QueryMainCommand.Tip.self
        case .balance: return QueryMainCommand.Balance.self
        case .utxo: return QueryMainCommand.Utxo.self
        case .protocolParameters: return QueryMainCommand.ProtocolParameters.self
        case .stakePool: return QueryMainCommand.StakePool.self
        case .stakeDistribution: return QueryMainCommand.StakeDistribution.self
        case .leadershipSchedule: return QueryMainCommand.LeadershipSchedule.self
        case .kesPeriodInfo: return QueryMainCommand.KesPeriodInfo.self
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
        print("Use 'query --help' to see available subcommands")
    }
}

extension QueryMainCommand {
    struct Tip: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query the tip of the blockchain.")
        func run() async throws { print("Query tip command not yet implemented") }
    }
    
    struct Balance: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query balance of an address.")
        func run() async throws { print("Query balance command not yet implemented") }
    }
    
    struct Utxo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query UTXOs of an address.")
        func run() async throws { print("Query utxo command not yet implemented") }
    }
    
    struct ProtocolParameters: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query protocol parameters.")
        func run() async throws { print("Query protocol parameters command not yet implemented") }
    }
    
    struct StakePool: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query stake pool information.")
        func run() async throws { print("Query stake pool command not yet implemented") }
    }
    
    struct StakeDistribution: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query stake distribution.")
        func run() async throws { print("Query stake distribution command not yet implemented") }
    }
    
    struct LeadershipSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query leadership schedule.")
        func run() async throws { print("Query leadership schedule command not yet implemented") }
    }
    
    struct KesPeriodInfo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query KES period information.")
        func run() async throws { print("Query KES period info command not yet implemented") }
    }
}
