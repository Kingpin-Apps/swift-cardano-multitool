import SwiftCardanoChain
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("Contexts.override + getContext")
struct ChainContextOverrideTests {

    @Test("getContext returns the task-local override when set")
    func returnsOverride() async throws {
        let mock = MockChainContext(name: "MockUnderTest", type: .online, networkId: .mainnet)
        try await Contexts.$override.withValue(mock) {
            let cfg = MultitoolConfig(
                tokenMetaServer: TokenMetaServerURLs(),
                adaHandlePolicy: AdaHandlePolicyIds()
            )
            let context = try await getContext(config: cfg)
            #expect(context.name == "MockUnderTest")
            #expect(context.networkId == .mainnet)
        }
    }

    @Test("getContext clears the override outside withValue scope")
    func overrideScopedToWithValue() async throws {
        // Sanity: with no override set, getContext goes through real-config logic.
        // We don't run that real logic here (it requires cardano-cli/network), but
        // confirm the override is nil after the withValue scope exits.
        let mock = MockChainContext(name: "Inside", type: .offline, networkId: .testnet)
        Contexts.$override.withValue(mock) {
            #expect(Contexts.override?.name == "Inside")
        }
        #expect(Contexts.override == nil)
    }

    @Test("mock epoch stub is observable through the override")
    func mockEpochStubVisible() async throws {
        let mock = MockChainContext()
        mock.stubEpoch = { 482 }
        try await Contexts.$override.withValue(mock) {
            let cfg = MultitoolConfig(
                tokenMetaServer: TokenMetaServerURLs(),
                adaHandlePolicy: AdaHandlePolicyIds()
            )
            let context = try await getContext(config: cfg)
            let epoch = try await context.epoch()
            #expect(epoch == 482)
        }
    }
}
