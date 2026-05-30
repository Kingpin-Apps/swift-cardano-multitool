import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("TransactionMessage.buildMetadata")
struct TransactionMessageBuildMetadataTests {

    // MARK: - Empty input

    @Test("returns nil for an empty message array (plaintext mode)")
    func emptyPlain() throws {
        #expect(try TransactionMessage.buildMetadata(messages: []) == nil)
    }

    @Test("returns nil for an empty message array (encrypted mode)")
    func emptyEncrypted() throws {
        #expect(
            try TransactionMessage.buildMetadata(
                messages: [],
                encryption: .basic,
                passphrase: "secret"
            ) == nil
        )
    }

    // MARK: - Plaintext mode

    @Test("plaintext mode emits metadata under the 674 label with a msg array")
    func plainMetadataShape() throws {
        let json = try TransactionMessage.buildMetadata(
            messages: ["hello", "world"],
            encryption: .none
        )
        let obj = try jsonObject(json)
        let label = try #require(obj["674"] as? [String: Any])
        let msg = try #require(label["msg"] as? [String])
        #expect(msg == ["hello", "world"])
        #expect(label["enc"] == nil)
    }

    @Test("plaintext mode is deterministic for the same input")
    func plainDeterministic() throws {
        let a = try TransactionMessage.buildMetadata(messages: ["hi"], encryption: .none)
        let b = try TransactionMessage.buildMetadata(messages: ["hi"], encryption: .none)
        #expect(a == b)
    }

    // MARK: - Encrypted mode

    @Test("encrypted mode emits enc=basic and a base64 msg array")
    func encryptedShape() throws {
        let json = try TransactionMessage.buildMetadata(
            messages: ["confidential"],
            encryption: .basic,
            passphrase: "test-pass"
        )
        let obj = try jsonObject(json)
        let label = try #require(obj["674"] as? [String: Any])
        #expect(label["enc"] as? String == "basic")
        let msg = try #require(label["msg"] as? [String])
        #expect(!msg.isEmpty)
    }

    @Test("encrypted chunks are each at most 64 characters")
    func encryptedChunkSize() throws {
        // Use a longer payload to guarantee multiple chunks.
        let big = String(repeating: "lorem ipsum dolor ", count: 30)
        let json = try TransactionMessage.buildMetadata(
            messages: [big],
            encryption: .basic,
            passphrase: "test-pass"
        )
        let obj = try jsonObject(json)
        let label = try #require(obj["674"] as? [String: Any])
        let msg = try #require(label["msg"] as? [String])
        #expect(msg.count > 1)
        for chunk in msg {
            #expect(chunk.count <= 64)
        }
    }

    @Test("encrypted output begins with the OpenSSL Salted__ marker (base64 U2Fsd)")
    func encryptedSaltedPrefix() throws {
        // The combined base64 starts with the base64 encoding of "Salted__" + 8 salt bytes.
        // Regardless of the salt, the first 4 characters are always "U2Fsd" (base64 of "Salt").
        let json = try TransactionMessage.buildMetadata(
            messages: ["payload"],
            encryption: .basic,
            passphrase: "test-pass"
        )
        let obj = try jsonObject(json)
        let label = try #require(obj["674"] as? [String: Any])
        let msg = try #require(label["msg"] as? [String])
        let first = try #require(msg.first)
        #expect(first.hasPrefix("U2Fsd"))
    }

    @Test("encrypted output differs across calls because of the random salt")
    func encryptedRandomness() throws {
        let a = try TransactionMessage.buildMetadata(
            messages: ["same"],
            encryption: .basic,
            passphrase: "pass"
        )
        let b = try TransactionMessage.buildMetadata(
            messages: ["same"],
            encryption: .basic,
            passphrase: "pass"
        )
        #expect(a != b)
    }

    // MARK: - Helpers

    private func jsonObject(_ json: String?) throws -> [String: Any] {
        let unwrapped = try #require(json)
        let data = try #require(unwrapped.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data)
        return try #require(obj as? [String: Any])
    }
}

@Suite("TransactionMessage.buildAuxiliaryData")
struct TransactionMessageBuildAuxiliaryDataTests {

    @Test("returns nil when no messages and no metadata files are supplied")
    func nilWhenNoInputs() throws {
        let result = try TransactionMessage.buildAuxiliaryData(
            messages: nil,
            encryption: .none,
            passphrase: "x",
            metadataJson: nil,
            metadataCbor: nil
        )
        #expect(result == nil)
    }

    @Test("returns auxiliary data for plain-text messages")
    func nonNilForPlainMessages() throws {
        let result = try TransactionMessage.buildAuxiliaryData(
            messages: ["hello"],
            encryption: .none
        )
        #expect(result != nil)
    }

    @Test("returns auxiliary data for encrypted messages")
    func nonNilForEncryptedMessages() throws {
        let result = try TransactionMessage.buildAuxiliaryData(
            messages: ["confidential"],
            encryption: .basic,
            passphrase: "passphrase"
        )
        #expect(result != nil)
    }
}

@Suite("TransactionMessageError")
struct TransactionMessageErrorTests {

    @Test("jsonEncodingFailed has descriptive message")
    func jsonEncodingFailed() {
        #expect(TransactionMessageError.jsonEncodingFailed.errorDescription == "Failed to encode metadata as JSON")
    }

    @Test("keyDerivationFailed includes the OS status")
    func keyDerivationFailed() {
        #expect(TransactionMessageError.keyDerivationFailed(-42).errorDescription == "Key derivation failed with status: -42")
    }

    @Test("encryptionFailed includes the OS status")
    func encryptionFailed() {
        #expect(TransactionMessageError.encryptionFailed(7).errorDescription == "Encryption failed with status: 7")
    }

    @Test("encryptionNotSupported has descriptive message")
    func encryptionNotSupported() {
        #expect(TransactionMessageError.encryptionNotSupported.errorDescription == "AES-CBC encryption is not supported on this platform")
    }
}
