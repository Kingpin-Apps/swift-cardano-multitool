import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Parse-level tests for a representative subset of `certificate` subcommands.
///
/// These verify the registered command names, the credential/argument binding, and the
/// shared `SharedCertificateOptions` / `SharedTransactionOptions` flag wiring (out-file,
/// generate-transaction, fee-payment-address, save inversion, submit). `run()` needs a
/// chain context, protocol parameters, and on-disk key files, and `wizardForCertificate`
/// prompts via the global `noora` (not the injectable `Prompts.current`), so neither is
/// exercised here. Enum→type dispatch is covered by `CommandDispatchTests`.

private let hexHash = String(repeating: "ab", count: 28)

@Suite("CertificateMainCommand.StakeAddressRegistrationCertificate")
struct StakeAddressRegistrationParseTests {

    @Test("commandName is stake-address-registration")
    func commandName() {
        #expect(
            CertificateMainCommand.StakeAddressRegistrationCertificate.configuration.commandName
                == "stake-address-registration"
        )
    }

    @Test("shared certificate + transaction flags parse")
    func sharedFlagsParse() throws {
        let cmd = try CertificateMainCommand.StakeAddressRegistrationCertificate.parse([
            "--out-file", "owner.stake.cert",
            "--generate-transaction",
            "--no-save",
        ])
        #expect(cmd.certificateOptions.outFile?.string == "owner.stake.cert")
        #expect(cmd.certificateOptions.generateTransaction == true)
        #expect(cmd.transactionOptions.save == false)
    }

    @Test("defaults: generate-transaction off, save on, submit off")
    func defaults() throws {
        let cmd = try CertificateMainCommand.StakeAddressRegistrationCertificate.parse([])
        #expect(cmd.certificateOptions.generateTransaction == false)
        #expect(cmd.transactionOptions.save == true)
        #expect(cmd.transactionOptions.submit == false)
    }
}

@Suite("CertificateMainCommand.RegisterDRepCertificate")
struct RegisterDRepParseTests {

    @Test("commandName is register-drep")
    func commandName() {
        #expect(
            CertificateMainCommand.RegisterDRepCertificate.configuration.commandName == "register-drep"
        )
    }

    @Test("--drep-credential accepts a hex hash")
    func drepCredentialParses() throws {
        let cmd = try CertificateMainCommand.RegisterDRepCertificate.parse([
            "--drep-credential", hexHash,
        ])
        #expect(cmd.drepCredential != nil)
    }

    @Test("--submit flag flips submit to true")
    func submitFlag() throws {
        let cmd = try CertificateMainCommand.RegisterDRepCertificate.parse(["--submit"])
        #expect(cmd.transactionOptions.submit == true)
    }
}

@Suite("CertificateMainCommand.AuthCommitteeHotCertificate")
struct AuthCommitteeHotParseTests {

    @Test("commandName is auth-committee-hot")
    func commandName() {
        #expect(
            CertificateMainCommand.AuthCommitteeHotCertificate.configuration.commandName
                == "auth-committee-hot"
        )
    }

    @Test("cold and hot credentials both accept hex hashes")
    func bothCredentialsParse() throws {
        let cmd = try CertificateMainCommand.AuthCommitteeHotCertificate.parse([
            "--committee-cold-credential", hexHash,
            "--committee-hot-credential", hexHash,
        ])
        #expect(cmd.committeeColdCredential != nil)
        #expect(cmd.committeeHotCredential != nil)
    }
}

@Suite("CertificateMainCommand.StakePoolRegistrationCertificate on-chain edits")
struct StakePoolRegistrationOnChainParseTests {

    @Test("edit flags parse with --pool-operator")
    func editFlagsParse() throws {
        let cmd = try CertificateMainCommand.StakePoolRegistrationCertificate.parse([
            "--pool-operator", String(repeating: "77", count: 28),
            "--pledge", "2K",
            "--cost", "340",
            "--margin", "1.5%",
            "--relay", "dns:relay.example.com:3001",
            "--relay", "srv:_cardano._tcp.example.com",
            "--owner", String(repeating: "4f", count: 28),
            "--reward-account", String(repeating: "4f", count: 28),
            "--metadata-url", "https://example.com/pool.json",
            "--metadata-hash", String(repeating: "ab", count: 32),
        ])
        #expect(cmd.poolOperator != nil)
        #expect(cmd.relays.count == 2)
        #expect(cmd.owners.count == 1)
        #expect(cmd.rewardAccount != nil)
    }

    @Test("edit flags require --pool-operator")
    func editFlagsRequirePoolOperator() {
        #expect(throws: (any Error).self) {
            _ = try CertificateMainCommand.StakePoolRegistrationCertificate.parse([
                "--pool-name", "mypool",
                "--pledge", "2K",
            ])
        }
    }

    @Test("invalid margin and half-set metadata are rejected")
    func rejectsInvalidValues() {
        let pool = String(repeating: "77", count: 28)
        #expect(throws: (any Error).self) {
            _ = try CertificateMainCommand.StakePoolRegistrationCertificate.parse(["--pool-operator", pool, "--margin", "150%"])
        }
        #expect(throws: (any Error).self) {
            _ = try CertificateMainCommand.StakePoolRegistrationCertificate.parse(["--pool-operator", pool, "--metadata-hash", String(repeating: "ab", count: 32)])
        }
    }
}

@Suite("CertificateMainCommand.StakePoolDeregistrationCertificate")
struct StakePoolDeregistrationParseTests {

    @Test("commandName is pool-deregistration")
    func commandName() {
        #expect(
            CertificateMainCommand.StakePoolDeregistrationCertificate.configuration.commandName
                == "pool-deregistration"
        )
    }

    @Test("--pool-name and --epoch parse")
    func poolNameAndEpoch() throws {
        let cmd = try CertificateMainCommand.StakePoolDeregistrationCertificate.parse([
            "--pool-name", "mypool",
            "--epoch", "500",
        ])
        #expect(cmd.poolName == "mypool")
        #expect(cmd.epoch != nil)
    }

    @Test("--pool-operator and --cold-signing-key parse without a pool.json")
    func poolOperatorAndColdSigningKey() throws {
        let cmd = try CertificateMainCommand.StakePoolDeregistrationCertificate.parse([
            "--pool-operator", String(repeating: "ab", count: 28),
            "--cold-signing-key", "mypool.node.skey",
            "--generate-transaction",
            "--fee-payment-address", "addr_test1vr2p8st5t5cxqglyjky7vk98k7jtfhdpvhl4e97cezuhn0cqcexl7",
        ])
        #expect(cmd.poolOperator != nil)
        #expect(cmd.poolName == nil)
        #expect(cmd.poolJSON == nil)
        #expect(cmd.coldSigningKey?.string == "mypool.node.skey")
        #expect(cmd.certificateOptions.generateTransaction)
    }
}
