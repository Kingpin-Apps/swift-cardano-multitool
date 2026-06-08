import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Argument-parsing smoke tests for GovernanceMainCommand subcommands.
///
/// The TransactionSendable subcommands (vote, info-action, treasury-withdrawal,
/// no-confidence, new-constitution, hard-fork-initiation, update-committee,
/// parameter-change, submit-action) all require a configured chain context to
/// run end-to-end. These tests stay at the argument-parsing and configuration
/// layer, exercising flag shapes without invoking the network.

@Suite("GovernanceMainCommand")
struct GovernanceMainCommandTests {

    @Test("commandName is 'governance'")
    func commandName() {
        #expect(GovernanceMainCommand.configuration.commandName == "governance")
    }

    @Test("subcommands list contains every non-menu case")
    func subcommandsRegistered() {
        let names = GovernanceMainCommand.configuration.subcommands.map { $0.configuration.commandName }
        #expect(names.contains("vote"))
        #expect(names.contains("info-action"))
        #expect(names.contains("treasury-withdrawal"))
        #expect(names.contains("no-confidence"))
        #expect(names.contains("new-constitution"))
        #expect(names.contains("hard-fork-initiation"))
        #expect(names.contains("update-committee"))
        #expect(names.contains("parameter-change"))
        #expect(names.contains("submit-action"))
        #expect(names.contains("canonize"))
        #expect(names.contains("cip129"))
    }

