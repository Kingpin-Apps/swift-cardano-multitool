import Foundation
import ArgumentParser

enum QueryCommands: String, Subcommandable {
    case address
    case epoch
    case era
    case kesPeriodInfo = "kes-period-info"
    case leadershipSchedule = "leadership-schedule"
    case protocolParameters = "protocol-parameters"
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
            case .stakePool: return "Stake Pool - Query stake pool information."
            case .tip: return "Tip - Query the tip of the blockchain."
            case .back: return "Back - Go back to the main menu."
            case .exit: return "Exit - Leave the program."
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
            case .address: return QueryMainCommand.Address.self
            case .epoch: return QueryMainCommand.Epoch.self
            case .era: return QueryMainCommand.Era.self
            case .kesPeriodInfo: return QueryMainCommand.KesPeriodInfo.self
            case .leadershipSchedule: return QueryMainCommand.LeadershipSchedule.self
            case .protocolParameters: return QueryMainCommand.ProtocolParameters.self
            case .stakePool: return QueryMainCommand.StakePool.self
            case .tip: return QueryMainCommand.Tip.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct QueryMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = QueryCommands
    
    var name: String { "Query" }
    
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Query various data from cardano-node.",
        discussion: """
        Query various data from the Cardano blockchain, such as addresses, 
        epochs, eras, protocol parameters, stake pools, and more. This command 
        provides a user-friendly interface to access on-chain information and 
        node status.
        """,
        subcommands: QueryCommands.subcommands
    )
}

