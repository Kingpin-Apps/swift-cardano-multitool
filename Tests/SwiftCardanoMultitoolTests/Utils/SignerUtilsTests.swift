import Foundation
import Testing
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoCIPs
import SwiftCardanoSigner
@testable import SwiftCardanoMultitool

@Suite("SignerUtils")
struct SignerUtilsTests {

    // MARK: - SignerOutputFormat

    @Test("SignerOutputFormat raw values match cardano-signer flags")
    func formatRawValues() {
        #expect(SignerOutputFormat.plain.rawValue == "plain")
        #expect(SignerOutputFormat.json.rawValue == "json")
        #expect(SignerOutputFormat.jsonExtended.rawValue == "json-extended")
    }

    // MARK: - SignerOutputOptions.format

    @Test("SignerOutputOptions.format defaults to .plain")
    func defaultFormatPlain() throws {
        let opts = try SignerOutputOptions.parse([])
        #expect(opts.format == .plain)
    }

    @Test("--json sets format to .json")
    func jsonFlag() throws {
        let opts = try SignerOutputOptions.parse(["--json"])
        #expect(opts.format == .json)
    }

    @Test("--json-extended takes precedence over --json")
    func jsonExtendedWins() throws {
        let opts = try SignerOutputOptions.parse(["--json", "--json-extended"])
        #expect(opts.format == .jsonExtended)
    }

    // MARK: - resolveData

    @Test("resolveData with text returns UTF-8 bytes")
    func resolveDataText() throws {
        let data = try SignerUtils.resolveData(text: "hello", hex: nil, file: nil)
        #expect(data == Data("hello".utf8))
    }

    @Test("resolveData with hex decodes the hex string")
    func resolveDataHex() throws {
        let data = try SignerUtils.resolveData(text: nil, hex: "48656c6c6f", file: nil)
        #expect(data == Data("Hello".utf8))
    }

    @Test("resolveData throws when no input is provided")
    func resolveDataNone() {
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveData(text: nil, hex: nil, file: nil)
        }
    }

    @Test("resolveData throws when more than one input is provided")
    func resolveDataMultiple() {
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveData(text: "hi", hex: "deadbeef", file: nil)
        }
    }

    @Test("resolveData throws on invalid hex")
    func resolveDataInvalidHex() {
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveData(text: nil, hex: "not-hex!!", file: nil)
        }
    }

    @Test("resolveData throws when file is missing")
    func resolveDataMissingFile() {
        let nonExistent = FilePath("/tmp/scm-signerutils-missing-\(UUID().uuidString)")
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveData(text: nil, hex: nil, file: nonExistent)
        }
    }

    @Test("resolveData reads from an existing file")
    func resolveDataReadsFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-signerutils-\(UUID().uuidString).bin")
        let payload = Data([0x01, 0x02, 0x03, 0xff])
        try payload.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try SignerUtils.resolveData(text: nil, hex: nil, file: FilePath(url.path))
        #expect(data == payload)
    }

    // MARK: - resolveSignature

    @Test("resolveSignature decodes hex")
    func resolveSignatureHex() throws {
        let sig = try SignerUtils.resolveSignature("deadbeef")
        #expect(sig == Data([0xde, 0xad, 0xbe, 0xef]))
    }

    @Test("resolveSignature rejects invalid hex")
    func resolveSignatureInvalid() {
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveSignature("XYZ")
        }
    }

    // MARK: - currentMainnetSlotNonce

    @Test("currentMainnetSlotNonce returns a positive slot number")
    func slotNonceIsPositive() {
        let nonce = SignerUtils.currentMainnetSlotNonce()
        #expect(nonce > 0)
    }

    // MARK: - jsonString

    @Test("jsonString produces valid sorted JSON")
    func jsonStringSortsKeys() throws {
        let s = try SignerUtils.jsonString(["b": "2", "a": "1"])
        // sortedKeys => 'a' must appear before 'b'
        let aIndex = s.range(of: "\"a\"")?.lowerBound
        let bIndex = s.range(of: "\"b\"")?.lowerBound
        #expect(aIndex != nil && bIndex != nil)
        #expect(aIndex! < bIndex!)
    }

    @Test("jsonString round-trips to a dictionary")
    func jsonStringRoundTrip() throws {
        let original: [String: String] = ["one": "1", "two": "2"]
        let s = try SignerUtils.jsonString(original)
        let data = Data(s.utf8)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(decoded == original)
    }

    // MARK: - renderDefaultVerify

    @Test("renderDefaultVerify plain emits 'true' or 'false'")
    func verifyPlain() throws {
        // .plain doesn't use the verificationKey at all, so any non-throwing path works.
        let key = try VerificationKeyType.verificationKey(VerificationKey(payload: Data(repeating: 0xab, count: 32)))
        let yes = try SignerUtils.renderDefaultVerify(valid: true, payload: Data(), signature: Data(), verificationKey: key, format: .plain)
        let no = try SignerUtils.renderDefaultVerify(valid: false, payload: Data(), signature: Data(), verificationKey: key, format: .plain)
        #expect(yes == "true")
        #expect(no == "false")
    }

    @Test("renderDefaultVerify .json contains a 'result' field")
    func verifyJson() throws {
        let key = try VerificationKeyType.verificationKey(VerificationKey(payload: Data(repeating: 0xab, count: 32)))
        let rendered = try SignerUtils.renderDefaultVerify(valid: true, payload: Data(), signature: Data(), verificationKey: key, format: .json)
        #expect(rendered.contains("\"result\""))
        #expect(rendered.contains("\"true\""))
    }

    @Test("renderDefaultVerify .jsonExtended includes workMode + hex payload")
    func verifyJsonExtended() throws {
        let key = try VerificationKeyType.verificationKey(VerificationKey(payload: Data(repeating: 0xcd, count: 32)))
        let payload = Data([0x01, 0x02])
        let sig = Data([0xff, 0xee])
        let rendered = try SignerUtils.renderDefaultVerify(
            valid: false,
            payload: payload,
            signature: sig,
            verificationKey: key,
            format: .jsonExtended
        )
        #expect(rendered.contains("\"workMode\""))
        #expect(rendered.contains("\"verify\""))
        #expect(rendered.contains("\"verifyDataHex\""))
        #expect(rendered.contains("0102"))
        #expect(rendered.contains("ffee"))
    }

    // MARK: - SignerDataSource

    @Test("SignerDataSource.description returns rawValue")
    func dataSourceDescriptionEqualsRawValue() {
        for source in SignerDataSource.allCases {
            #expect(source.description == source.rawValue)
        }
    }
}

