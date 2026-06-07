import Foundation
import ArgumentParser

enum QueryCommands: String, Subcommandable, AlignedChoiceDescribable {
    case address
    case assetMeta = "asset-meta"
    case committeeMember = "committee-member"
    case drep
    case epoch
    case era
    case governanceAction = "governance-action"
    case kesPeriodInfo = "kes-period-info"
    case leadershipSchedule = "leadership-schedule"
    case protocolParameters = "protocol-parameters"
    case stakePool = "stake-pool"
    case tip
    case vote
    case back
    case exit

    var name: String {
        switch self {
            case .address: return "Address"
            case .assetMeta: return "Asset Metadata"
            case .committeeMember: return "Committee Member"
            case .drep: return "DRep"
            case .epoch: return "Epoch"
            case .era: return "Era"
            case .governanceAction: return "Governance Action"
            case .kesPeriodInfo: return "KES Period Info"
            case .leadershipSchedule: return "Leadership Schedule"
            case .protocolParameters: return "Protocol Parameters"
            case .stakePool: return "Stake Pool"
            case .tip: return "Tip"
            case .vote: return "Vote"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .address: return "Query an address."
            case .assetMeta: return "Query off-chain metadata for a native asset from the Cardano Token Registry."
            case .committeeMember: return "Query on-chain state for a constitutional-committee member."
            case .drep: return "Query on-chain DRep state and verify anchor metadata."
            case .epoch: return "Query information about a specific epoch."
            case .era: return "Query information about a specific era."
            case .governanceAction: return "Query on-chain state for a governance action."
            case .kesPeriodInfo: return "Check a node opcert KES period information."
            case .leadershipSchedule: return "Query leadership schedule."
            case .protocolParameters: return "Query protocol parameters."
            case .stakePool: return "Query stake pool information."
            case .tip: return "Query the tip of the blockchain."
            case .vote: return "Query votes on governance actions, filtered by voter, action ID, or action type."
            case .back: return "Go back to the main menu."
            case .exit: return "Leave the program."
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
            case .assetMeta: return QueryMainCommand.AssetMeta.self
            case .committeeMember: return QueryMainCommand.CommitteeMember.self
            case .drep: return QueryMainCommand.DRep.self
            case .epoch: return QueryMainCommand.Epoch.self
            case .era: return QueryMainCommand.Era.self
            case .governanceAction: return QueryMainCommand.GovernanceAction.self
            case .kesPeriodInfo: return QueryMainCommand.KesPeriodInfo.self
            case .leadershipSchedule: return QueryMainCommand.LeadershipSchedule.self
            case .protocolParameters: return QueryMainCommand.ProtocolParameters.self
            case .stakePool: return QueryMainCommand.StakePool.self
            case .tip: return QueryMainCommand.Tip.self
            case .vote: return QueryMainCommand.Vote.self
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

