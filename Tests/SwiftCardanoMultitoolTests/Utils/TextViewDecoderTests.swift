import Foundation
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

/// Fixtures were generated with cardano-cli 11.0; the identifiers they are checked
/// against were printed by cardano-cli for the same files.
@Suite("TextViewDecoder")
struct TextViewDecoderTests {

    private let decoder = TextViewDecoder(network: .testnet)

    private func view(_ type: String, _ cborHex: String, decoder: TextViewDecoder? = nil) throws -> TextView {
        let json = #"{"type": "\#(type)", "description": "", "cborHex": "\#(cborHex)"}"#
        return try (decoder ?? self.decoder).view(fileData: Data(json.utf8), source: "test")
    }

    private func string(_ value: DecodedValue?) -> String? {
        if case .string(let text) = value { return text }
        if case .number(let text) = value { return text }
        return nil
    }

    private func object(_ value: DecodedValue?) -> DecodedObject? {
        if case .object(let object) = value { return object }
        return nil
    }

    // MARK: Keys

    @Test("verification keys show the key hash, Bech32 key and address")
    func paymentVerificationKey() throws {
        let view = try view("PaymentVerificationKeyShelley_ed25519", HashUtilsTests.paymentVkeyCbor)
        #expect(view.title == "Payment Verification Key")
        #expect(string(view.decoded["keyHash"]) == HashUtilsTests.paymentKeyHash)
        #expect(string(view.decoded["enterpriseAddress"]) == "addr_test1vqm5nukask500l5r04q24zuuyfeh6xjr2nxj6s4suw50lhsvsjccr")
        #expect(string(object(view.decoded["verificationKey"])?["bech32"]) == "addr_vk1hzejdyf2a25zr5r07n9fy6dklgy87ykqyc3ekcn6nzmwysx26dysqc65ha")
    }

    @Test("signing keys derive the verification key and hide the secret by default")
    func signingKey() throws {
        let cbor = "5820935d711eb12b914685524ae71e5147f30b5bdad8fe8374250aec62e0bbc24d6f"
        let hidden = try view("PaymentSigningKeyShelley_ed25519", cbor)
        #expect(string(hidden.decoded["keyHash"]) == HashUtilsTests.paymentKeyHash)
        #expect(string(hidden.decoded["signingKey"])?.hasPrefix("hidden") == true)
        #expect(!hidden.json().contains("935d711e"))

        let shown = try view("PaymentSigningKeyShelley_ed25519", cbor, decoder: TextViewDecoder(network: .testnet, showSecret: true))
        #expect(string(shown.decoded["signingKeyHex"]) == String(cbor.dropFirst(4)))
    }

    @Test("pool cold keys show the pool ID; DRep keys show both DRep ID formats")
    func identifiers() throws {
        let cold = try view("StakePoolVerificationKey_ed25519", "582035620a4c2085916bcd6b2b30078967f38b1d405627a54d5b8c9f18f182234828")
        #expect(string(cold.decoded["poolId"]) == "pool156j7gneclcxk3u29sqh4afgs428ghda4538t0p27xmf4ylu6zar")

        let drep = try view("DRepVerificationKey_ed25519", "5820d1fa6be9518280be166134bf203a0583eeafa979ad741fa464b12fd4cf305c55")
        #expect(string(drep.decoded["drepId"]) == "drep1yf4ft6r96zm6dt4q6kzgp8jw8zxx4l63uhwr2dsagjkcy8stq32w0")
        #expect(string(drep.decoded["drepIdCip105"]) == "drep1d227sewsk7n2agx4sjqfun3c33407509ms6nv82y4kppujxkm5a")
    }

    @Test("addresses are omitted when no network is configured")
    func noNetwork() throws {
        let view = try view("StakeVerificationKeyShelley_ed25519", "582008ab27cba8005776e26a79f9befb2a411277194a7de1611ae9bc4aa7777b61d0",
                            decoder: TextViewDecoder(network: nil))
        #expect(view.decoded["stakeAddress"] == nil)
        #expect(string(view.decoded["keyHash"]) == "a49e1e4b74224dd10cd8c8798d3a6535f2e5ea3f209790798ab1c3b8")
    }

    // MARK: Certificates and governance

