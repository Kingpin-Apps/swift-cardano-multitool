import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("Cexplorer")
struct CexplorerTests {

    @Test("mainnet baseURL points at cexplorer.io")
    func mainnetBaseURL() throws {
        let url = try Cexplorer(network: .mainnet).baseURL
        #expect(url.absoluteString == "https://cexplorer.io")
    }

    @Test("preprod baseURL points at preprod.cexplorer.io")
    func preprodBaseURL() throws {
        let url = try Cexplorer(network: .preprod).baseURL
        #expect(url.absoluteString == "https://preprod.cexplorer.io")
    }

    @Test("preview baseURL points at preview.cexplorer.io")
    func previewBaseURL() throws {
        let url = try Cexplorer(network: .preview).baseURL
        #expect(url.absoluteString == "https://preview.cexplorer.io")
    }

    @Test("guildnet baseURL throws unsupportedNetwork")
    func guildnetThrows() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try Cexplorer(network: .guildnet).baseURL
        }
    }

    @Test("viewBlock requires a body hash, not a number")
    func viewBlockRejectsNumber() {
        let explorer = Cexplorer(network: .mainnet)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try explorer.viewBlock(block: .number(BlockNumber(1)))
        }
    }

    @Test("viewBlock with a body hash builds /block/<hex>")
    func viewBlockAcceptsBodyHash() throws {
        let bodyHash = BlockBodyHash(payload: Data(repeating: 0x12, count: 32))
        let url = try Cexplorer(network: .mainnet).viewBlock(block: .bodyHash(bodyHash))
        let expected = String(repeating: "12", count: 32)
        #expect(url.absoluteString == "https://cexplorer.io/block/\(expected)")
    }

    @Test("viewTransaction builds /tx/<txid-hex>")
    func viewTransactionBuildsTxPath() throws {
        let txId = TransactionId(payload: Data(repeating: 0xAB, count: 32))
        let url = try Cexplorer(network: .preview).viewTransaction(transactionId: txId)
        let expected = String(repeating: "ab", count: 32)
        #expect(url.absoluteString == "https://preview.cexplorer.io/tx/\(expected)")
    }

    @Test("viewAddress builds /address/<bech32>")
    func viewAddressBuildsAddressPath() throws {
        let addr = try ChainFixtures.makeAddress()
        let url = try Cexplorer(network: .mainnet).viewAddress(address: addr)
        let bech32 = try addr.toBech32()
        #expect(url.absoluteString == "https://cexplorer.io/address/\(bech32)")
    }

    @Test("viewAccount rejects a non-stake address")
    func viewAccountRejectsPayment() throws {
        let addr = try ChainFixtures.makeAddress()
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try Cexplorer(network: .mainnet).viewAccount(address: addr)
        }
    }

    @Test("viewPool builds /pool/<bech32>")
    func viewPoolBuildsPoolPath() throws {
        let poolBech32 = "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt"
        let pool = PoolOperator(argument: poolBech32)
        let url = try Cexplorer(network: .mainnet).viewPool(pool: pool!)
        #expect(url.absoluteString == "https://cexplorer.io/pool/\(poolBech32)")
    }
}
