import ArgumentParser
import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

/// Expected hashes below were produced by cardano-cli 11.0 for the same inputs.
@Suite("HashUtils")
struct HashUtilsTests {

    static let paymentVkeyCbor = "5820b8b326912aeaa821d06ff4ca9269b6fa087f12c026239b627a98b6e240cad349"
    static let paymentKeyHash = "3749f2dd85a8f7fe837d40aa8b9c22737d1a4354cd2d42b0e3a8ffde"
    static let extendedVkeyCbor = "58400968edcb47a849d0f95ab6a5e32892752c816f2aaf8b9d6adf6de1dae5771a614511d5ae66c7af28d6e38d1ee7c1e3c941a5e2c97f6290d3b65e1ac3ccb679f1"
    static let extendedKeyHash = "fa2276771d02b893abe78b6482be6714f0d0e480655b040c6c8dad7c"

    private func tempFile(_ name: String, _ contents: String) throws -> FilePath {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return FilePath(url.path)
    }

    private func envelope(_ type: String, _ cborHex: String) -> String {
        #"{"type": "\#(type)", "description": "", "cborHex": "\#(cborHex)"}"#
    }

    // MARK: Key hashes

    @Test("payment key hash matches cardano-cli address key-hash")
    func paymentKeyHash() throws {
        let path = try tempFile("pay.vkey", envelope("PaymentVerificationKeyShelley_ed25519", Self.paymentVkeyCbor))
        let loaded = try HashUtils.verificationKeyFile(path)
        #expect(try HashUtils.verificationKeyHash(payload: loaded.payload) == Self.paymentKeyHash)
        #expect(HashUtils.isExpectedKeyType(loaded.envelope.type, role: .payment))
        #expect(!HashUtils.isExpectedKeyType(loaded.envelope.type, role: .stake))
    }

    @Test("extended keys hash only the 32-byte public key")
    func extendedKeyHash() throws {
        let path = try tempFile("payext.vkey", envelope("PaymentExtendedVerificationKeyShelley_ed25519_bip32", Self.extendedVkeyCbor))
        let loaded = try HashUtils.verificationKeyFile(path)
        #expect(loaded.payload.count == 64)
        #expect(try HashUtils.verificationKeyHash(payload: loaded.payload) == Self.extendedKeyHash)
    }

    @Test("signing key files are rejected")
    func rejectsSigningKey() throws {
        let path = try tempFile("pay.skey", envelope("PaymentSigningKeyShelley_ed25519", Self.paymentVkeyCbor))
        #expect(throws: (any Error).self) { try HashUtils.verificationKeyFile(path) }
    }

