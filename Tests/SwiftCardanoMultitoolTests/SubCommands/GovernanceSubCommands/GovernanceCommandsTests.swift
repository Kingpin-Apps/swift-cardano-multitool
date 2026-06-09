import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Argument-parsing behavior tests for GovernanceMainCommand subcommands.
///
/// Full behavior tests need a configured chain context. These tests stay at the
/// argument-parsing layer and exercise flag shapes that have validation or
/// non-trivial parsing rules.

@Suite("GovernanceMainCommand.NoConfidence")
struct NoConfidenceTests {

    @Test("parses --prev-action-id")
    func parsesPrevActionId() throws {
        let cmd = try GovernanceMainCommand.NoConfidence.parse([
            "--prev-action-id", "gov_action1xyz"
        ])
        #expect(cmd.prevActionId == "gov_action1xyz")
    }
}

@Suite("GovernanceMainCommand.HardForkInitiation")
struct HardForkInitiationTests {

    @Test("parses --protocol-version")
    func parsesProtocolVersion() throws {
        let cmd = try GovernanceMainCommand.HardForkInitiation.parse([
            "--protocol-version", "10.0"
        ])
        #expect(cmd.protocolVersion == "10.0")
    }
}

@Suite("GovernanceMainCommand.TreasuryWithdrawal")
struct TreasuryWithdrawalTests {

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

@Suite("GovernanceMainCommand.Vote")
struct GovernanceVoteTests {

    @Test("parses positional govActionId and yes/no/abstain choices")
    func parsesPositionals() throws {
        for choice in ["yes", "no", "abstain"] {
            let cmd = try GovernanceMainCommand.Vote.parse(["gov_action1xyz", choice])
            #expect(cmd.govActionId == "gov_action1xyz")
            #expect(cmd.choice != nil)
        }
    }
}

@Suite("GovernanceMainCommand.Canonize")
struct CanonizeTests {

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

@Suite("GovernanceMainCommand.CIP129Command")
struct CIP129EncodeDecodeTests {

    @Test("encode parses --prefix and --key-hash")
    func encodeParsesPrefixAndKeyHash() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Encode.parse([
            "--prefix", "drep",
            "--key-hash", String(repeating: "a", count: 56)
        ])
        #expect(cmd.prefix == "drep")
        #expect(cmd.keyHash == String(repeating: "a", count: 56))
    }

    @Test("encode parses --script flag")
    func encodeParsesScriptFlag() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Encode.parse(["--script"])
        #expect(cmd.script == true)
    }

    @Test("decode parses --id")
    func decodeParsesId() throws {
        let cmd = try GovernanceMainCommand.CIP129Command.Decode.parse(["--id", "drep1ygx"])
        #expect(cmd.id == "drep1ygx")
    }
}
