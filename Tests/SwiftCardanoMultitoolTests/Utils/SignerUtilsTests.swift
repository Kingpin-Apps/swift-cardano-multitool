import Foundation
import Testing
import SystemPackage
import SwiftCardanoCore
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
