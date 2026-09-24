import Foundation
import SwiftCardanoChain
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("TransactionMainCommand.RewardsWithdraw")
struct RewardsWithdrawTests {

    private static let stakeAddress = "stake_test1upyz3gk6mw5he20apnwfn96cn9rscgvmmsxc9r86dh0k66gswf59n"

    private func stakeInfo(file: FilePath?) throws -> AddressInfo {
        let address = try AddressInfo(fromAddressString: Self.stakeAddress).address
        return try AddressInfo(addressFile: file, name: file == nil ? "owner" : nil, address: address)
    }

    @Test("claim-to-self payment file sits next to an absolute stake address file")
    func paymentFileNextToAbsoluteStakeFile() throws {
        let info = try stakeInfo(file: FilePath("/keys/owner.stake.addr"))
        let paymentFile = TransactionMainCommand.RewardsWithdraw.claimToSelfPaymentFile(for: info)
        #expect(paymentFile == FilePath("/keys/owner.payment.addr"))
    }

    @Test("claim-to-self payment file resolves under cwd for a relative stake address file")
    func paymentFileUnderCwdForRelativeStakeFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-rewards-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try WorkingDirectory.withCurrent(dir.path) {
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let info = try stakeInfo(file: FilePath("owner.stake.addr"))
            let paymentFile = TransactionMainCommand.RewardsWithdraw.claimToSelfPaymentFile(for: info)
            #expect(paymentFile == cwd.appending("owner.payment.addr"))
        }
    }

    @Test("claim-to-self payment file falls back to cwd when there is no stake address file")
    func paymentFileUnderCwdWithoutStakeFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-rewards-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try WorkingDirectory.withCurrent(dir.path) {
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let info = try stakeInfo(file: nil)
            let paymentFile = TransactionMainCommand.RewardsWithdraw.claimToSelfPaymentFile(for: info)
            #expect(paymentFile == cwd.appending("owner.payment.addr"))
        }
    }
}
