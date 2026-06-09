import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("RunMainCommand.Wallet --mainnet flag")
struct RunWalletTests {

    @Test("--mainnet flag flips the bool")
    func parsesMainnetFlag() throws {
        let cmd = try RunMainCommand.Wallet.parse(["--mainnet"])
        #expect(cmd.mainnet == true)
    }
}
