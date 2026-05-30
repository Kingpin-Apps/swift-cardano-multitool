import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Argument-parsing smoke tests for all TransactionMainCommand subcommands.
///
/// Full behavior tests for these commands need a valid Cardano `Transaction` CBOR
/// to be constructed, which is a substantial fixture investment. These tests verify
/// the command shape and that each documented argument is accepted.

@Suite("TransactionMainCommand.Id")
struct TransactionIdTests {
    @Test("commandName is 'id'")
    func commandName() {
        #expect(TransactionMainCommand.Id.configuration.commandName == "id")
    }
    @Test("parses with tx-file")
    func parsesTxFile() throws {
        let cmd = try TransactionMainCommand.Id.parse(["--tx-file", "/tmp/x.tx"])
        #expect(cmd.txFile?.string == "/tmp/x.tx")
    }
    @Test("parses with cbor-hex and --json flag")
    func parsesCborAndJson() throws {
        let cmd = try TransactionMainCommand.Id.parse(["--cbor-hex", "deadbeef", "--json"])
        #expect(cmd.cborHex == "deadbeef")
        #expect(cmd.json == true)
    }
    @Test("--tool defaults to .swiftCardano")
    func toolDefault() throws {
        let cmd = try TransactionMainCommand.Id.parse([])
        #expect(cmd.tool == .swiftCardano)
    }
}

@Suite("TransactionMainCommand.View")
struct TransactionViewTests {
    @Test("parses defaults")
    func defaults() throws {
        let cmd = try TransactionMainCommand.View.parse([])
        #expect(cmd.txFile == nil)
        #expect(cmd.cborHex == nil)
    }
    @Test("parses tx-file")
    func parsesTxFile() throws {
        let cmd = try TransactionMainCommand.View.parse(["-t", "/tmp/x.tx"])
        #expect(cmd.txFile?.string == "/tmp/x.tx")
    }
}

@Suite("TransactionMainCommand.Inspect")
struct TransactionInspectTests {
    @Test("commandName is 'inspect'")
    func commandName() {
        #expect(TransactionMainCommand.Inspect.configuration.commandName == "inspect")
    }
    @Test("parses defaults")
    func defaults() throws {
        let cmd = try TransactionMainCommand.Inspect.parse([])
        #expect(cmd.txFile == nil)
        #expect(cmd.cborHex == nil)
        #expect(cmd.json == false)
    }
    @Test("parses --json flag")
    func jsonFlag() throws {
        let cmd = try TransactionMainCommand.Inspect.parse(["--json"])
        #expect(cmd.json == true)
    }
}

@Suite("TransactionMainCommand.Validate")
struct TransactionValidateTests {
    @Test("commandName is 'validate'")
    func commandName() {
        #expect(TransactionMainCommand.Validate.configuration.commandName == "validate")
    }
    @Test("parses defaults")
    func defaults() throws {
        let cmd = try TransactionMainCommand.Validate.parse([])
        #expect(cmd.txFile == nil)
        #expect(cmd.cborHex == nil)
        #expect(cmd.json == false)
    }
}

@Suite("TransactionMainCommand.CalculateMinFee")
struct TransactionCalculateMinFeeTests {
    @Test("commandName is 'calculate-min-fee'")
    func commandName() {
        #expect(TransactionMainCommand.CalculateMinFee.configuration.commandName == "calculate-min-fee")
    }
    @Test("parses defaults")
    func defaults() throws {
        let cmd = try TransactionMainCommand.CalculateMinFee.parse([])
        #expect(cmd.txFile == nil)
        #expect(cmd.json == false)
    }
}

@Suite("TransactionMainCommand.CalculateMinRequiredUtxo")
struct TransactionCalculateMinRequiredUtxoTests {
    @Test("commandName is 'calculate-min-required-utxo'")
    func commandName() {
        #expect(TransactionMainCommand.CalculateMinRequiredUtxo.configuration.commandName == "calculate-min-required-utxo")
    }
    @Test("parses defaults")
    func defaults() throws {
        _ = try TransactionMainCommand.CalculateMinRequiredUtxo.parse([])
    }
}

@Suite("TransactionMainCommand.HashScriptData")
struct TransactionHashScriptDataTests {
    @Test("commandName is 'hash-script-data'")
    func commandName() {
        #expect(TransactionMainCommand.HashScriptData.configuration.commandName == "hash-script-data")
    }
    @Test("parses defaults")
    func defaults() throws {
        let cmd = try TransactionMainCommand.HashScriptData.parse([])
        #expect(cmd.json == false)
    }
    @Test("--json flag flips bool")
    func jsonFlag() throws {
        let cmd = try TransactionMainCommand.HashScriptData.parse(["--json"])
        #expect(cmd.json == true)
    }
}

@Suite("TransactionMainCommand.Build")
struct TransactionBuildTests {
    @Test("commandName is 'build'")
    func commandName() {
        #expect(TransactionMainCommand.Build.configuration.commandName == "build")
    }
    @Test("parses with no arguments (wizard would run)")
    func parsesEmpty() throws {
        _ = try TransactionMainCommand.Build.parse([])
    }
    @Test("accepts --tx-in repeated")
    func acceptsTxIn() throws {
        let cmd = try TransactionMainCommand.Build.parse([
            "--tx-in", "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef#0"
        ])
        #expect(!cmd.txIn.isEmpty)
    }
}

@Suite("TransactionMainCommand.Sign")
struct TransactionSignTests {
    @Test("parses --save default true")
    func saveDefault() throws {
        let cmd = try TransactionMainCommand.Sign.parse([])
        #expect(cmd.save == true)
    }
    @Test("--no-save inverts")
    func noSave() throws {
        let cmd = try TransactionMainCommand.Sign.parse(["--no-save"])
        #expect(cmd.save == false)
    }
}

@Suite("TransactionMainCommand.Submit")
struct TransactionSubmitTests {
    @Test("parses defaults")
    func defaults() throws {
        let cmd = try TransactionMainCommand.Submit.parse([])
        #expect(cmd.txFile == nil)
        #expect(cmd.cborHex == nil)
    }
}

@Suite("TransactionMainCommand.Witness")
struct TransactionWitnessCommandTests {
    @Test("--save defaults to true")
    func saveDefault() throws {
        let cmd = try TransactionMainCommand.Witness.parse([])
        #expect(cmd.save == true)
    }
}

@Suite("TransactionMainCommand.Assemble")
struct TransactionAssembleTests {
    @Test("--save defaults to true")
    func saveDefault() throws {
        let cmd = try TransactionMainCommand.Assemble.parse([])
        #expect(cmd.save == true)
    }
    @Test("--submit defaults to false")
    func submitDefault() throws {
        let cmd = try TransactionMainCommand.Assemble.parse([])
        #expect(cmd.submit == false)
    }
}

@Suite("TransactionMainCommand.RewardsWithdraw")
struct TransactionRewardsWithdrawTests {
    @Test("parses with no arguments (wizard would run)")
    func parsesEmpty() throws {
        _ = try TransactionMainCommand.RewardsWithdraw.parse([])
    }
}
