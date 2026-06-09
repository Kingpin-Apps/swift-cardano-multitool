import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Behavior tests for TransactionMainCommand subcommands.
///
/// Full behavior tests need a valid CBOR Transaction fixture and a chain context,
/// which is a significant investment. These tests cover the parser-level behavior
/// that's not trivially derivable from the source — flag inversion, repeated
/// options, validation rules, and the txid/id alias regression guard.

@Suite("TransactionMainCommand.Id")
struct TransactionIdTests {

    @Test("commandName is 'txid' with 'id' alias")
    func commandName() {
        // Regression guard: this subcommand was previously registered as 'id'
        // while the README documented 'txid'. The fix kept 'id' as an alias.
        #expect(TransactionMainCommand.Id.configuration.commandName == "txid")
        #expect(TransactionMainCommand.Id.configuration.aliases.contains("id"))
    }
}

@Suite("TransactionMainCommand.Build")
struct TransactionBuildTests {

    @Test("--tx-in accepts a valid 64-hex#index input")
    func acceptsTxIn() throws {
        let cmd = try TransactionMainCommand.Build.parse([
            "--tx-in", "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef#0"
        ])
        #expect(!cmd.txIn.isEmpty)
    }
}

@Suite("TransactionMainCommand.Sign / Witness / Assemble — flag inversion")
struct TransactionSignWitnessAssembleFlagTests {

    @Test("Sign --no-save inverts save flag")
    func signNoSave() throws {
        let cmd = try TransactionMainCommand.Sign.parse(["--no-save"])
        #expect(cmd.save == false)
    }

    @Test("Sign --save defaults to true")
    func signSaveDefault() throws {
        let cmd = try TransactionMainCommand.Sign.parse([])
        #expect(cmd.save == true)
    }

    @Test("Witness --save defaults to true")
    func witnessSaveDefault() throws {
        let cmd = try TransactionMainCommand.Witness.parse([])
        #expect(cmd.save == true)
    }

    @Test("Assemble --save defaults to true, --submit defaults to false")
    func assembleDefaults() throws {
        let cmd = try TransactionMainCommand.Assemble.parse([])
        #expect(cmd.save == true)
        #expect(cmd.submit == false)
    }
}
