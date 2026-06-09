import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Regression guards for the `command()` dispatch tables that map a menu enum case to
/// the concrete subcommand type. These tables are hand-written switch statements where a
/// copy-paste slip silently routes a case to the wrong command — exactly the
/// `poolDeregistration -> StakePoolRegistrationCertificate` bug fixed earlier. Comparing
/// metatype identity here catches that class of mistake directly at the source.

private func sameType(_ lhs: any AsyncParsableCommand.Type, _ rhs: any AsyncParsableCommand.Type) -> Bool {
    ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}

@Suite("CertificateCommands.command() dispatch")
struct CertificateCommandsDispatchTests {

    @Test("every case maps to its expected certificate command type")
    func eachCaseMapsCorrectly() {
        #expect(sameType(CertificateCommands.stakeRegistration.command(), CertificateMainCommand.StakeAddressRegistrationCertificate.self))
        #expect(sameType(CertificateCommands.stakeDelegation.command(), CertificateMainCommand.StakeAddressDelegationCertificate.self))
        #expect(sameType(CertificateCommands.stakeDeregistration.command(), CertificateMainCommand.StakeAddressDeregistrationCertificate.self))
        // The pool (de)registration pair is the original regression: they were swapped.
        #expect(sameType(CertificateCommands.poolRegistration.command(), CertificateMainCommand.StakePoolRegistrationCertificate.self))
        #expect(sameType(CertificateCommands.poolDeregistration.command(), CertificateMainCommand.StakePoolDeregistrationCertificate.self))
        #expect(sameType(CertificateCommands.genesisKeyDelegation.command(), CertificateMainCommand.GenesisKeyDelegationCertificate.self))
        #expect(sameType(CertificateCommands.moveInstantaneousRewards.command(), CertificateMainCommand.MoveInstantaneousRewardsCertificate.self))
        #expect(sameType(CertificateCommands.voteDelegate.command(), CertificateMainCommand.VoteDelegationCertificate.self))
        #expect(sameType(CertificateCommands.stakeVoteDelegate.command(), CertificateMainCommand.StakeVoteDelegateCertificate.self))
        #expect(sameType(CertificateCommands.stakeRegisterDelegate.command(), CertificateMainCommand.StakeRegisterDelegateCertificate.self))
        #expect(sameType(CertificateCommands.voteRegisterDelegate.command(), CertificateMainCommand.VoteRegisterDelegateCertificate.self))
        #expect(sameType(CertificateCommands.stakeVoteRegisterDelegate.command(), CertificateMainCommand.StakeVoteRegisterDelegateCertificate.self))
        #expect(sameType(CertificateCommands.authCommitteeHot.command(), CertificateMainCommand.AuthCommitteeHotCertificate.self))
        #expect(sameType(CertificateCommands.resignCommitteeCold.command(), CertificateMainCommand.ResignCommitteeColdCertificate.self))
        #expect(sameType(CertificateCommands.registerDRep.command(), CertificateMainCommand.RegisterDRepCertificate.self))
        #expect(sameType(CertificateCommands.unRegisterDRep.command(), CertificateMainCommand.UnRegisterDRepCertificate.self))
        #expect(sameType(CertificateCommands.updateDRep.command(), CertificateMainCommand.UpdateDRepCertificate.self))
    }

    @Test("back and exit route to the menu/exit commands")
    func navigationCases() {
        #expect(sameType(CertificateCommands.back.command(), MainMenuCommand.self))
        #expect(sameType(CertificateCommands.exit.command(), ExitCommand.self))
    }

    @Test("the 17 certificate commands are all distinct types")
    func certificateTypesAreDistinct() {
        let certCases: [CertificateCommands] = [
            .stakeRegistration, .stakeDelegation, .stakeDeregistration,
            .poolRegistration, .poolDeregistration, .genesisKeyDelegation,
            .moveInstantaneousRewards, .voteDelegate, .stakeVoteDelegate,
            .stakeRegisterDelegate, .voteRegisterDelegate, .stakeVoteRegisterDelegate,
            .authCommitteeHot, .resignCommitteeCold, .registerDRep,
            .unRegisterDRep, .updateDRep,
        ]
        let ids = Set(certCases.map { ObjectIdentifier($0.command()) })
        #expect(ids.count == certCases.count)
    }
}

@Suite("GenerateCommands.command() dispatch")
struct GenerateCommandsDispatchTests {

    @Test("every case maps to its expected generate command type")
    func eachCaseMapsCorrectly() {
        #expect(sameType(GenerateCommands.nodeColdKeys.command(), GenerateMainCommand.NodeColdKeys.self))
        #expect(sameType(GenerateCommands.nodeKesKeys.command(), GenerateMainCommand.NodeKESKeys.self))
        #expect(sameType(GenerateCommands.nodeVrfKeys.command(), GenerateMainCommand.NodeVRFKeys.self))
        #expect(sameType(GenerateCommands.nodeOperationalCertificate.command(), GenerateMainCommand.NodeOperationalCertificate.self))
        #expect(sameType(GenerateCommands.paymentAddressOnly.command(), GenerateMainCommand.PaymentAddressOnly.self))
        #expect(sameType(GenerateCommands.paymentAndStakeAddress.command(), GenerateMainCommand.PaymentAndStakeAddress.self))
        #expect(sameType(GenerateCommands.keyRotation.command(), GenerateMainCommand.KeyRotation.self))
        #expect(sameType(GenerateCommands.poolJSON.command(), GenerateMainCommand.PoolJSON.self))
        #expect(sameType(GenerateCommands.dRep.command(), GenerateMainCommand.DRepKeys.self))
        #expect(sameType(GenerateCommands.policy.command(), GenerateMainCommand.Policy.self))
        #expect(sameType(GenerateCommands.assetMeta.command(), GenerateMainCommand.AssetMeta.self))
        #expect(sameType(GenerateCommands.ed25519.command(), GenerateMainCommand.Ed25519Key.self))
        #expect(sameType(GenerateCommands.derivedKey.command(), GenerateMainCommand.DerivedKey.self))
        #expect(sameType(GenerateCommands.voteKey.command(), GenerateMainCommand.VoteKey.self))
        #expect(sameType(GenerateCommands.calidusKey.command(), GenerateMainCommand.CalidusKey.self))
        #expect(sameType(GenerateCommands.byronKey.command(), GenerateMainCommand.ByronKey.self))
    }

    @Test("back and exit route to the menu/exit commands")
    func navigationCases() {
        #expect(sameType(GenerateCommands.back.command(), MainMenuCommand.self))
        #expect(sameType(GenerateCommands.exit.command(), ExitCommand.self))
    }

    @Test("the 16 generate commands are all distinct types")
    func generateTypesAreDistinct() {
        let genCases: [GenerateCommands] = [
            .nodeColdKeys, .nodeKesKeys, .nodeVrfKeys, .nodeOperationalCertificate,
            .paymentAddressOnly, .paymentAndStakeAddress, .keyRotation, .poolJSON,
            .dRep, .policy, .assetMeta, .ed25519, .derivedKey, .voteKey,
            .calidusKey, .byronKey,
        ]
        let ids = Set(genCases.map { ObjectIdentifier($0.command()) })
        #expect(ids.count == genCases.count)
    }
}