// MARK: - resolveSecretKey

@Suite("SignerUtils.resolveSecretKey")
struct SignerUtilsResolveSecretKeyTests {

    @Test("32-byte hex yields a non-extended SigningKey")
    func resolveStandardKey() throws {
        let hex = Data(repeating: 0xab, count: 32).toHex
        let result = try SignerUtils.resolveSecretKey(hex)
        guard case .signingKey = result else {
            Issue.record("expected .signingKey, got \(result)")
            return
        }
    }

    @Test("64-byte hex yields an extended signing key")
    func resolveExtendedKey() throws {
        let hex = Data(repeating: 0xab, count: 64).toHex
        let result = try SignerUtils.resolveSecretKey(hex)
        guard case .extendedSigningKey = result else {
            Issue.record("expected .extendedSigningKey, got \(result)")
            return
        }
    }

    @Test("non-hex non-file input throws")
    func resolveBadInput() {
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveSecretKey("not-a-key")
        }
    }
}

// MARK: - resolvePublicKey

@Suite("SignerUtils.resolvePublicKey")
struct SignerUtilsResolvePublicKeyTests {

    @Test("32-byte hex yields a non-extended VerificationKey")
    func resolveStandard() throws {
        let hex = Data(repeating: 0xab, count: 32).toHex
        let result = try SignerUtils.resolvePublicKey(hex)
        guard case .verificationKey = result else {
            Issue.record("expected .verificationKey, got \(result)")
            return
        }
    }

    @Test("64-byte hex yields an extended verification key")
    func resolveExtended() throws {
        let hex = Data(repeating: 0xab, count: 64).toHex
        let result = try SignerUtils.resolvePublicKey(hex)
        guard case .extendedVerificationKey = result else {
            Issue.record("expected .extendedVerificationKey, got \(result)")
            return
        }
    }

    @Test("hex of an unsupported byte length is rejected")
    func resolveOddLength() {
        let hex = Data(repeating: 0xab, count: 16).toHex // 16 bytes — neither 32 nor 64
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolvePublicKey(hex)
        }
    }

    @Test("non-hex non-file input throws")
    func resolveBadInput() {
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolvePublicKey("not-a-key")
        }
    }
}

// MARK: - resolveRawKey

@Suite("SignerUtils.resolveRawKey")
struct SignerUtilsResolveRawKeyTests {

    @Test("hex input returns the raw bytes")
    func hexReturnsRaw() throws {
        let data = try SignerUtils.resolveRawKey("deadbeef")
        #expect(data == Data([0xde, 0xad, 0xbe, 0xef]))
    }

    @Test("non-hex non-file input throws")
    func badInputThrows() {
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveRawKey("zzgg")
        }
    }
}

// MARK: - resolveAddress

@Suite("SignerUtils.resolveAddress")
struct SignerUtilsResolveAddressTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-su-addr-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("file-path branch reads the contents and forwards to Address parser (rejects bad address)")
    func filePathRejectsBadAddress() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("bad.addr")
        try Data("not-a-real-address\n".utf8).write(to: url)
        // The file-path branch is exercised; the address parse then throws.
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveAddress(url.path)
        }
    }

    @Test("rejects garbage input that is neither file nor bech32")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try SignerUtils.resolveAddress("not-an-address")
        }
    }
}

