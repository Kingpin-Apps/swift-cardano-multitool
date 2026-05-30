import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("PoolTool")
struct PoolToolTests {

    @Test("mainnet baseURL points at pooltool.io")
    func mainnetBaseURL() throws {
        let url = try PoolTool(network: .mainnet).baseURL
        #expect(url.absoluteString == "https://pooltool.io")
    }

    @Test("preprod baseURL throws notImplemented (mainnet-only explorer)")
    func preprodThrows() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try PoolTool(network: .preprod).baseURL
        }
    }

    @Test("viewBlock accepts a block number and builds /realtime/<n>")
    func viewBlockAcceptsNumber() throws {
        let url = try PoolTool(network: .mainnet).viewBlock(block: .number(BlockNumber(999)))
        #expect(url.absoluteString == "https://pooltool.io/realtime/999")
    }

    @Test("viewBlock rejects a body hash identifier")
    func viewBlockRejectsBodyHash() {
        let explorer = PoolTool(network: .mainnet)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try explorer.viewBlock(block: .bodyHash(BlockBodyHash(payload: Data(count: 32))))
        }
    }

    @Test("viewTransaction throws notImplemented (uses default protocol impl)")
    func viewTransactionThrows() {
        let explorer = PoolTool(network: .mainnet)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try explorer.viewTransaction(transactionId: TransactionId(payload: Data(count: 32)))
        }
    }
}
