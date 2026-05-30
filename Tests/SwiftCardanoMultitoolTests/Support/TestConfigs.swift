import Foundation
import SwiftCardanoCore
import SwiftCardanoUtils
@testable import SwiftCardanoMultitool

/// Builds a `MultitoolConfig` suitable for use in unit tests via `Configs.$override`.
///
/// SubCommand tests typically need a config whose `cardano` section is populated
/// (because `printContextInfo` / `getCardanoConfig` throw otherwise). This helper
/// produces a fully-formed config with sensible defaults that can be tweaked.
public enum TestConfigs {

    public static func make(
        network: Network = .mainnet,
        era: Era = .conway,
        mode: Mode = .online
    ) -> MultitoolConfig {
        let cardano = CardanoConfig(
            network: network,
            era: era,
            ttlBuffer: 1000
        )
        return MultitoolConfig(
            cardano: cardano,
            mode: mode,
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds(),
            logLevel: .error
        )
    }
}
