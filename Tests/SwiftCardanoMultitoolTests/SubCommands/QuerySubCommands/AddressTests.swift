import ArgumentParser
import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Address")
struct QueryAddressTests {

    @Test("rejects garbage that doesn't resolve to an address")
    func rejectsGarbageAddress() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.Address.parse(["not_a_real_address_xyz"])
        }
    }

    @Test("run() on a payment address queries UTxOs and renders the summary")
    func runPaymentPath() async throws {
        // Base (payment) address — bech32 starts with "addr1", so AddressInfo.type == .payment.
        let addr = try ChainFixtures.makeAddress(seed: 0x11)
        let bech32 = try addr.toBech32()

        let mock = MockChainContext(name: "AddrCtx", type: .online, networkId: .mainnet)
        // The payment branch fetches UTxOs and feeds them to utxoSummary.
        mock.stubUtxos = { _ in [ChainFixtures.makeUTxO(address: addr, coin: 7_000_000)] }

        let cfg = TestConfigs.make(network: .mainnet)
        try await Configs.$override.withValue(cfg) {
            try await Contexts.$override.withValue(mock) {
                var cmd = try QueryMainCommand.Address.parse([bech32])
                try await cmd.run()
            }
        }
    }

    @Test("run() on a stake address fetches rewards info and protocol params")
    func runStakePath() async throws {
        // Reward (stake) address — bech32 starts with "stake1", so AddressInfo.type == .stake.
        let stakeHash = VerificationKeyHash(payload: Data(repeating: 0x22, count: 28))
        let stakeAddr = try Address(
            stakingPart: .verificationKeyHash(stakeHash),
            network: .mainnet
        )
        let bech32 = try stakeAddr.toBech32()

        let mock = MockChainContext(name: "StakeCtx", type: .online, networkId: .mainnet)
        // The stake branch fetches stake-address info, then protocol parameters for the summary.
        // A registered stake address keeps stakeAddressInfoSummary on its success path.
        let info = SwiftCardanoCore.StakeAddressInfo(
            active: true,
            address: try stakeAddr.toBech32(),
            rewardAccountBalance: 12_345_678,
            stakeDelegation: nil,
            stakeRegistrationDeposit: 2_000_000,
            voteDelegation: nil
        )
        mock.stubStakeAddressInfo = { _ in [info] }
        mock.stubProtocolParameters = { try TestFixtures.sampleProtocolParameters() }

        let cfg = TestConfigs.make(network: .mainnet)
        try await Configs.$override.withValue(cfg) {
            try await Contexts.$override.withValue(mock) {
                var cmd = try QueryMainCommand.Address.parse([bech32])
                try await cmd.run()
            }
        }
    }
}
