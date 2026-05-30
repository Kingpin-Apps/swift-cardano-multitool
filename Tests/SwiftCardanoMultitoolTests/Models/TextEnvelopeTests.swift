import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("TextEnvelope computed properties")
struct TextEnvelopeComputedTests {

    @Test("isHardwareKey is true when description mentions ledger")
    func isHardwareKeyLedger() {
        let env = TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Hardware Ledger Wallet Signing Key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.isHardwareKey == true)
    }

    @Test("isHardwareKey is true when description mentions trezor (case insensitive)")
    func isHardwareKeyTrezor() {
        let env = TextEnvelope(
            type: nil,
            description: "TREZOR signing key",
            cborHex: "",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.isHardwareKey == true)
    }

    @Test("isHardwareKey is false for a plain CLI description")
    func isHardwareKeyFalseForCLI() {
        let env = TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Payment Signing Key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.isHardwareKey == false)
    }

    @Test("isHardwareKey is false when description is nil")
    func isHardwareKeyFalseForNil() {
        let env = TextEnvelope(
            type: nil,
            description: nil,
            cborHex: nil,
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.isHardwareKey == false)
    }

    @Test("keyGenType reports .hw when hardware-flavoured")
    func keyGenHardware() {
        let env = TextEnvelope(
            type: nil,
            description: "Ledger signing key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.keyGenType == .hw)
    }

    @Test("keyGenType reports .enc when encrHex is set and not hardware")
    func keyGenEncrypted() {
        let env = TextEnvelope(
            type: nil,
            description: "Encrypted Payment Signing Key",
            cborHex: nil,
            encrHex: "deadbeef",
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.keyGenType == .enc)
    }

    @Test("keyGenType defaults to .cli")
    func keyGenCLI() {
        let env = TextEnvelope(
            type: nil,
            description: "Payment Signing Key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.keyGenType == .cli)
    }

    @Test("isEncrypted requires both encrHex and an Encrypted description")
    func isEncryptedRequiresBoth() {
        // Both present
        let both = TextEnvelope(
            type: nil,
            description: "Encrypted Payment Signing Key",
            cborHex: nil,
            encrHex: "deadbeef",
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(both.isEncrypted == true)

        // encrHex without Encrypted in description
        let onlyEncr = TextEnvelope(
            type: nil,
            description: "Payment Signing Key",
            cborHex: nil,
            encrHex: "deadbeef",
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(onlyEncr.isEncrypted == false)

        // Encrypted description but no encrHex
        let onlyDesc = TextEnvelope(
            type: nil,
            description: "Encrypted Payment Signing Key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(onlyDesc.isEncrypted == false)
    }
}
