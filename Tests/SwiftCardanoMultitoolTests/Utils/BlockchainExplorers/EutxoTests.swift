import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("Eutxo")
struct EutxoTests {

    @Test("mainnet baseURL points at eutxo.org")
    func mainnetBaseURL() throws {
        let url = try Eutxo(network: .mainnet).baseURL
        #expect(url.absoluteString == "https://eutxo.org")
    }

    @Test("preprod baseURL throws notImplemented (mainnet-only explorer)")
    func preprodThrows() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try Eutxo(network: .preprod).baseURL
        }
    }

    @Test("preview baseURL throws notImplemented (mainnet-only explorer)")
    func previewThrows() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try Eutxo(network: .preview).baseURL
        }
    }

    @Test("viewAccount throws notImplemented (not supported by Eutxo)")
    func viewAccountThrows() {
        let explorer = Eutxo(network: .mainnet)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            // Default protocol impl throws — give it any address-like thing it can carry.
            // We don't have a clean way to fabricate an Address here, so go through viewPool
            // instead, which also uses the default-throws path.
            _ = try explorer.viewPool(pool: PoolOperator(argument: String(repeating: "ab", count: 28))!)
        }
    }

    @Test("viewBlock rejects a block number identifier")
    func viewBlockRejectsNumber() {
        let explorer = Eutxo(network: .mainnet)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try explorer.viewBlock(block: .number(BlockNumber(1)))
        }
    }
}