    @Test("pool registration certificates show readable pool parameters")
    func poolRegistration() throws {
        let cbor = "8a03581ca6a5e44f38fe0d68f145802f5ea510aa8e8bb7b5a44eb7855e36d3525820dc80e3aa843557014ba0b9e29c4c51e27bb8a711088c05e15a4d2e7f5110454e18641a0a21fe80d81e82011864581de0a49e1e4b74224dd10cd8c8798d3a6535f2e5ea3f209790798ab1c3b8d9010281581ca49e1e4b74224dd10cd8c8798d3a6535f2e5ea3f209790798ab1c3b8828400190bb94401020304f68301190bba7172656c61792e6578616d706c652e636f6d827368747470733a2f2f782e696f2f702e6a736f6e58200000000000000000000000000000000000000000000000000000000000000000"
        let view = try view("Certificate", cbor)
        #expect(view.title == "Stake Pool Registration Certificate")
        #expect(string(view.decoded["poolId"]) == "pool156j7gneclcxk3u29sqh4afgs428ghda4538t0p27xmf4ylu6zar")
        #expect(string(view.decoded["cost"]) == "170 ADA (170000000 lovelace)")
        #expect(string(view.decoded["margin"]) == "1% (1/100)")
        #expect(string(view.decoded["rewardAccount"]) == "stake_test1uzjfu8jtws3ym5gvmry8nrf6v56l9e028usf0yre32cu8wqgjzhhc")
        #expect(view.decoded["relays"] == .array([.string("1.2.3.4:3001"), .string("relay.example.com:3002")]))
    }

    @Test("vote files list the voter, action and decision")
    func votes() throws {
        let cbor = "a18202581c6a95e865d0b7a6aea0d584809e4e388c6aff51e5dc35361d44ad821ea18258200000000000000000000000000000000000000000000000000000000000000001008201f6"
        let view = try view("Governance voting procedures", cbor)
        guard case .array(let votes) = view.decoded["votes"], let vote = object(votes.first) else {
            Issue.record("expected one vote")
            return
        }
        #expect(string(object(vote["voter"])?["id"]) == "drep1yf4ft6r96zm6dt4q6kzgp8jw8zxx4l63uhwr2dsagjkcy8stq32w0")
        #expect(string(object(vote["governanceAction"])?["transaction"]) == "0000000000000000000000000000000000000000000000000000000000000001#0")
        #expect(string(vote["vote"]) == "Yes")
    }

    @Test("proposals show deposit, return address and action type")
    func proposal() throws {
        let cbor = "841b000000174876e800581de0a49e1e4b74224dd10cd8c8798d3a6535f2e5ea3f209790798ab1c3b88106827368747470733a2f2f782e696f2f612e6a736f6e58200000000000000000000000000000000000000000000000000000000000000000"
        let view = try view("Governance proposal", cbor)
        #expect(string(view.decoded["deposit"]) == "100,000 ADA (100000000000 lovelace)")
        #expect(string(view.decoded["depositReturnAddress"]) == "stake_test1uzjfu8jtws3ym5gvmry8nrf6v56l9e028usf0yre32cu8wqgjzhhc")
        #expect(string(object(view.decoded["action"])?["type"]) == "Info")
    }

    @Test("operational certificates show the KES key, counter, period and pool ID")
    func operationalCertificate() throws {
        let cbor = "82845820cd09e015004a57e87658041415b86b903dc22680bf2811e9fe6c0598a7e7eda6000a5840fbfac7d4da151ef1dbf5a5027f2f24e93008be7fc62bc226cd7ebe9f5aa3a1715f133cddd4d4d4fd7f24cb6defef0fe4cc60553e5d1610a57ea97c92291ba900582035620a4c2085916bcd6b2b30078967f38b1d405627a54d5b8c9f18f182234828"
        let view = try view("NodeOperationalCertificate", cbor)
        #expect(string(view.decoded["issueCounter"]) == "0")
        #expect(string(view.decoded["kesPeriod"]) == "10")
        #expect(string(view.decoded["poolId"]) == "pool156j7gneclcxk3u29sqh4afgs428ghda4538t0p27xmf4ylu6zar")
    }