// MARK: - renderDefaultSign

@Suite("SignerUtils.renderDefaultSign")
struct SignerUtilsRenderDefaultSignTests {

    private func sampleSignatureResult() -> SignatureResult {
        SignatureResult(
            signature: Data(repeating: 0xab, count: 64),
            publicKey: Data(repeating: 0xcd, count: 32)
        )
    }

    private func sampleSigningKey() throws -> SigningKeyType {
        .signingKey(try SigningKey(payload: Data(repeating: 0xef, count: 32)))
    }

    @Test("plain format emits 'signatureHex publicKeyHex' separated by a space")
    func plainFormat() throws {
        let result = sampleSignatureResult()
        let key = try sampleSigningKey()
        let rendered = try SignerUtils.renderDefaultSign(
            result, payload: Data(),
            signingKey: key, format: .plain,
            includeSecret: false
        )
        let parts = rendered.split(separator: " ")
        #expect(parts.count == 2)
        #expect(parts[0] == Data(repeating: 0xab, count: 64).toHex[...])
        #expect(parts[1] == Data(repeating: 0xcd, count: 32).toHex[...])
    }

    @Test("plain format appends extras after publicKey")
    func plainWithExtras() throws {
        let result = sampleSignatureResult()
        let key = try sampleSigningKey()
        let rendered = try SignerUtils.renderDefaultSign(
            result, payload: Data(),
            signingKey: key, format: .plain,
            includeSecret: false,
            extras: [(key: "calidusId", value: "calidus1abc")]
        )
        #expect(rendered.hasSuffix("calidus1abc"))
    }

    @Test("json format emits signature + publicKey keys")
    func jsonFormat() throws {
        let result = sampleSignatureResult()
        let key = try sampleSigningKey()
        let rendered = try SignerUtils.renderDefaultSign(
            result, payload: Data(),
            signingKey: key, format: .json,
            includeSecret: false
        )
        #expect(rendered.contains("\"signature\""))
        #expect(rendered.contains("\"publicKey\""))
        #expect(rendered.contains("\"secretKey\"") == false)
    }

    @Test("json format includes secretKey when includeSecret is true")
    func jsonIncludesSecret() throws {
        let result = sampleSignatureResult()
        let key = try sampleSigningKey()
        let rendered = try SignerUtils.renderDefaultSign(
            result, payload: Data(),
            signingKey: key, format: .json,
            includeSecret: true
        )
        #expect(rendered.contains("\"secretKey\""))
    }

    @Test("jsonExtended format adds workMode and signDataHex")
    func jsonExtendedFormat() throws {
        let result = sampleSignatureResult()
        let key = try sampleSigningKey()
        let rendered = try SignerUtils.renderDefaultSign(
            result, payload: Data([0x01, 0x02]),
            signingKey: key, format: .jsonExtended,
            includeSecret: false
        )
        #expect(rendered.contains("\"workMode\""))
        #expect(rendered.contains("\"signDataHex\""))
        #expect(rendered.contains("0102"))
    }
}

// MARK: - renderSignedMessage

@Suite("SignerUtils.renderSignedMessage")
struct SignerUtilsRenderSignedMessageTests {

    @Test("plain format with no key returns just the signature string")
    func plainNoKey() throws {
        let signed = SignedMessage(signature: "abcd", key: nil)
        let rendered = try SignerUtils.renderSignedMessage(
            signed, workMode: "sign-cip8",
            payload: Data(), format: .plain
        )
        #expect(rendered == "abcd")
    }

    @Test("plain format with key returns 'signature key' separated by space")
    func plainWithKey() throws {
        let signed = SignedMessage(signature: "abcd", key: "1234")
        let rendered = try SignerUtils.renderSignedMessage(
            signed, workMode: "sign-cip30",
            payload: Data(), format: .plain
        )
        #expect(rendered == "abcd 1234")
    }

    @Test("json format includes signature and key but not workMode/signDataHex")
    func jsonFormat() throws {
        let signed = SignedMessage(signature: "abcd", key: "1234")
        let rendered = try SignerUtils.renderSignedMessage(
            signed, workMode: "sign-cip8",
            payload: Data([0x07]), format: .json
        )
        #expect(rendered.contains("\"signature\""))
        #expect(rendered.contains("\"key\""))
        #expect(rendered.contains("\"workMode\"") == false)
        #expect(rendered.contains("\"signDataHex\"") == false)
    }

    @Test("jsonExtended format adds workMode and signDataHex")
    func jsonExtendedFormat() throws {
        let signed = SignedMessage(signature: "abcd", key: nil)
        let rendered = try SignerUtils.renderSignedMessage(
            signed, workMode: "sign-cip30",
            payload: Data([0x07]), format: .jsonExtended
        )
        #expect(rendered.contains("\"workMode\""))
        #expect(rendered.contains("\"signDataHex\""))
        #expect(rendered.contains("\"sign-cip30\""))
    }
}
