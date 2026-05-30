import Foundation
import SwiftCardanoChain
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

/// Test-only `ChainContext` conformer whose responses are supplied per-instance.
///
/// `ChainContext` provides default `notImplemented` implementations for every method
/// in a public extension, so tests only need to override the calls they care about.
/// Use the closure properties (`stubXxx`) to script the responses; unset closures
/// inherit the protocol's default-throws behavior.
///
/// Install via `Contexts.$override.withValue(MockChainContext(...)) { ... }`.
public final class MockChainContext: ChainContext, @unchecked Sendable {

    public let name: String
    public let type: ContextType
    public let networkId: NetworkId

    public var stubEpoch: (@Sendable () throws -> Int)?
    public var stubEra: (@Sendable () throws -> Era?)?
    public var stubLastBlockSlot: (@Sendable () throws -> Int)?
    public var stubProtocolParameters: (@Sendable () throws -> ProtocolParameters)?
    public var stubGenesisParameters: (@Sendable () throws -> GenesisParameters)?

    public init(
        name: String = "Mock",
        type: ContextType = .online,
        networkId: NetworkId = .testnet
    ) {
        self.name = name
        self.type = type
        self.networkId = networkId
    }

    public func protocolParameters() async throws -> ProtocolParameters {
        guard let stub = stubProtocolParameters else {
            throw CardanoChainError.notImplemented("MockChainContext.protocolParameters: no stub set")
        }
        return try stub()
    }

    public func genesisParameters() async throws -> GenesisParameters {
        guard let stub = stubGenesisParameters else {
            throw CardanoChainError.notImplemented("MockChainContext.genesisParameters: no stub set")
        }
        return try stub()
    }

    public func epoch() async throws -> Int {
        guard let stub = stubEpoch else {
            throw CardanoChainError.notImplemented("MockChainContext.epoch: no stub set")
        }
        return try stub()
    }

    public func era() async throws -> Era? {
        guard let stub = stubEra else {
            throw CardanoChainError.notImplemented("MockChainContext.era: no stub set")
        }
        return try stub()
    }

    public func lastBlockSlot() async throws -> Int {
        guard let stub = stubLastBlockSlot else {
            throw CardanoChainError.notImplemented("MockChainContext.lastBlockSlot: no stub set")
        }
        return try stub()
    }
}
