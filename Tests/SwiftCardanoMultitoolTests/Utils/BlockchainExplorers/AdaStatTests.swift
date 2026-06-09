import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("AdaStat")
struct AdaStatTests {

    @Test("mainnet baseURL points at adastat.net")
    func mainnetBaseURL() throws {
        let url = try AdaStat(network: .mainnet).baseURL
        #expect(url.absoluteString == "https://adastat.net")
    }

    @Test("preprod baseURL throws notImplemented (mainnet-only explorer)")
    func preprodThrows() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try AdaStat(network: .preprod).baseURL
        }
    }

    @Test("preview baseURL throws notImplemented (mainnet-only explorer)")
    func previewThrows() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try AdaStat(network: .preview).baseURL
        }
    }

    @Test("guildnet baseURL throws unsupportedNetwork")
    func guildnetThrows() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try AdaStat(network: .guildnet).baseURL
        }
    }

    @Test("viewBlock rejects a block number identifier")
    func viewBlockRejectsNumber() {
        let explorer = AdaStat(network: .mainnet)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try explorer.viewBlock(block: .number(BlockNumber(123)))
        }
    }

    @Test("viewBlock accepts a body hash and builds /blocks/<hex>")
    func viewBlockAcceptsBodyHash() throws {
        let bodyHash = BlockBodyHash(payload: Data(repeating: 0xCD, count: 32))
        let url = try AdaStat(network: .mainnet).viewBlock(block: .bodyHash(bodyHash))
        let expected = String(repeating: "cd", count: 32)
        #expect(url.absoluteString == "https://adastat.net/blocks/\(expected)")
    }

    @Test("viewTransaction builds /transactions/<txid-hex>")
    func viewTransactionBuildsPath() throws {
        let txId = TransactionId(payload: Data(repeating: 0x42, count: 32))
        let url = try AdaStat(network: .mainnet).viewTransaction(transactionId: txId)
        let expected = String(repeating: "42", count: 32)
        #expect(url.absoluteString == "https://adastat.net/transactions/\(expected)")
    }

    @Test("viewAddress builds /addresses/<bech32>")
    func viewAddressBuildsPath() throws {
        let addr = try ChainFixtures.makeAddress()
        let url = try AdaStat(network: .mainnet).viewAddress(address: addr)
        let bech32 = try addr.toBech32()
        #expect(url.absoluteString == "https://adastat.net/addresses/\(bech32)")
    }

    @Test("viewAccount builds /accounts/<staking-key-hash-hex>")
    func viewAccountBuildsPath() throws {
        let addr = try ChainFixtures.makeAddress(seed: 0xAA)
        let url = try AdaStat(network: .mainnet).viewAccount(address: addr)
        // staking part of makeAddress(seed: 0xAA) is 28 bytes of 0xAA
        let expected = String(repeating: "aa", count: 28)
        #expect(url.absoluteString == "https://adastat.net/accounts/\(expected)")
    }

    @Test("viewPool builds /pools/<hex-pool-id>")
    func viewPoolBuildsHexPath() throws {
        let poolBech32 = "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt"
        let pool = PoolOperator(argument: poolBech32)
        let url = try AdaStat(network: .mainnet).viewPool(pool: pool!)
        // Should be the hex form of the pool ID — verify the prefix and length only.
        #expect(url.absoluteString.hasPrefix("https://adastat.net/pools/"))
        let component = url.lastPathComponent
        #expect(component.count == 56)  // 28-byte pool ID = 56 hex chars
    }
}
