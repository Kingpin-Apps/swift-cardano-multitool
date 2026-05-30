import ArgumentParser
import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

/// Minimal test stub that conforms to `TransactionSendable` so we can exercise the
/// protocol extension's `validateForTransaction()` logic in isolation.
private struct TestSender: TransactionSendable {
    @OptionGroup var transactionOptions: SharedTransactionOptions
    func run() async throws {}
}

@Suite("TransactionSendable.validateForTransaction")
struct TransactionSendableValidateTests {

    private func makeSender() throws -> TestSender {
        try TestSender.parse([])
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Defaults

    @Test("default options pass validation")
    func defaultsPass() throws {
        var sender = try makeSender()
        try sender.validateForTransaction()
    }

    // MARK: - Messages

    @Test("accepts a message at exactly 64 UTF-8 bytes")
    func acceptsMessageAt64Bytes() throws {
        var sender = try makeSender()
        sender.transactionOptions.messages = [String(repeating: "a", count: 64)]
        try sender.validateForTransaction()
    }

    @Test("rejects a message exceeding 64 UTF-8 bytes")
    func rejectsLongMessage() throws {
        var sender = try makeSender()
        sender.transactionOptions.messages = [String(repeating: "a", count: 65)]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    @Test("counts UTF-8 bytes, not Swift Character count, for the 64-byte limit")
    func countsUtf8Bytes() throws {
        // "é" is 2 UTF-8 bytes; 33 of them = 66 bytes (over the limit) but only 33 characters.
        var sender = try makeSender()
        sender.transactionOptions.messages = [String(repeating: "é", count: 33)]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    // MARK: - Metadata files

    @Test("accepts a metadata JSON path that exists on disk")
    func acceptsExistingJsonMetadata() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("meta.json")
        try Data("{}".utf8).write(to: url)
        var sender = try makeSender()
        sender.transactionOptions.metadataJson = [FilePath(url.path)]
        try sender.validateForTransaction()
    }

    @Test("rejects a missing metadata JSON path")
    func rejectsMissingJsonMetadata() throws {
        var sender = try makeSender()
        sender.transactionOptions.metadataJson = [FilePath("/no/such/file.json")]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    @Test("rejects a missing metadata CBOR path")
    func rejectsMissingCborMetadata() throws {
        var sender = try makeSender()
        sender.transactionOptions.metadataCbor = [FilePath("/no/such/file.cbor")]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    // MARK: - UTXO filter format

    @Test("accepts a UTXO filter in txHash#index format")
    func acceptsValidUtxoFilter() throws {
        var sender = try makeSender()
        sender.transactionOptions.utxoFilter = [
            String(repeating: "a", count: 64) + "#0",
            String(repeating: "F", count: 64) + "#42"
        ]
        try sender.validateForTransaction()
    }

    @Test("rejects a UTXO filter missing the # separator")
    func rejectsUtxoFilterNoHash() throws {
        var sender = try makeSender()
        sender.transactionOptions.utxoFilter = [String(repeating: "a", count: 64)]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    @Test("rejects a UTXO filter with a short txHash")
    func rejectsShortTxHash() throws {
        var sender = try makeSender()
        sender.transactionOptions.utxoFilter = [String(repeating: "a", count: 63) + "#0"]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    @Test("rejects a UTXO filter whose index is not numeric")
    func rejectsNonNumericIndex() throws {
        var sender = try makeSender()
        sender.transactionOptions.utxoFilter = [String(repeating: "a", count: 64) + "#x"]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    // MARK: - UTXO limit

    @Test("accepts a positive utxoLimit")
    func acceptsPositiveLimit() throws {
        var sender = try makeSender()
        sender.transactionOptions.utxoLimit = 5
        try sender.validateForTransaction()
    }

    @Test("rejects a non-positive utxoLimit")
    func rejectsNonPositiveLimit() throws {
        var sender = try makeSender()
        sender.transactionOptions.utxoLimit = 0
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
        sender.transactionOptions.utxoLimit = -1
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    // MARK: - Asset filter format

    @Test("accepts an asset filter in policyId+assetNameHex format")
    func acceptsValidAssetFilter() throws {
        let asset = String(repeating: "a", count: 56) + "+" + String(repeating: "f", count: 8)
        var sender = try makeSender()
        sender.transactionOptions.skipUtxoWithAsset = [asset]
        sender.transactionOptions.onlyUtxoWithAsset = [asset]
        try sender.validateForTransaction()
    }

    @Test("rejects an asset filter with a short policyId")
    func rejectsShortPolicyId() throws {
        let asset = String(repeating: "a", count: 55) + "+ff"
        var sender = try makeSender()
        sender.transactionOptions.skipUtxoWithAsset = [asset]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    @Test("rejects an asset filter missing the + separator")
    func rejectsAssetFilterNoSeparator() throws {
        let asset = String(repeating: "a", count: 56) + String(repeating: "f", count: 8)
        var sender = try makeSender()
        sender.transactionOptions.onlyUtxoWithAsset = [asset]
        #expect(throws: ValidationError.self) {
            try sender.validateForTransaction()
        }
    }

    // MARK: - isSame

    @Test("isSame is true when both addresses are nil")
    func isSameWithBothNil() throws {
        let sender = try makeSender()
        #expect(sender.isSame == true)
    }
}
