import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("CardanoScan")
struct CardanoScanTests {

    // MARK: - Base URL per network

    @Test("mainnet baseURL points at cardanoscan.io")
    func mainnetBaseURL() throws {
        let url = try CardanoScan(network: .mainnet).baseURL
        #expect(url.absoluteString == "https://cardanoscan.io")
    }

    @Test("preprod baseURL points at preprod.cardanoscan.io")
    func preprodBaseURL() throws {
        let url = try CardanoScan(network: .preprod).baseURL
        #expect(url.absoluteString == "https://preprod.cardanoscan.io")
    }

    @Test("preview baseURL points at preview.cardanoscan.io")
    func previewBaseURL() throws {
        let url = try CardanoScan(network: .preview).baseURL
        #expect(url.absoluteString == "https://preview.cardanoscan.io")
    }

    @Test("guildnet baseURL throws unsupportedNetwork")
    func guildnetThrows() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try CardanoScan(network: .guildnet).baseURL
        }
    }

    // MARK: - viewBlock

    @Test("viewBlock accepts a block number and builds /blocks/<n>")
    func viewBlockAcceptsNumber() throws {
        let url = try CardanoScan(network: .mainnet).viewBlock(block: .number(BlockNumber(123)))
        #expect(url.absoluteString == "https://cardanoscan.io/blocks/123")
    }

    @Test("viewBlock rejects a body hash identifier")
    func viewBlockRejectsBodyHash() {
        let explorer = CardanoScan(network: .mainnet)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try explorer.viewBlock(block: .bodyHash(BlockBodyHash(payload: Data(count: 32))))
        }
    }

    // MARK: - viewTransaction

    @Test("viewTransaction builds /transaction/<txid-hex>")
    func viewTransactionBuildsHexPath() throws {
        let txId = TransactionId(payload: Data(repeating: 0xAB, count: 32))
        let url = try CardanoScan(network: .mainnet).viewTransaction(transactionId: txId)
        let expectedHex = String(repeating: "ab", count: 32)
        #expect(url.absoluteString == "https://cardanoscan.io/transaction/\(expectedHex)")
    }

    @Test("viewTransaction routes through the network-specific subdomain")
    func viewTransactionUsesPreprodSubdomain() throws {
        let txId = TransactionId(payload: Data(repeating: 0x01, count: 32))
        let url = try CardanoScan(network: .preprod).viewTransaction(transactionId: txId)
        #expect(url.host == "preprod.cardanoscan.io")
        #expect(url.path == "/transaction/" + String(repeating: "01", count: 32))
    }

    // MARK: - viewAddress

    @Test("viewAddress builds /address/<bech32> for a payment address")
    func viewAddressBuildsPaymentPath() throws {
        let addr = try ChainFixtures.makeAddress(seed: 0xCD)
        let url = try CardanoScan(network: .mainnet).viewAddress(address: addr)
        let bech32 = try addr.toBech32()
        #expect(url.absoluteString == "https://cardanoscan.io/address/\(bech32)")
    }

    // MARK: - viewAccount

    @Test("viewAccount rejects a payment-only (non-stake) address")
    func viewAccountRejectsPaymentAddress() throws {
        let addr = try ChainFixtures.makeAddress(seed: 0xEF)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try CardanoScan(network: .mainnet).viewAccount(address: addr)
        }
    }

    // MARK: - viewPool

    @Test("viewPool builds /pool/<bech32-pool-id>")
    func viewPoolBuildsBech32Path() throws {
        let poolBech32 = "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt"
        let pool = PoolOperator(argument: poolBech32)
        let url = try CardanoScan(network: .mainnet).viewPool(pool: pool!)
        #expect(url.absoluteString == "https://cardanoscan.io/pool/\(poolBech32)")
    }
}
