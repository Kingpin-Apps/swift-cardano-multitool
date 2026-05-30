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
}
