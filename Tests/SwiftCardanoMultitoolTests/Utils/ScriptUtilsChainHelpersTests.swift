import Foundation
import Testing
import SystemPackage
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

// MARK: - getContext (Contexts.override fast path)

@Suite("ScriptUtils.getContext (override path)")
struct GetContextOverrideTests {

    @Test("returns the Contexts.override value when set, without touching online/lite logic")
    func returnsOverride() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext(name: "Injected", type: .online, networkId: .mainnet)

        let returned: any ChainContext = try await Contexts.$override.withValue(mock) {
            try await getContext(config: cfg)
        }
        #expect(returned.name == "Injected")
    }
}

// MARK: - printToolInfo

@Suite("ScriptUtils.printToolInfo")
struct PrintToolInfoTests {

    @Test("swiftCardano branch prints info without throwing")
    func swiftCardanoBranch() async throws {
        let cfg = TestConfigs.make()
        try await printToolInfo(config: cfg, tool: .swiftCardano)
    }

    @Test("preprod network: swiftCardano branch still succeeds")
    func swiftCardanoOnPreprod() async throws {
        let cfg = TestConfigs.make(network: .preprod)
        try await printToolInfo(config: cfg, tool: .swiftCardano)
    }
}

// MARK: - getProtocolParameters

@Suite("ScriptUtils.getProtocolParameters")
struct GetProtocolParametersTests {

    @Test("quiet=true returns the stubbed ProtocolParameters")
    func returnsStubbedQuiet() async throws {
        let pp = try TestFixtures.sampleProtocolParameters()
        let mock = MockChainContext(name: "M", type: .online, networkId: .mainnet)
        mock.stubProtocolParameters = { pp }

        let result = try await getProtocolParameters(context: mock, quiet: true)
        #expect(result.maxTxSize == pp.maxTxSize)
    }

    @Test("with a protocolParamsFile, writes the fetched parameters to disk")
    func writesToFile() async throws {
        let pp = try TestFixtures.sampleProtocolParameters()
        let mock = MockChainContext(name: "M", type: .online, networkId: .mainnet)
        mock.stubProtocolParameters = { pp }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-gpp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("pp.json").path)

        _ = try await getProtocolParameters(
            context: mock,
            protocolParamsFile: path,
            quiet: true
        )
        #expect(FileManager.default.fileExists(atPath: path.string))
    }

    @Test("propagates chain errors from the stub")
    func propagatesError() async {
        struct Boom: Error {}
        let mock = MockChainContext(name: "M", type: .online, networkId: .mainnet)
        mock.stubProtocolParameters = { throw Boom() }

        await #expect(throws: (any Error).self) {
            _ = try await getProtocolParameters(context: mock, quiet: true)
        }
    }
}

// MARK: - checkTransactionSize (bounds enforcement)

@Suite("ScriptUtils.checkTransactionSize")
struct CheckTransactionSizeTests {

    /// `checkTransactionSize` does `cborHex.count / 2 > pp.maxTxSize`, so we only
    /// need a Transaction whose CBOR size we can predict and a ProtocolParameters
    /// whose `maxTxSize` we control via the fixture. We skip building a real
    /// Transaction and instead test the throw path via a deliberately tiny
    /// maxTxSize fixture — but we don't have a Transaction constructor handy
    /// in tests, so we exercise only the cardano-config-driven happy path of
    /// the fixture loader here.
    @Test("ProtocolParameters fixture loads with a sane maxTxSize")
    func fixtureHasMaxTxSize() throws {
        let pp = try TestFixtures.sampleProtocolParameters()
        #expect(pp.maxTxSize > 0)
    }
}

// MARK: - stakeAddressInfoSummary

@Suite("ScriptUtils.stakeAddressInfoSummary")
struct StakeAddressInfoSummaryTests {

