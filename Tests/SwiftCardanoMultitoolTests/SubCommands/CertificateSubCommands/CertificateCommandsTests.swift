import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Smoke tests for all CertificateMainCommand subcommands.
///
/// These commands build certificate files and optionally submit transactions, both
/// requiring real key files and chain state. The smoke tests here verify each
/// command's argument-parser configuration is well-formed. Deeper behavior coverage
/// would need key-file fixtures and a `MockChainContext`.
@Suite("CertificateMainCommand smoke tests")
struct CertificateCommandsTests {

    @Test("AuthCommitteeHotCertificate: commandName 'auth-committee-hot'")
    func authCommitteeHot() {
        #expect(CertificateMainCommand.AuthCommitteeHotCertificate.configuration.commandName == "auth-committee-hot")
        _ = try? CertificateMainCommand.AuthCommitteeHotCertificate.parse([])
    }

    @Test("GenesisKeyDelegationCertificate: commandName 'genesis-key-delegation'")
    func genesisKeyDelegation() {
        #expect(CertificateMainCommand.GenesisKeyDelegationCertificate.configuration.commandName == "genesis-key-delegation")
        _ = try? CertificateMainCommand.GenesisKeyDelegationCertificate.parse([])
    }

    @Test("RegisterDRepCertificate: commandName 'register-drep'")
    func registerDRep() {
        #expect(CertificateMainCommand.RegisterDRepCertificate.configuration.commandName == "register-drep")
        _ = try? CertificateMainCommand.RegisterDRepCertificate.parse([])
    }

    @Test("UnRegisterDRepCertificate: commandName 'unregister-drep'")
    func unregisterDRep() {
        #expect(CertificateMainCommand.UnRegisterDRepCertificate.configuration.commandName == "unregister-drep")
        _ = try? CertificateMainCommand.UnRegisterDRepCertificate.parse([])
    }

    @Test("UpdateDRepCertificate: commandName 'update-drep'")
    func updateDRep() {
        #expect(CertificateMainCommand.UpdateDRepCertificate.configuration.commandName == "update-drep")
        _ = try? CertificateMainCommand.UpdateDRepCertificate.parse([])
    }

    @Test("ResignCommitteeColdCertificate: commandName 'resign-committee-cold'")
    func resignCommitteeCold() {
        #expect(CertificateMainCommand.ResignCommitteeColdCertificate.configuration.commandName == "resign-committee-cold")
        _ = try? CertificateMainCommand.ResignCommitteeColdCertificate.parse([])
    }

    @Test("MoveInstantaneousRewardsCertificate: commandName 'move-instantaneous-rewards'")
    func moveInstantaneousRewards() {
        #expect(CertificateMainCommand.MoveInstantaneousRewardsCertificate.configuration.commandName == "move-instantaneous-rewards")
        _ = try? CertificateMainCommand.MoveInstantaneousRewardsCertificate.parse([])
    }

    @Test("StakeAddressRegistrationCertificate: commandName 'stake-address-registration'")
    func stakeAddressRegistration() {
        #expect(CertificateMainCommand.StakeAddressRegistrationCertificate.configuration.commandName == "stake-address-registration")
        _ = try? CertificateMainCommand.StakeAddressRegistrationCertificate.parse([])
    }

    @Test("StakeAddressDeregistrationCertificate: commandName 'stake-address-deregistration'")
    func stakeAddressDeregistration() {
        #expect(CertificateMainCommand.StakeAddressDeregistrationCertificate.configuration.commandName == "stake-address-deregistration")
        _ = try? CertificateMainCommand.StakeAddressDeregistrationCertificate.parse([])
    }

    @Test("StakeAddressDelegationCertificate: commandName 'stake-address-delegation'")
    func stakeAddressDelegation() {
        #expect(CertificateMainCommand.StakeAddressDelegationCertificate.configuration.commandName == "stake-address-delegation")
        _ = try? CertificateMainCommand.StakeAddressDelegationCertificate.parse([])
    }

    @Test("StakePoolRegistrationCertificate: commandName 'pool-registration'")
    func stakePoolRegistration() {
        #expect(CertificateMainCommand.StakePoolRegistrationCertificate.configuration.commandName == "pool-registration")
        _ = try? CertificateMainCommand.StakePoolRegistrationCertificate.parse([])
    }

    @Test("StakePoolDeregistrationCertificate: commandName 'pool-deregistration'")
    func stakePoolDeregistration() {
        #expect(CertificateMainCommand.StakePoolDeregistrationCertificate.configuration.commandName == "pool-deregistration")
        _ = try? CertificateMainCommand.StakePoolDeregistrationCertificate.parse([])
    }

    @Test("VoteDelegationCertificate: commandName 'vote-delegation'")
    func voteDelegation() {
        #expect(CertificateMainCommand.VoteDelegationCertificate.configuration.commandName == "vote-delegation")
        _ = try? CertificateMainCommand.VoteDelegationCertificate.parse([])
    }

    @Test("StakeVoteDelegateCertificate: commandName 'stake-vote-delegation'")
    func stakeVoteDelegate() {
        #expect(CertificateMainCommand.StakeVoteDelegateCertificate.configuration.commandName == "stake-vote-delegation")
        _ = try? CertificateMainCommand.StakeVoteDelegateCertificate.parse([])
    }

    @Test("StakeRegisterDelegateCertificate: commandName 'stake-register-delegation'")
    func stakeRegisterDelegate() {
        #expect(CertificateMainCommand.StakeRegisterDelegateCertificate.configuration.commandName == "stake-register-delegation")
        _ = try? CertificateMainCommand.StakeRegisterDelegateCertificate.parse([])
    }

    @Test("VoteRegisterDelegateCertificate: commandName 'vote-register-delegation'")
    func voteRegisterDelegate() {
        #expect(CertificateMainCommand.VoteRegisterDelegateCertificate.configuration.commandName == "vote-register-delegation")
        _ = try? CertificateMainCommand.VoteRegisterDelegateCertificate.parse([])
    }

    @Test("StakeVoteRegisterDelegateCertificate: commandName 'stake-vote-register-delegation'")
    func stakeVoteRegisterDelegate() {
        #expect(CertificateMainCommand.StakeVoteRegisterDelegateCertificate.configuration.commandName == "stake-vote-register-delegation")
        _ = try? CertificateMainCommand.StakeVoteRegisterDelegateCertificate.parse([])
    }
}
