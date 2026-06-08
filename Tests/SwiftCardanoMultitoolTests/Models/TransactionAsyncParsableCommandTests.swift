import Foundation
import Testing
import ArgumentParser
import SystemPackage
@testable import SwiftCardanoMultitool

@Suite("TransactionAsyncParsableCommand")
struct TransactionAsyncParsableCommandTests {

    /// Minimal in-test conformer used to exercise the protocol's default helpers.
    private struct ProbeCommand: TransactionAsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "probe")
        @Option(name: .long) var txFile: FilePath?
        @Option(name: .long) var cborHex: String?
        mutating func run() async throws {}
    }

    @Test("resolveCborHex returns the literal --cbor-hex value when set")
    func resolveCborHexReturnsCbor() throws {
        let cmd = try ProbeCommand.parse(["--cbor-hex", "deadbeef"])
        #expect(try cmd.resolveCborHex() == "deadbeef")
    }

    @Test("resolveCborHex prefers --cbor-hex over --tx-file when both are set")
    func resolveCborHexPrefersCbor() throws {
        let cmd = try ProbeCommand.parse([
            "--cbor-hex", "abcd",
            "--tx-file", "/tmp/does-not-exist.tx"
        ])
        // Even though the file is missing, cborHex wins so this still succeeds.
        #expect(try cmd.resolveCborHex() == "abcd")
    }

    @Test("resolveCborHex throws when both inputs are nil")
    func resolveCborHexThrowsWhenEmpty() throws {
        let cmd = try ProbeCommand.parse([])
        #expect(throws: (any Error).self) {
            _ = try cmd.resolveCborHex()
        }
    }

    @Test("resolveCborHex throws when only the file is given but doesn't exist")
    func resolveCborHexThrowsForMissingFile() throws {
        let cmd = try ProbeCommand.parse(["--tx-file", "/tmp/scm-tap-missing-\(UUID().uuidString).tx"])
        #expect(throws: (any Error).self) {
            _ = try cmd.resolveCborHex()
        }
    }

    @Test("resolveTransaction throws on invalid cborHex")
    func resolveTransactionRejectsInvalidCbor() throws {
        let cmd = try ProbeCommand.parse(["--cbor-hex", "deadbeef"])
        #expect(throws: (any Error).self) {
            _ = try cmd.resolveTransaction()
        }
    }

    @Test("resolveTransaction throws when both inputs are nil")
    func resolveTransactionThrowsWhenEmpty() throws {
        let cmd = try ProbeCommand.parse([])
        #expect(throws: (any Error).self) {
            _ = try cmd.resolveTransaction()
        }
    }
}