    @Test("GovernanceCommands name / details non-empty for every case")
    func commandLabels() {
        for c in GovernanceCommands.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

// MARK: - InfoAction

@Suite("GovernanceMainCommand.InfoAction")
struct InfoActionTests {
    @Test("commandName is 'info-action'")
    func commandName() {
        #expect(GovernanceMainCommand.InfoAction.configuration.commandName == "info-action")
    }

    @Test("parses with no arguments (wizard would run)")
    func parsesEmpty() throws {
        _ = try GovernanceMainCommand.InfoAction.parse([])
    }
}

// MARK: - NoConfidence

@Suite("GovernanceMainCommand.NoConfidence")
struct NoConfidenceTests {
    @Test("commandName is 'no-confidence'")
    func commandName() {
        #expect(GovernanceMainCommand.NoConfidence.configuration.commandName == "no-confidence")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        let cmd = try GovernanceMainCommand.NoConfidence.parse([])
        #expect(cmd.prevActionId == nil)
    }

    @Test("parses --prev-action-id")
    func parsesPrevActionId() throws {
        let cmd = try GovernanceMainCommand.NoConfidence.parse([
            "--prev-action-id", "gov_action1xyz"
        ])
        #expect(cmd.prevActionId == "gov_action1xyz")
    }
}

// MARK: - HardForkInitiation

@Suite("GovernanceMainCommand.HardForkInitiation")
struct HardForkInitiationTests {
    @Test("commandName is 'hard-fork-initiation'")
    func commandName() {
        #expect(GovernanceMainCommand.HardForkInitiation.configuration.commandName == "hard-fork-initiation")
    }

    @Test("parses --protocol-version")
    func parsesProtocolVersion() throws {
        let cmd = try GovernanceMainCommand.HardForkInitiation.parse([
            "--protocol-version", "10.0"
        ])
        #expect(cmd.protocolVersion == "10.0")
    }
}

// MARK: - NewConstitution

@Suite("GovernanceMainCommand.NewConstitution")
struct NewConstitutionTests {
    @Test("commandName is 'new-constitution'")
    func commandName() {
        #expect(GovernanceMainCommand.NewConstitution.configuration.commandName == "new-constitution")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try GovernanceMainCommand.NewConstitution.parse([])
    }
}

// MARK: - TreasuryWithdrawal

@Suite("GovernanceMainCommand.TreasuryWithdrawal")
struct TreasuryWithdrawalTests {
    @Test("commandName is 'treasury-withdrawal'")
    func commandName() {
        #expect(GovernanceMainCommand.TreasuryWithdrawal.configuration.commandName == "treasury-withdrawal")
    }

    @Test("parses an empty withdrawal list by default")
    func defaults() throws {
        let cmd = try GovernanceMainCommand.TreasuryWithdrawal.parse([])
        #expect(cmd.withdrawal.isEmpty)
    }

    @Test("parses repeated --withdrawal values")
    func parsesRepeatedWithdrawal() throws {
        let cmd = try GovernanceMainCommand.TreasuryWithdrawal.parse([
            "--withdrawal", "stake1abc:1000",
            "--withdrawal", "stake1def:2000"
        ])
        #expect(cmd.withdrawal == ["stake1abc:1000", "stake1def:2000"])
    }

    @Test("parses --guardrails-script-hash")
    func parsesGuardrails() throws {
        let cmd = try GovernanceMainCommand.TreasuryWithdrawal.parse([
            "--guardrails-script-hash", String(repeating: "a", count: 56)
        ])
        #expect(cmd.guardrailsScriptHash == String(repeating: "a", count: 56))
    }
}

// MARK: - ParameterChange

@Suite("GovernanceMainCommand.ParameterChange")
struct ParameterChangeTests {
    @Test("commandName is 'parameter-change'")
    func commandName() {
        #expect(GovernanceMainCommand.ParameterChange.configuration.commandName == "parameter-change")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try GovernanceMainCommand.ParameterChange.parse([])
    }
}

// MARK: - UpdateCommittee

@Suite("GovernanceMainCommand.UpdateCommittee")
struct UpdateCommitteeTests {
    @Test("commandName is 'update-committee'")
    func commandName() {
        #expect(GovernanceMainCommand.UpdateCommittee.configuration.commandName == "update-committee")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try GovernanceMainCommand.UpdateCommittee.parse([])
    }
}

// MARK: - SubmitAction

@Suite("GovernanceMainCommand.SubmitAction")
struct SubmitActionTests {
    @Test("commandName is 'submit-action'")
    func commandName() {
        #expect(GovernanceMainCommand.SubmitAction.configuration.commandName == "submit-action")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try GovernanceMainCommand.SubmitAction.parse([])
    }
}

// MARK: - Vote

@Suite("GovernanceMainCommand.Vote")
struct GovernanceVoteTests {
    @Test("commandName is 'vote'")
    func commandName() {
        #expect(GovernanceMainCommand.Vote.configuration.commandName == "vote")
    }

    @Test("parses with no positionals (wizard would run)")
    func parsesEmpty() throws {
        let cmd = try GovernanceMainCommand.Vote.parse([])
        #expect(cmd.govActionId == nil)
        #expect(cmd.choice == nil)
    }

    @Test("parses positional govActionId and yes/no/abstain choices")
    func parsesPositionals() throws {
        for choice in ["yes", "no", "abstain"] {
            let cmd = try GovernanceMainCommand.Vote.parse(["gov_action1xyz", choice])
            #expect(cmd.govActionId == "gov_action1xyz")
            #expect(cmd.choice != nil)
        }
    }

    @Test("ttl extra defaults to 500")
    func ttlDefault() throws {
        let cmd = try GovernanceMainCommand.Vote.parse([])
        #expect(cmd.ttlExtra == 500)
    }
}

// MARK: - Canonize

@Suite("GovernanceMainCommand.Canonize")
struct CanonizeTests {
    @Test("commandName is 'canonize'")
    func commandName() {
        #expect(GovernanceMainCommand.Canonize.configuration.commandName == "canonize")
    }

    @Test("defaults are nil")
    func defaults() throws {
        let cmd = try GovernanceMainCommand.Canonize.parse([])
        #expect(cmd.data == nil)
        #expect(cmd.dataFile == nil)
        #expect(cmd.outCanonized == nil)
    }

    @Test("parses --data-file and --out-canonized")
    func parsesFileOptions() throws {
        let cmd = try GovernanceMainCommand.Canonize.parse([
            "--data-file", "/tmp/doc.jsonld",
            "--out-canonized", "/tmp/doc.nq"
        ])
        #expect(cmd.dataFile?.string == "/tmp/doc.jsonld")
        #expect(cmd.outCanonized?.string == "/tmp/doc.nq")
    }
}

// MARK: - CIP129

@Suite("GovernanceMainCommand.CIP129Command")
struct CIP129CommandTests {
    @Test("commandName is 'cip129'")
    func commandName() {
        #expect(GovernanceMainCommand.CIP129Command.configuration.commandName == "cip129")
    }

    @Test("encode and decode subcommands are registered")
    func subcommandsRegistered() {
        let names = GovernanceMainCommand.CIP129Command.configuration.subcommands.map { $0.configuration.commandName }
        #expect(names.contains("encode"))
        #expect(names.contains("decode"))
    }
}

@Suite("GovernanceMainCommand.CIP129Command.Encode")
struct CIP129EncodeTests {
    @Test("defaults: no prefix, no key-hash, script false")
    func defaults() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Encode.parse([])
        #expect(cmd.prefix == nil)
        #expect(cmd.keyHash == nil)
        #expect(cmd.script == false)
    }

    @Test("parses --prefix and --key-hash")
    func parsesPrefixAndKeyHash() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Encode.parse([
            "--prefix", "drep",
            "--key-hash", String(repeating: "a", count: 56)
        ])
        #expect(cmd.prefix == "drep")
        #expect(cmd.keyHash == String(repeating: "a", count: 56))
    }

    @Test("parses --script flag")
    func parsesScriptFlag() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Encode.parse(["--script"])
        #expect(cmd.script == true)
    }
}

@Suite("GovernanceMainCommand.CIP129Command.Decode")
struct CIP129DecodeTests {
    @Test("defaults: no id")
    func defaults() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Decode.parse([])
        #expect(cmd.id == nil)
    }

    @Test("parses --id")
    func parsesId() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Decode.parse(["--id", "drep1ygx"])
        #expect(cmd.id == "drep1ygx")
    }
}