    @Test("keys are accepted as Bech32 or hex")
    func keyFromText() throws {
        let hex = String(Self.paymentVkeyCbor.dropFirst(4))
        let fromHex = try HashUtils.verificationKeyPayload(from: hex, role: .payment)
        #expect(try HashUtils.verificationKeyHash(payload: fromHex) == Self.paymentKeyHash)

        let bech32 = "addr_vk1hzejdyf2a25zr5r07n9fy6dklgy87ykqyc3ekcn6nzmwysx26dysqc65ha"
        let fromBech32 = try HashUtils.verificationKeyPayload(from: bech32, role: .payment)
        #expect(fromBech32 == fromHex)

        // A stake key prefix is not a payment key.
        #expect(throws: (any Error).self) {
            try HashUtils.verificationKeyPayload(from: "stake_vk1pz4j0jagqpthdcn208uma7e2gyf8wx220hskzxhfh392wammv8gq7nu2kl", role: .payment)
        }
        #expect(throws: (any Error).self) { try HashUtils.verificationKeyPayload(from: "abcd", role: .payment) }
    }

    // MARK: Address credentials

    static let stakeKeyHash = "a49e1e4b74224dd10cd8c8798d3a6535f2e5ea3f209790798ab1c3b8"
    static let nativeScriptHash = "dafe82c00f7ba1d2bf9d2f6b97ea16cce1522aaca380adfd742c85f2"

    private func credential(_ address: String, _ part: HashUtils.AddressPart) throws -> HashUtils.AddressCredential {
        try HashUtils.credential(fromAddressBytes: HashUtils.addressBytes(bech32: address), part: part)
    }

    @Test("payment credentials are read from base, enterprise and script addresses")
    func paymentCredentialFromAddress() throws {
        // Addresses built by cardano-cli from the fixture keys and script.
        let base = try credential("addr1qym5nukask500l5r04q24zuuyfeh6xjr2nxj6s4suw50lh4ync0ykapzfhgsekxg0xxn5ef47tj750eqj7g8nz43cwuq7fxs39", .payment)
        #expect(base == HashUtils.AddressCredential(hash: try #require(Data(hexString: Self.paymentKeyHash)), isScript: false))

        let testnet = try credential("addr_test1qqm5nukask500l5r04q24zuuyfeh6xjr2nxj6s4suw50lh4ync0ykapzfhgsekxg0xxn5ef47tj750eqj7g8nz43cwuqalmsa6", .payment)
        #expect(testnet.hash.toHex == Self.paymentKeyHash)

        let enterprise = try credential("addr1vym5nukask500l5r04q24zuuyfeh6xjr2nxj6s4suw50lhshcxyhx", .payment)
        #expect(enterprise.hash.toHex == Self.paymentKeyHash)

        let script = try credential("addr1z8d0aqkqpaa6r54ln5hkh9l2zmxwz5324j3cpt0awskgtu4ync0ykapzfhgsekxg0xxn5ef47tj750eqj7g8nz43cwuquqfgjd", .payment)
        #expect(script.hash.toHex == Self.nativeScriptHash)
        #expect(script.isScript)

        let example = try credential("addr1v9dj7z3r5k96dqk8kjre7kzhlzete4crejyl3hm754a3dlss0ue7p", .payment)
        #expect(example.hash.toHex == "5b2f0a23a58ba682c7b4879f5857f8b2bcd703cc89f8df7ea57b16fe")
    }

    @Test("stake credentials are read from stake and base addresses")
    func stakeCredentialFromAddress() throws {
        #expect(try credential("stake1uxjfu8jtws3ym5gvmry8nrf6v56l9e028usf0yre32cu8wq0cg4n9", .stake).hash.toHex == Self.stakeKeyHash)
        #expect(try credential("addr1qym5nukask500l5r04q24zuuyfeh6xjr2nxj6s4suw50lh4ync0ykapzfhgsekxg0xxn5ef47tj750eqj7g8nz43cwuq7fxs39", .stake).hash.toHex == Self.stakeKeyHash)
        // Script payment part, key stake part.
        let mixed = try credential("addr1z8d0aqkqpaa6r54ln5hkh9l2zmxwz5324j3cpt0awskgtu4ync0ykapzfhgsekxg0xxn5ef47tj750eqj7g8nz43cwuquqfgjd", .stake)
        #expect(mixed.hash.toHex == Self.stakeKeyHash)
        #expect(!mixed.isScript)
        let scriptStake = try credential("stake_test17rd0aqkqpaa6r54ln5hkh9l2zmxwz5324j3cpt0awskgtusy70n8d", .stake)
        #expect(scriptStake.hash.toHex == Self.nativeScriptHash)
        #expect(scriptStake.isScript)
    }

    @Test("addresses without the requested credential are rejected")
    func missingCredential() throws {
        #expect(throws: (any Error).self) { try credential("addr1vym5nukask500l5r04q24zuuyfeh6xjr2nxj6s4suw50lhshcxyhx", .stake) }
        #expect(throws: (any Error).self) { try credential("stake1uxjfu8jtws3ym5gvmry8nrf6v56l9e028usf0yre32cu8wq0cg4n9", .payment) }
        #expect(throws: (any Error).self) { try HashUtils.credential(fromAddressBytes: Data([0x61, 0x01]), part: .payment) }
    }

    @Test("cardano-cli address info output is parsed from its base16 field")
    func addressInfo() throws {
        let json = #"{"address": "addr1v9dj7z3r5k96dqk8kjre7kzhlzete4crejyl3hm754a3dlss0ue7p", "base16": "615b2f0a23a58ba682c7b4879f5857f8b2bcd703cc89f8df7ea57b16fe", "type": "payment"}"#
        #expect(try HashUtils.credential(fromAddressInfo: json, part: .payment).hash.toHex == "5b2f0a23a58ba682c7b4879f5857f8b2bcd703cc89f8df7ea57b16fe")
    }

    @Test("addresses resolve from Bech32, address files and address names")
    func addressText() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let directory = FilePath(dir.path)
        let base = "addr1qym5nukask500l5r04q24zuuyfeh6xjr2nxj6s4suw50lh4ync0ykapzfhgsekxg0xxn5ef47tj750eqj7g8nz43cwuq7fxs39"
        let stake = "stake1uxjfu8jtws3ym5gvmry8nrf6v56l9e028usf0yre32cu8wq0cg4n9"
        let enterprise = "addr1vym5nukask500l5r04q24zuuyfeh6xjr2nxj6s4suw50lhshcxyhx"
        try (base + "\n").write(to: dir.appendingPathComponent("alice.payment.addr"), atomically: true, encoding: .utf8)
        try stake.write(to: dir.appendingPathComponent("alice.stake.addr"), atomically: true, encoding: .utf8)
        try enterprise.write(to: dir.appendingPathComponent("bob.addr"), atomically: true, encoding: .utf8)

        #expect(try HashUtils.addressText(base, part: .payment, directory: directory) == base)
        #expect(try HashUtils.addressText("alice", part: .payment, directory: directory) == base)
        #expect(try HashUtils.addressText("bob", part: .payment, directory: directory) == enterprise)
        #expect(try HashUtils.addressText("alice", part: .stake, directory: directory) == stake)
        #expect(try HashUtils.addressText(dir.appendingPathComponent("bob.addr").path, part: .payment, directory: directory) == enterprise)
        #expect(throws: (any Error).self) { try HashUtils.addressText("nobody", part: .payment, directory: directory) }
    }

    // MARK: Other key roles

    @Test("VRF key hashes are blake2b-256 of the key, matching node key-hash-VRF")
    func vrfKeyHash() throws {
        let payload = try #require(Data(hexString: "33648cad2fcbb61f061ede0a638e5fbeb33979e94cf95c3ea36f25371fbfc332"))
        #expect(try HashUtils.verificationKeyHash(payload: payload, role: .vrf) == "dc80e3aa843557014ba0b9e29c4c51e27bb8a711088c05e15a4d2e7f5110454e")
        let fromBech32 = try HashUtils.verificationKeyPayload(from: "vrf_vk1xdjgetf0ewmp7ps7mc9x8rjlh6enj70ffnu4c04rdujnw8alcveqv5vhrs", role: .vrf)
        #expect(fromBech32 == payload)
        // VRF keys have no extended form.
        #expect(throws: (any Error).self) { try HashUtils.verificationKeyPayload(from: Self.extendedVkeyCbor.dropFirst(4).description, role: .vrf) }
    }

    @Test("roles other than payment and stake reject key files of another type, like cardano-cli")
    func strictKeyTypes() throws {
        let payment = try tempFile("pay.vkey", envelope("PaymentVerificationKeyShelley_ed25519", Self.paymentVkeyCbor))
        for role in [HashUtils.KeyRole.drep, .committee, .vrf, .stakePool, .genesis] {
            #expect(throws: (any Error).self) { try HashUtils.verificationKeyFile(payment, role: role) }
        }
        let drep = try tempFile("drep.vkey", envelope("DRepVerificationKey_ed25519", "5820d1fa6be9518280be166134bf203a0583eeafa979ad741fa464b12fd4cf305c55"))
        #expect(try HashUtils.verificationKeyFile(drep, role: .drep).payload.count == 32)
        // cardano-cli address key-hash hashes any key, so payment only warns.
        #expect(try HashUtils.verificationKeyFile(drep, role: .payment).payload.count == 32)
    }

    @Test("DRep key hashes are read from hex, CIP-105 and CIP-129 IDs")
    func drepKeyHash() throws {
        let hex = "6a95e865d0b7a6aea0d584809e4e388c6aff51e5dc35361d44ad821e"
        #expect(try HashUtils.drepKeyHash(from: hex).toHex == hex)
        #expect(try HashUtils.drepKeyHash(from: "drep1d227sewsk7n2agx4sjqfun3c33407509ms6nv82y4kppujxkm5a").toHex == hex)
        #expect(try HashUtils.drepKeyHash(from: "drep1yf4ft6r96zm6dt4q6kzgp8jw8zxx4l63uhwr2dsagjkcy8stq32w0").toHex == hex)
        #expect(throws: (any Error).self) { try HashUtils.drepKeyHash(from: "abcd") }

        let ids = try HashUtils.drepIds(keyHash: try #require(Data(hexString: hex)))
        #expect(ids.cip105 == "drep1d227sewsk7n2agx4sjqfun3c33407509ms6nv82y4kppujxkm5a")
        #expect(ids.cip129 == "drep1yf4ft6r96zm6dt4q6kzgp8jw8zxx4l63uhwr2dsagjkcy8stq32w0")
    }

    @Test("pool IDs match stake-pool id")
    func poolIds() throws {
        let ids = try HashUtils.poolIds(keyHash: try #require(Data(hexString: "a6a5e44f38fe0d68f145802f5ea510aa8e8bb7b5a44eb7855e36d352")))
        #expect(ids.bech32 == "pool156j7gneclcxk3u29sqh4afgs428ghda4538t0p27xmf4ylu6zar")
    }

    // MARK: Pool metadata

    @Test("valid pool metadata passes, including a lowercase ticker and extra fields")
    func validPoolMetadata() throws {
        try HashUtils.validatePoolMetadata(Data(#"{"name":"x","description":"d","ticker":"TST","homepage":"https://x.io"}"#.utf8))
        try HashUtils.validatePoolMetadata(Data(#"{"name":"x","description":"d","ticker":"tst","homepage":"hello","extended":"https://x.io/e.json"}"#.utf8))
        #expect(try HashUtils.anchorDataHash(Data(#"{"name":"x","description":"d","ticker":"TST","homepage":"https://x.io"}"#.utf8))
                == "ddc00ca1fa2f6af2883992f5218ef2b1a9812212d645fe8d194b65698234aeed")
    }

    @Test(
        "invalid pool metadata is rejected like cardano-cli",
        arguments: [
            "not json",
            "[1,2]",
            #"{"name":"x"}"#,
            #"{"name":1,"description":"d","ticker":"TST","homepage":"https://x.io"}"#,
            #"{"name":"x","description":"d","ticker":"TOOLONGTICKER","homepage":"https://x.io"}"#,
            #"{"name":"x","description":"d","ticker":"TS","homepage":"https://x.io"}"#,
            "{\"name\":\"\(String(repeating: "n", count: 51))\",\"description\":\"d\",\"ticker\":\"TST\",\"homepage\":\"h\"}",
            "{\"name\":\"x\",\"description\":\"\(String(repeating: "d", count: 256))\",\"ticker\":\"TST\",\"homepage\":\"h\"}",
            "{\"name\":\"x\",\"description\":\"\(String(repeating: "d", count: 250))\",\"ticker\":\"TST\",\"homepage\":\"\(String(repeating: "h", count: 300))\"}",
        ]
    )
    func invalidPoolMetadata(json: String) {
        #expect(throws: (any Error).self) { try HashUtils.validatePoolMetadata(Data(json.utf8)) }
    }

    @Test("pool metadata lengths count characters, not bytes")
    func poolMetadataUnicode() throws {
        let name = String(repeating: "é", count: 50)
        try HashUtils.validatePoolMetadata(Data("{\"name\":\"\(name)\",\"description\":\"d\",\"ticker\":\"TST\",\"homepage\":\"h\"}".utf8))
    }

    @Test("keys given as text are written to a temporary envelope readable as the same key")
    func temporaryKeyFile() throws {
        let payload = try #require(Data(hexString: "33648cad2fcbb61f061ede0a638e5fbeb33979e94cf95c3ea36f25371fbfc332"))
        let file = try HashUtils.temporaryKeyFile(type: "VrfVerificationKey_PraosVRF", payload: payload)
        defer { try? FileManager.default.removeItem(atPath: file.string) }
        #expect(try HashUtils.verificationKeyFile(file, role: .vrf).payload == payload)
    }

    // MARK: Scripts

    @Test("Plutus script hash matches cardano-cli hash script")
    func plutusScriptHash() throws {
        let path = try tempFile("v3.plutus", envelope("PlutusScriptV3", "46450101002499"))
        let result = try HashUtils.scriptHash(scriptFile: path)
        #expect(result.hash == "186e32faa80a26810392fda6d559c7ed4721a65ce1c9d4ef3e1c87b4")
    }

    @Test(
        "native script hashes match cardano-cli, including before/after time locks",
        arguments: [
            (#"{"type":"sig","keyHash":"3749f2dd85a8f7fe837d40aa8b9c22737d1a4354cd2d42b0e3a8ffde"}"#,
             "1241def2089f832c48886b5fab77f6e850b21e23fcddf2e8ea2a1623"),
            (#"{"type":"before","slot":1000}"#, "f34ce37b50eec3bce2bd096fdaebd447cb92c9e74e2a4093beff8705"),
            (#"{"type":"after","slot":1000}"#, "592fb0f9d8ed15c06858118d134d5c4b7c77320507810fee9ac2ddf9"),
            (#"{"type":"all","scripts":[{"type":"sig","keyHash":"3749f2dd85a8f7fe837d40aa8b9c22737d1a4354cd2d42b0e3a8ffde"},{"type":"before","slot":1000}]}"#,
             "dafe82c00f7ba1d2bf9d2f6b97ea16cce1522aaca380adfd742c85f2"),
            (#"{"type":"atLeast","required":1,"scripts":[{"type":"sig","keyHash":"3749f2dd85a8f7fe837d40aa8b9c22737d1a4354cd2d42b0e3a8ffde"}]}"#,
             "b521ee162b08d9cc55649b09f482b19fc01c4a31a32b5ddef768dcbc"),
        ]
    )
    func nativeScriptHash(json: String, expected: String) throws {
        let path = try tempFile("policy.script", json)
        #expect(try HashUtils.scriptHash(scriptFile: path).hash == expected)
    }

    @Test("unsupported script envelopes are rejected")
    func rejectsUnknownScriptType() throws {
        let path = try tempFile("x.plutus", envelope("PlutusScriptV9", "46450101002499"))
        #expect(throws: (any Error).self) { try HashUtils.scriptHash(scriptFile: path) }
    }

    // MARK: Anchor data / genesis

    @Test("anchor data hash matches cardano-cli hash anchor-data")
    func anchorDataHash() throws {
        #expect(try HashUtils.anchorDataHash(Data("hello".utf8)) == "324dcf027dd4a30a932c441f365a25e86b173defa4b8e58948253471b81b72cf")
        #expect(try HashUtils.anchorDataHash(Data("hello\n".utf8)) == "93becc6e9882211c3ec3708c95bcd69baab7bb59c7f4bc84ce637b88a534b783")
    }

    @Test("genesis file hash covers the exact file bytes")
    func genesisFileHash() throws {
        let path = try tempFile("genesis.json", "hello\n")
        #expect(try HashUtils.genesisFileHash(path) == "93becc6e9882211c3ec3708c95bcd69baab7bb59c7f4bc84ce637b88a534b783")
    }

    @Test("expected hashes are normalized and validated")
    func normalizedHash() {
        let upper = String(repeating: "AB", count: 32)
        #expect(HashUtils.normalizedHash32(upper) == upper.lowercased())
        #expect(HashUtils.normalizedHash32("abcd") == nil)
        #expect(HashUtils.normalizedHash32(String(repeating: "zz", count: 32)) == nil)
    }

    @Test("ipfs URLs go through a gateway; other schemes are rejected")
    func anchorDownloadURL() throws {
        let ipfs = try HashUtils.anchorDownloadURL("ipfs://bafkreiabc")
        #expect(ipfs.absoluteString.hasSuffix("/ipfs/bafkreiabc"))
        #expect(try HashUtils.anchorDownloadURL("https://example.com/a.json").absoluteString == "https://example.com/a.json")
        #expect(throws: (any Error).self) { try HashUtils.anchorDownloadURL("ftp://example.com/a.json") }
    }
}

@Suite("hash command parsing")
struct HashCommandParseTests {

    @Test("every hash case maps to its command type")
    func dispatch() {
        #expect(ObjectIdentifier(HashCommands.paymentKey.command()) == ObjectIdentifier(HashMainCommand.PaymentKey.self))
        #expect(ObjectIdentifier(HashCommands.stakeKey.command()) == ObjectIdentifier(HashMainCommand.StakeKey.self))
        #expect(ObjectIdentifier(HashCommands.anchorData.command()) == ObjectIdentifier(HashMainCommand.AnchorData.self))
        #expect(ObjectIdentifier(HashCommands.script.command()) == ObjectIdentifier(HashMainCommand.Script.self))
        #expect(ObjectIdentifier(HashCommands.genesisFile.command()) == ObjectIdentifier(HashMainCommand.GenesisFile.self))
        #expect(ObjectIdentifier(HashCommands.drepKey.command()) == ObjectIdentifier(HashMainCommand.DRepKey.self))
        #expect(ObjectIdentifier(HashCommands.committeeKey.command()) == ObjectIdentifier(HashMainCommand.CommitteeKey.self))
        #expect(ObjectIdentifier(HashCommands.poolId.command()) == ObjectIdentifier(HashMainCommand.PoolId.self))
        #expect(ObjectIdentifier(HashCommands.vrfKey.command()) == ObjectIdentifier(HashMainCommand.VRFKey.self))
        #expect(ObjectIdentifier(HashCommands.genesisKey.command()) == ObjectIdentifier(HashMainCommand.GenesisKey.self))
        #expect(ObjectIdentifier(HashCommands.drepMetadata.command()) == ObjectIdentifier(HashMainCommand.DRepMetadata.self))
        #expect(ObjectIdentifier(HashCommands.poolMetadata.command()) == ObjectIdentifier(HashMainCommand.PoolMetadata.self))
        #expect(HashCommands.subcommands.count == 12)
        let names = HashCommands.subcommands.map { $0.configuration.commandName }
        #expect(Set(names).count == names.count)
    }

    @Test("payment-key and stake-key accept cardano-cli flag names")
    func keyHashFlags() throws {
        let payment = try HashMainCommand.PaymentKey.parse(["--payment-verification-key-file", "alice.payment.vkey", "--tool", "cardano-cli"])
        #expect(payment.verificationKeyFile?.string == "alice.payment.vkey")
        #expect(payment.tool == .cardanoCLI)

        let stake = try HashMainCommand.StakeKey.parse(["--stake-verification-key", "stake_vk1…", "-o", "stake.hash"])
        #expect(stake.verificationKey == "stake_vk1…")
        #expect(stake.outFile?.string == "stake.hash")
    }

    @Test("anchor-data allows only one source and a 32-byte expected hash")
    func anchorDataValidation() throws {
        let parsed = try HashMainCommand.AnchorData.parse(["--file-text", "drep.jsonld", "--expected-hash", String(repeating: "0", count: 64)])
        #expect(parsed.fileText?.string == "drep.jsonld")
        #expect(throws: (any Error).self) { try HashMainCommand.AnchorData.parse(["--text", "a", "--url", "https://x"]) }
        #expect(throws: (any Error).self) { try HashMainCommand.AnchorData.parse(["--text", "a", "--expected-hash", "abc"]) }
    }

    @Test("script and genesis-file parse their file options")
    func fileOptions() throws {
        #expect(try HashMainCommand.Script.parse(["--script-file", "policy.script"]).scriptFile?.string == "policy.script")
        #expect(try HashMainCommand.GenesisFile.parse(["--genesis", "shelley-genesis.json"]).genesis?.string == "shelley-genesis.json")
    }

    @Test("payment-key and stake-key accept addresses")
    func addressOptions() throws {
        #expect(try HashMainCommand.PaymentKey.parse(["--address", "addr1v9dj7z3r5k96dqk8kjre7kzhlzete4crejyl3hm754a3dlss0ue7p"]).address != nil)
        #expect(try HashMainCommand.StakeKey.parse(["--stake-address", "stake1…"]).stakeAddress == "stake1…")
    }

    @Test("drep-key output formats and sources")
    func drepKeyParsing() throws {
        let hex = try HashMainCommand.DRepKey.parse(["--drep-verification-key-file", "d.drep.vkey"])
        #expect(hex.output == .outputHex)
        #expect(try HashMainCommand.DRepKey.parse(["--drep-key-hash", "drep1…", "--output-cip129"]).output == .outputCip129)
        #expect(try HashMainCommand.DRepKey.parse(["--drep-name", "d", "--output-bech32"]).drepName == "d")
        #expect(HashMainCommand.DRepKey.configuration.aliases.contains("drep-id"))
    }

    @Test("pool-id accepts cardano-cli flags and rejects both key flags")
    func poolIdParsing() throws {
        #expect(try HashMainCommand.PoolId.parse(["--cold-verification-key-file", "p.node.vkey", "--output-hex"]).output == .outputHex)
        #expect(try HashMainCommand.PoolId.parse(["--pool-name", "p"]).output == .outputBech32)
        #expect(throws: (any Error).self) {
            try HashMainCommand.PoolId.parse(["--stake-pool-verification-key", "a", "--stake-pool-verification-extended-key", "b"])
        }
    }

    @Test("metadata commands take a file or URL and validate the expected hash")
    func metadataParsing() throws {
        #expect(try HashMainCommand.DRepMetadata.parse(["--drep-metadata-file", "d.jsonld"]).metadataFile?.string == "d.jsonld")
        #expect(try HashMainCommand.PoolMetadata.parse(["--pool-metadata-url", "https://x.io/p.json"]).metadataUrl == "https://x.io/p.json")
        #expect(throws: (any Error).self) { try HashMainCommand.PoolMetadata.parse(["--pool-metadata-file", "a", "--pool-metadata-url", "b"]) }
        #expect(throws: (any Error).self) { try HashMainCommand.DRepMetadata.parse(["--drep-metadata-file", "a", "--expected-hash", "00"]) }
    }

    @Test("committee-key, vrf-key and genesis-key parse their key options")
    func otherKeyParsing() throws {
        #expect(try HashMainCommand.CommitteeKey.parse(["--verification-key", "cc_hot_vk1…"]).verificationKey == "cc_hot_vk1…")
        #expect(try HashMainCommand.VRFKey.parse(["--pool-name", "p"]).poolName == "p")
        #expect(try HashMainCommand.GenesisKey.parse(["--verification-key-file", "g.vkey"]).verificationKeyFile?.string == "g.vkey")
        #expect(HashMainCommand.Script.configuration.aliases.contains("policy-id"))
    }

    @Test("text-view takes the file as an argument or --in-file, not both")
    func textViewParsing() throws {
        let positional = try TextViewMainCommand.parse(["pool.cert", "--output-cbor", "--json"])
        #expect(positional.file?.string == "pool.cert")
        #expect(positional.outputCBOR)
        #expect(positional.json)
        #expect(try TextViewMainCommand.parse(["--in-file", "node.opcert"]).inFile?.string == "node.opcert")
        #expect(throws: (any Error).self) { try TextViewMainCommand.parse(["a.cert", "--in-file", "b.cert"]) }
    }
}
