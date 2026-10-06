import ArgumentParser
import SystemPackage
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

@Suite("TransactionMainCommand.Witness — witness files")
struct TransactionWitnessFilesTests {
    private let cwd = FilePath("/work")

    @Test("defaults to <transaction-name>.<key-role>.witness in the current directory")
    func defaultNames() {
        let files = TransactionMainCommand.Witness.witnessFiles(
            for: [FilePath("/keys/owner.payment.skey"), FilePath("owner.stake.skey"), FilePath("qwe1.node.hwsfile")],
            outFiles: [],
            transactionName: "qwe1-stake-reg-deleg",
            cwd: cwd
        )
        #expect(files.map(\.string) == [
            "/work/qwe1-stake-reg-deleg.payment.witness",
            "/work/qwe1-stake-reg-deleg.stake.witness",
            "/work/qwe1-stake-reg-deleg.node.witness",
        ])
    }

    @Test("keys sharing a role fall back to their full key name")
    func sharedRole() {
        let files = TransactionMainCommand.Witness.witnessFiles(
            for: [FilePath("alice.payment.skey"), FilePath("bob.payment.skey"), FilePath("bob.stake.skey")],
            outFiles: [],
            transactionName: "tx1",
            cwd: cwd
        )
        #expect(files.map(\.string) == ["/work/tx1.alice.payment.witness", "/work/tx1.bob.payment.witness", "/work/tx1.stake.witness"])
    }

    @Test("--out-file is used for the matching signing key, relative to the current directory")
    func outFilesInOrder() {
        let files = TransactionMainCommand.Witness.witnessFiles(
            for: [FilePath("a.skey"), FilePath("b.skey")],
            outFiles: [FilePath("out/first.witness"), FilePath("/abs/second.witness")],
            transactionName: "tx1",
            cwd: cwd
        )
        #expect(files.map(\.string) == ["/work/out/first.witness", "/abs/second.witness"])
    }

    @Test("one --out-file per signing key is required when any are given")
    func outFileCountMustMatch() throws {
        #expect(throws: (any Error).self) {
            _ = try TransactionMainCommand.Witness.parse([
                "--signing-keys", "a.skey", "--signing-keys", "b.skey", "--out-file", "a.witness"
            ])
        }
        let cmd = try TransactionMainCommand.Witness.parse([
            "--signing-keys", "a.skey", "--signing-keys", "b.skey",
            "--out-file", "a.witness", "--out-file", "b.witness"
        ])
        #expect(cmd.outFile.map(\.string) == ["a.witness", "b.witness"])
    }

    @Test("paths inside the current directory are shown relative to it")
    func displayPath() {
        #expect(TransactionMainCommand.Witness.displayPath(FilePath("/work/out/a.witness"), cwd: cwd) == "out/a.witness")
        #expect(TransactionMainCommand.Witness.displayPath(FilePath("/elsewhere/a.witness"), cwd: cwd) == "/elsewhere/a.witness")
    }
}

@Suite("Transaction file naming")
struct TransactionFileNamingTests {
    @Test("transaction base name drops the transaction suffix", arguments: [
        ("qwe1-stake-reg-deleg.unwitnessed.tx", "qwe1-stake-reg-deleg"),
        ("/tmp/qwe1.signed.tx", "qwe1"),
        ("owner-2026-10-06-120000.raw.tx", "owner-2026-10-06-120000"),
        ("vote.tx", "vote"),
        ("tx.body", "tx.body"),
    ])
    func baseName(input: String, expected: String) {
        #expect(transactionBaseName(FilePath(input)) == expected)
    }

    @Test("signing key role is the last part of the key name", arguments: [
        ("qwe1.node.skey", "node"),
        ("/keys/owner.payment.hwsfile", "payment"),
        ("owner.stake.skey", "stake"),
        ("payment.skey", "payment"),
        ("mydrep.drep.skey", "drep"),
    ])
    func role(input: String, expected: String) {
        #expect(signingKeyRole(FilePath(input)) == expected)
    }
}
