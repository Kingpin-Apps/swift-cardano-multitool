import ArgumentParser
import Foundation
import Logging
import SwiftCardanoCore
import SwiftCardanoUtils
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("getCardanoConfig")
struct ScriptUtilsGetCardanoConfigTests {

    @Test("throws ExitCode.failure when cardano section is missing")
    func throwsWhenCardanoMissing() {
        let cfg = MultitoolConfig(
            cardano: nil,
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds()
        )
        #expect(throws: ExitCode.self) {
            _ = try getCardanoConfig(config: cfg)
        }
    }
}

@Suite("healthyKupoURL")
struct ScriptUtilsHealthyKupoURLTests {

    let logger = Logger(label: "test")

    @Test("returns nil without a [kupo] block")
    func nilWithoutConfig() async {
        #expect(await healthyKupoURL(config: nil, logger: logger) == nil)
    }

    @Test("returns nil when [kupo] has no port")
    func nilWithoutPort() async {
        #expect(await healthyKupoURL(config: KupoConfig(host: "localhost"), logger: logger) == nil)
    }

    @Test("returns nil when nothing answers on the port")
    func nilWhenUnreachable() async {
        // Port 9 (discard) is closed on a normal machine, so the connection is refused at once.
        let config = KupoConfig(host: "127.0.0.1", port: 9)
        #expect(await healthyKupoURL(config: config, logger: logger) == nil)
    }
}

@Suite("Signing without chain data")
struct ScriptUtilsSigningTests {

    // An unsigned `Tx ConwayEra` from `cardano-cli conway transaction build-raw`,
    // and the same tx signed by `cardano-cli conway transaction sign` 11.2.3
    // with a key of 32 0x01 bytes.
    let unsignedTx = "84a300d9010281825820000000000000000000000000000000000000000000000000000000000000000000018182581d60db3d5712207e0414a33726120ec4cd6146dcaa7fedb9bcb55727136d1a000f4240021a00030d40a0f5f6"
    let cliSignedTx = "84a300d9010281825820000000000000000000000000000000000000000000000000000000000000000000018182581d60db3d5712207e0414a33726120ec4cd6146dcaa7fedb9bcb55727136d1a000f4240021a00030d40a100d90102818258208a88e3dd7409f195fd52db2d3cba5d72ca6709bf1d94121bf3748801b40f6f5c5840a24715f5204364ba318bebfecfeeae2c244f1c8e6e74fb5ce034b9d0d051c502b3d2766b7a29f110ee92ed16835e1d92c442a1f99d42ab3fe8a3046a4c68fd03f5f6"
    let key = SigningKeyType.signingKey(try! PaymentSigningKey(payload: Data(repeating: 0x01, count: 32)))

    @Test("offline mode gives no context and never reads the offline file")
    func offlineModeHasNoContext() async throws {
        let cfg = MultitoolConfig(
            mode: .offline,
            offlineFile: FilePath("/nonexistent/offline-transfer.json"),
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds()
        )
        #expect(try await getSigningContext(config: cfg) == nil)
    }

    @Test("witnessing and assembling match cardano-cli's signed tx")
    func matchesCardanoCli() throws {
        let tx = try Transaction.fromCBORHex(unsignedTx)
        let witnesses = try witnessTransaction(tx, keys: [key])
        let signed = assembleTransaction(tx, vkeyWitnesses: witnesses)

        #expect(try signed.toCBORHex() == cliSignedTx)
    }

    @Test("assembling keeps the witnesses already on the tx")
    func keepsExistingWitnesses() throws {
        let tx = try Transaction.fromCBORHex(cliSignedTx)
        let other = SigningKeyType.signingKey(try PaymentSigningKey(payload: Data(repeating: 0x02, count: 32)))
        let signed = assembleTransaction(tx, vkeyWitnesses: try witnessTransaction(tx, keys: [other]))

        #expect(signed.transactionWitnessSet.vkeyWitnesses?.asList.count == 2)
    }
}
