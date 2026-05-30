import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("BlockchainExplorer enum")
struct BlockchainExplorerEnumTests {

    @Test("all 5 cases are present")
    func allCasesPresent() {
        let names = Set(BlockchainExplorer.allCases.map(\.rawValue))
        #expect(names == ["adastat", "cardanoscan", "cexplorer", "eutxo", "pooltool"])
    }

    @Test("each case has a non-empty description")
    func descriptionsNonEmpty() {
        for c in BlockchainExplorer.allCases {
            #expect(!c.description.isEmpty)
        }
    }

    @Test("explorer(network:) returns the matching concrete type")
    func explorerFactoryReturnsMatchingType() {
        #expect(BlockchainExplorer.adaStat.explorer(network: .mainnet) is AdaStat)
        #expect(BlockchainExplorer.cardanoScan.explorer(network: .mainnet) is CardanoScan)
        #expect(BlockchainExplorer.cexplorer.explorer(network: .mainnet) is Cexplorer)
        #expect(BlockchainExplorer.eutxo.explorer(network: .mainnet) is Eutxo)
        #expect(BlockchainExplorer.pooltool.explorer(network: .mainnet) is PoolTool)
    }

    @Test("explorer(network:) propagates the chosen network")
    func explorerFactoryPropagatesNetwork() {
        let e = BlockchainExplorer.cardanoScan.explorer(network: .preview)
        #expect(e.network == .preview)
    }
}
