import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("CardanoScan")
struct CardanoScanTests {

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
}
