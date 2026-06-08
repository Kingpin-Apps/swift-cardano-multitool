import Foundation
import ArgumentParser

enum GovernanceCommands: String, Subcommandable, AlignedChoiceDescribable {
    case vote
    case infoAction = "info-action"
    case treasuryWithdrawal = "treasury-withdrawal"
    case noConfidence = "no-confidence"
    case newConstitution = "new-constitution"
    case hardForkInitiation = "hard-fork-initiation"
    case updateCommittee = "update-committee"
    case parameterChange = "parameter-change"
    case submitAction = "submit-action"
    case canonize
    case cip129
    case back
    case exit

    var name: String {
        switch self {
            case .vote: return "Vote"
            case .infoAction: return "Create Info Action"
            case .treasuryWithdrawal: return "Create Treasury Withdrawal"
            case .noConfidence: return "Create No-Confidence Motion"
            case .newConstitution: return "Create New Constitution"
            case .hardForkInitiation: return "Create Hard-Fork Initiation"
            case .updateCommittee: return "Create Update-Committee Action"
            case .parameterChange: return "Create Parameter-Change Action"
            case .submitAction: return "Submit Pre-Built Action File"
            case .canonize: return "Canonize CIP-100 Metadata"
            case .cip129: return "CIP-129 ID Encode / Decode"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .vote:
                return "Cast a Conway-era on-chain vote on a governance action."
            case .infoAction:
                return "Build + submit an informational governance action (anchor only)."
            case .treasuryWithdrawal:
                return "Build + submit a treasury-withdrawal governance action."
            case .noConfidence:
                return "Build + submit a no-confidence motion against the constitutional committee."
            case .newConstitution:
                return "Build + submit a new-constitution proposal."
            case .hardForkInitiation:
                return "Build + submit a hard-fork-initiation action."
            case .updateCommittee:
                return "Build + submit an update-committee action (add/remove members + threshold)."
            case .parameterChange:
                return "Build + submit a protocol-parameter-update action."
            case .submitAction:
                return "Submit one or more previously generated .action files as a single transaction."
            case .canonize:
                return "Compute the URDNA2015 canonical form and blake2b-256 hash of a CIP-100 JSON-LD document."
            case .cip129:
                return "Encode or decode CIP-129 / CIP-151 bech32 governance identifiers (drep, cc_cold, cc_hot, calidus)."
            case .back:
                return "Go back to the main menu."
            case .exit:
                return "Leave the program."
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
            case .vote: return GovernanceMainCommand.Vote.self
            case .infoAction: return GovernanceMainCommand.InfoAction.self
            case .treasuryWithdrawal: return GovernanceMainCommand.TreasuryWithdrawal.self
            case .noConfidence: return GovernanceMainCommand.NoConfidence.self
            case .newConstitution: return GovernanceMainCommand.NewConstitution.self
            case .hardForkInitiation: return GovernanceMainCommand.HardForkInitiation.self
            case .updateCommittee: return GovernanceMainCommand.UpdateCommittee.self
            case .parameterChange: return GovernanceMainCommand.ParameterChange.self
            case .submitAction: return GovernanceMainCommand.SubmitAction.self
            case .canonize: return GovernanceMainCommand.Canonize.self
            case .cip129: return GovernanceMainCommand.CIP129Command.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Conway-era governance operations: cast votes and submit governance-action proposals.
///
/// `vote` wraps the build–sign–submit pipeline for DRep / SPO / CC-hot voters (bash
/// `24a_genVote.sh` + `24b_regVote.sh`). The seven `create-*` subcommands plus
/// `submit-action` port `25a_genAction.sh` + `25b_regAction.sh`. All commands reuse
/// the shared `TransactionSendable` infrastructure (UTxO query → TxBuilder → Sign).
struct GovernanceMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = GovernanceCommands

    var name: String { "Governance" }

    static let configuration = CommandConfiguration(
        commandName: "governance",
        abstract: "Cast votes and submit governance-action proposals.",
        discussion: """
        High-level Conway-era governance commands. Pass an optional anchor
        (CIP-100 metadata) on any subcommand and it will be downloaded and
        blake2b-256 hash-verified before broadcasting — disable with
        --skip-anchor-verify.

        Each create-* subcommand can be run with --generate-only to emit just
        the .action file (no transaction). submit-action then takes one or
        more such files and builds + signs + submits the proposal transaction.
        """,
        subcommands: GovernanceCommands.subcommands
    )
}