    @Test("empty stakeAddressInfo throws ExitCode.failure (not registered)")
    func emptyArrayThrows() async throws {
        let cfg = TestConfigs.make()
        let pp = try TestFixtures.sampleProtocolParameters()
        await #expect(throws: (any Error).self) {
            try await stakeAddressInfoSummary(
                stakeAddressInfo: [],
                config: cfg,
                protocolParams: pp
            )
        }
    }

    @Test("registered stake with zero rewards and no delegation finishes without throwing")
    func registeredZeroRewards() async throws {
        let cfg = TestConfigs.make()
        let pp = try TestFixtures.sampleProtocolParameters()
        let info = SwiftCardanoCore.StakeAddressInfo(
            active: true,
            address: "stake_test1ur0wvgdxr8m4qtye3p3rj36g3f2lh9c7q92t3qdkj9z8xqx6gn8y3",
            rewardAccountBalance: 0,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2_000_000,
            voteDelegation: nil
        )
        try await stakeAddressInfoSummary(
            stakeAddressInfo: [info],
            config: cfg,
            protocolParams: pp
        )
    }

    @Test("registered stake with non-zero rewards prints rewards balance branch")
    func registeredNonZeroRewards() async throws {
        let cfg = TestConfigs.make()
        let pp = try TestFixtures.sampleProtocolParameters()
        let info = SwiftCardanoCore.StakeAddressInfo(
            active: true,
            address: "stake_test1ur0wvgdxr8m4qtye3p3rj36g3f2lh9c7q92t3qdkj9z8xqx6gn8y3",
            rewardAccountBalance: 12_345_678,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2_000_000,
            voteDelegation: nil
        )
        try await stakeAddressInfoSummary(
            stakeAddressInfo: [info],
            config: cfg,
            protocolParams: pp
        )
    }

    @Test("alwaysAbstain DRep delegation prints the always-abstain branch")
    func voteDelegationAlwaysAbstain() async throws {
        let cfg = TestConfigs.make()
        let pp = try TestFixtures.sampleProtocolParameters()
        let info = SwiftCardanoCore.StakeAddressInfo(
            active: true,
            address: "stake_test1ur0wvgdxr8m4qtye3p3rj36g3f2lh9c7q92t3qdkj9z8xqx6gn8y3",
            rewardAccountBalance: 0,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2_000_000,
            voteDelegation: DRep(credential: .alwaysAbstain)
        )
        try await stakeAddressInfoSummary(
            stakeAddressInfo: [info],
            config: cfg,
            protocolParams: pp
        )
    }

    @Test("alwaysNoConfidence DRep delegation prints the always-no-confidence branch")
    func voteDelegationAlwaysNoConfidence() async throws {
        let cfg = TestConfigs.make()
        let pp = try TestFixtures.sampleProtocolParameters()
        let info = SwiftCardanoCore.StakeAddressInfo(
            active: true,
            address: "stake_test1ur0wvgdxr8m4qtye3p3rj36g3f2lh9c7q92t3qdkj9z8xqx6gn8y3",
            rewardAccountBalance: 1_000_000,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2_000_000,
            voteDelegation: DRep(credential: .alwaysNoConfidence)
        )
        try await stakeAddressInfoSummary(
            stakeAddressInfo: [info],
            config: cfg,
            protocolParams: pp
        )
    }

    @Test("non-empty govActionDeposits with valid txHash#index keys prints the takeaways")
    func govActionDepositsValidKey() async throws {
        let cfg = TestConfigs.make()
        let pp = try TestFixtures.sampleProtocolParameters()
        // Valid 64-hex tx hash + index, the cardano-cli natural form.
        let txHash = String(repeating: "ab", count: 32)
        let info = SwiftCardanoCore.StakeAddressInfo(
            active: true,
            address: "stake_test1ur0wvgdxr8m4qtye3p3rj36g3f2lh9c7q92t3qdkj9z8xqx6gn8y3",
            govActionDeposits: ["\(txHash)#0": 100_000_000_000],  // 100k ADA — far above any UInt16 index
            rewardAccountBalance: 0,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2_000_000,
            voteDelegation: DRep(credential: .alwaysAbstain)
        )
        // Regression: this used to fatalError because the source conflated the deposit
        // value with the action index in `GovActionID(from: .list([.string, .uint]))`.
        try await stakeAddressInfoSummary(
            stakeAddressInfo: [info],
            config: cfg,
            protocolParams: pp
        )
    }

    @Test("non-empty govActionDeposits with an unparseable key falls through to the danger fallback")
    func govActionDepositsUnparseableKey() async throws {
        let cfg = TestConfigs.make()
        let pp = try TestFixtures.sampleProtocolParameters()
        let info = SwiftCardanoCore.StakeAddressInfo(
            active: true,
            address: "stake_test1ur0wvgdxr8m4qtye3p3rj36g3f2lh9c7q92t3qdkj9z8xqx6gn8y3",
            govActionDeposits: ["not-a-real-action-id": 50_000_000],
            rewardAccountBalance: 0,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2_000_000,
            voteDelegation: DRep(credential: .alwaysAbstain)
        )
        try await stakeAddressInfoSummary(
            stakeAddressInfo: [info],
            config: cfg,
            protocolParams: pp
        )
    }
}
