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

    @Test("viewBlock rejects a block number identifier")
    func viewBlockRejectsNumber() {
        let explorer = Cexplorer(network: .mainnet)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try explorer.viewBlock(block: .number(BlockNumber(1)))
        }
    }
}
