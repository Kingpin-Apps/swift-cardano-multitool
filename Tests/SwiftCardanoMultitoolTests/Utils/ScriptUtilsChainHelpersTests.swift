import Foundation
import Testing
import SwiftCardanoChain
import SwiftCardanoCore
import SwiftCardanoUtils
@testable import SwiftCardanoMultitool

/// Tests for `Utils/ScriptUtils.swift` helpers that wrap individual `ChainContext`
/// methods. The point is to exercise the success branches via stubs on
/// `MockChainContext`, including the side-effects (prints, file writes) we can
/// safely ignore. Functions that require a real `CardanoCLI` subprocess or
/// full `ProtocolParameters` round-trip are out of scope.

// MARK: - queryChainState

@Suite("ScriptUtils.queryChainState")
struct QueryChainStateTests {

    @Test("returns (tip, tip + ttlBuffer) when the chain stub provides a slot")
    func happyPath() async throws {
        let cfg = TestConfigs.make() // ttlBuffer = 1000 (TestConfigs default)
        let mock = MockChainContext(name: "Test", type: .online, networkId: .mainnet)
        mock.stubLastBlockSlot = { 50_000_000 }

        let (tip, ttl) = try await queryChainState(context: mock, config: cfg)
        #expect(tip == 50_000_000)
        #expect(ttl == 50_001_000) // tip + 1000
    }

    @Test("propagates chain errors when lastBlockSlot throws")
    func propagatesChainError() async {
        struct Boom: Error {}
        let cfg = TestConfigs.make()
        let mock = MockChainContext(name: "Test", type: .online, networkId: .mainnet)
        mock.stubLastBlockSlot = { throw Boom() }

        await #expect(throws: (any Error).self) {
            _ = try await queryChainState(context: mock, config: cfg)
        }
    }

    @Test("ttlBuffer comes from the cardano config")
    func ttlBufferFromConfig() async throws {
        let cardano = CardanoConfig(network: .mainnet, era: .conway, ttlBuffer: 5_000)
        let cfg = MultitoolConfig(
            cardano: cardano,
            mode: .online,
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds(),
            logLevel: .error
        )
        let mock = MockChainContext(name: "Test", type: .online, networkId: .mainnet)
        mock.stubLastBlockSlot = { 100 }

        let (tip, ttl) = try await queryChainState(context: mock, config: cfg)
        #expect(tip == 100)
        #expect(ttl == 5_100)
    }
}

// MARK: - displayChainInfo

@Suite("ScriptUtils.displayChainInfo")
struct DisplayChainInfoTests {

    @Test("prints chain info using the mocked epoch")
    func happyPath() async throws {
        let mock = MockChainContext(name: "Test", type: .online, networkId: .mainnet)
        mock.stubEpoch = { 500 }
        // Function prints; no return value to assert. Confirm it doesn't throw.
        try await displayChainInfo(context: mock, tip: 100, ttl: 1_100)
    }

    @Test("throws when the epoch stub throws")
    func propagatesEpochError() async {
        struct Boom: Error {}
        let mock = MockChainContext(name: "Test", type: .online, networkId: .mainnet)
        mock.stubEpoch = { throw Boom() }
        await #expect(throws: (any Error).self) {
            try await displayChainInfo(context: mock, tip: 0, ttl: 0)
        }
    }
}

// MARK: - getVersionAndInfoText

@Suite("ScriptUtils.getVersionAndInfoText")
struct GetVersionAndInfoTextTests {

    @Test("mainnet config produces a success-styled mainnet label")
    func mainnet() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        let (version, _) = try await getVersionAndInfoText(config: cfg)
        #expect(version == Version.number)
    }

    @Test("a named testnet (preprod) returns a version + info text without throwing")
    func preprod() async throws {
        let cfg = TestConfigs.make(network: .preprod)
        let (version, _) = try await getVersionAndInfoText(config: cfg)
        #expect(version == Version.number)
    }

    @Test("preview testnet returns a version + info text without throwing")
    func preview() async throws {
        let cfg = TestConfigs.make(network: .preview)
        let (_, _) = try await getVersionAndInfoText(config: cfg)
    }

    @Test("throws when the config is missing a cardano section")
    func throwsWhenMissingCardano() async {
        let cfg = MultitoolConfig(
            cardano: nil,
            mode: .online,
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds(),
            logLevel: .error
        )
        await #expect(throws: (any Error).self) {
            _ = try await getVersionAndInfoText(config: cfg)
        }
    }
}

// MARK: - printContextInfo

@Suite("ScriptUtils.printContextInfo")
struct PrintContextInfoTests {

    @Test("non-cardano-cli context: prints info without throwing")
    func nonCardanoCLIPath() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext(name: "MockCtx", type: .online, networkId: .mainnet)
        // Mock context is NOT a CardanoCliChainContext so the heavy CLI branch is skipped.
        try await printContextInfo(config: cfg, context: mock)
    }

    @Test("nil context: prints 'No Chain Context' takeaway without throwing")
    func nilContextPath() async throws {
        let cfg = TestConfigs.make()
        try await printContextInfo(config: cfg, context: nil)
    }

    @Test("throws when the config is missing a cardano section")
    func throwsOnMissingCardanoConfig() async {
        let cfg = MultitoolConfig(
            cardano: nil,
            mode: .online,
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds(),
            logLevel: .error
        )
        await #expect(throws: (any Error).self) {
            try await printContextInfo(config: cfg)
        }
    }
}

// MARK: - getCardanoConfig

@Suite("ScriptUtils.getCardanoConfig")
struct GetCardanoConfigTests {

    @Test("returns the cardano section when present")
    func happyPath() throws {
        let cfg = TestConfigs.make()
        let cardano = try getCardanoConfig(config: cfg)
        #expect(cardano.network == .mainnet)
    }

    @Test("throws when the cardano section is nil")
    func throwsWhenMissing() {
        let cfg = MultitoolConfig(
            cardano: nil,
            mode: .online,
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds(),
            logLevel: .error
        )
        #expect(throws: (any Error).self) {
            _ = try getCardanoConfig(config: cfg)
        }
    }
}
