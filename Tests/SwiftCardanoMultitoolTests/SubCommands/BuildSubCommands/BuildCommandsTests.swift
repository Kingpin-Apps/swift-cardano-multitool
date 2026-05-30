import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("BuildMainCommand.PaymentAddress")
struct BuildPaymentAddressTests {

    @Test("aliases include 'payment'")
    func aliasPayment() {
        #expect(BuildMainCommand.PaymentAddress.configuration.aliases.contains("payment"))
    }

    @Test("default parse leaves every option nil")
    func defaults() throws {
        let cmd = try BuildMainCommand.PaymentAddress.parse([])
        #expect(cmd.addressName == nil)
        #expect(cmd.stakeVkey == nil)
        #expect(cmd.paymentVkey == nil)
        #expect(cmd.tool == nil)
    }

    @Test("parses --address-name")
    func parsesAddressName() throws {
        let cmd = try BuildMainCommand.PaymentAddress.parse(["--address-name", "alice"])
        #expect(cmd.addressName == "alice")
    }

    @Test("parses --tool option")
    func parsesTool() throws {
        let cmd = try BuildMainCommand.PaymentAddress.parse(["--tool", "swiftcardano"])
        #expect(cmd.tool == .swiftCardano)
        let cmd2 = try BuildMainCommand.PaymentAddress.parse(["--tool", "cardano-cli"])
        #expect(cmd2.tool == .cardanoCLI)
    }
}

@Suite("BuildMainCommand.StakeAddress")
struct BuildStakeAddressTests {

    @Test("default parse leaves every option nil")
    func defaults() throws {
        let cmd = try BuildMainCommand.StakeAddress.parse([])
        #expect(cmd.addressName == nil)
        #expect(cmd.stakeVkey == nil)
        #expect(cmd.tool == nil)
    }

    @Test("parses --address-name and --stake-vkey")
    func parsesNamedOptions() throws {
        let cmd = try BuildMainCommand.StakeAddress.parse([
            "--address-name", "bob",
            "--stake-vkey", "/keys/bob.stake.vkey"
        ])
        #expect(cmd.addressName == "bob")
        #expect(cmd.stakeVkey?.string == "/keys/bob.stake.vkey")
    }
}