    @Test("transactions show the ID, fee, outputs, certificates and witnesses")
    func transaction() throws {
        let cbor = "84a400d9010281825820000000000000000000000000000000000000000000000000000000000000000200018182581d6054947bcf6b760319bcec250ec225fd1ce63baface47e34b44b73e4f91a000f4240021a00030d4004d901028183078200581ca49e1e4b74224dd10cd8c8798d3a6535f2e5ea3f209790798ab1c3b81a001e8480a100d9010282825820b8b326912aeaa821d06ff4ca9269b6fa087f12c026239b627a98b6e240cad34958400845d46fb94566443b54b69b95697301ed117e84965c4110c61d28182c444dd7ada01efaf5939f51ca65a97711d920442a6cae01a2fcd0dd829f0f1b3428490582582008ab27cba8005776e26a79f9befb2a411277194a7de1611ae9bc4aa7777b61d058400e27d682386e8ca0fce1aaaddfc2d76a40ed4f432aed34bd2f0612b9abfe6efdfef5a915343278b94ae85e3bf4da544e6f4b3c9fbef8015deff52bd91ee8480ff5f6"
        let view = try view("Tx ConwayEra", cbor)
        #expect(view.title == "Signed Transaction")
        #expect(string(view.decoded["transactionId"]) == "2b66c169ec846c23014af7d3b755e999e7d4017924031a750a40640d0e77df7d")
        #expect(string(view.decoded["fee"]) == "0.2 ADA (200000 lovelace)")
        guard case .array(let certificates) = view.decoded["certificates"] else {
            Issue.record("expected certificates")
            return
        }
        #expect(string(object(certificates.first)?["certificate"]) == "Stake Address Registration Certificate")
        guard case .array(let witnesses) = object(view.decoded["witnesses"])?["keyWitnesses"] else {
            Issue.record("expected key witnesses")
            return
        }
        #expect(witnesses.contains(.string(HashUtilsTests.paymentKeyHash)))
    }

    // MARK: Scripts, fallbacks and output

    @Test("native script JSON decodes with the cardano-cli time-lock meaning")
    func nativeScript() throws {
        let json = #"{"type":"all","scripts":[{"type":"sig","keyHash":"3749f2dd85a8f7fe837d40aa8b9c22737d1a4354cd2d42b0e3a8ffde"},{"type":"before","slot":1000}]}"#
        let view = try decoder.view(fileData: Data(json.utf8), source: "policy.script")
        #expect(string(view.decoded["scriptHash"]) == "dafe82c00f7ba1d2bf9d2f6b97ea16cce1522aaca380adfd742c85f2")
        guard case .array(let scripts) = object(view.decoded["script"])?["scripts"] else {
            Issue.record("expected child scripts")
            return
        }
        #expect(string(object(scripts.last)?["type"]) == "Valid before slot")
    }

    @Test("unknown types fall back to a generic CBOR tree")
    func unknownType() throws {
        let view = try view("SomethingNew", "a201820102026568656c6c6f")
        #expect(view.title == "Decoded CBOR")
        #expect(!view.notes.isEmpty)
    }

    @Test("encrypted files are reported rather than decoded")
    func encrypted() throws {
        let json = #"{"type":"PaymentSigningKeyShelley_ed25519","description":"Encrypted Payment Signing Key","encrHex":"00"}"#
        let view = try decoder.view(fileData: Data(json.utf8), source: "enc.skey")
        #expect(view.title == "Encrypted File")
    }

    @Test("CBOR output includes the hex and diagnostic notation")
    func cborOutput() throws {
        let view = try view("NodeOperationalCertificateIssueCounter",
                            "8201582035620a4c2085916bcd6b2b30078967f38b1d405627a54d5b8c9f18f182234828",
                            decoder: TextViewDecoder(network: nil, includeCBOR: true))
        #expect(view.cborHex == "8201582035620a4c2085916bcd6b2b30078967f38b1d405627a54d5b8c9f18f182234828")
        #expect(view.cborDiagnostic?.hasPrefix("[1, h'35620a4c") == true)
    }

    @Test("JSON output is valid and keeps field order")
    func jsonOutput() throws {
        let view = try view("PaymentVerificationKeyShelley_ed25519", HashUtilsTests.paymentVkeyCbor)
        let json = view.json()
        let parsed = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        let decoded = try #require(parsed["decoded"] as? [String: Any])
        #expect(decoded["keyHash"] as? String == HashUtilsTests.paymentKeyHash)
        let keyRole = try #require(json.range(of: "\"keyRole\""))
        let keyHash = try #require(json.range(of: "\"keyHash\""))
        #expect(keyRole.lowerBound < keyHash.lowerBound)
    }

    @Test("JSON keys are camel-cased labels")
    func jsonKeys() {
        #expect(DecodedObject.jsonKey("DRep ID (CIP-105)") == "drepIdCip105")
        #expect(DecodedObject.jsonKey("Pool ID Hex") == "poolIdHex")
        #expect(DecodedObject.jsonKey("KES Period") == "kesPeriod")
    }

    @Test("ADA amounts are exact and grouped")
    func adaFormatting() {
        #expect(TextViewDecoder.ada(100) == "0.0001 ADA (100 lovelace)")
        #expect(TextViewDecoder.ada(170_000_000) == "170 ADA (170000000 lovelace)")
        #expect(TextViewDecoder.ada(1_234_567_890) == "1,234.56789 ADA (1234567890 lovelace)")
        #expect(TextViewDecoder.ada(Int64(-2_500_000)) == "-2.5 ADA (-2500000 lovelace)")
    }
}
