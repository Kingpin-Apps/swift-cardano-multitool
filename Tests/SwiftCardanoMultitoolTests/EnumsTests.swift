import SystemPackage
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("Mode")
struct ModeTests {

    @Test("has four expected raw values")
    func hasExpectedRawValues() {
        let values = Mode.allCases.map(\.rawValue).sorted()
        #expect(values == ["auto", "lite", "offline", "online"])
    }
}

@Suite("Tool+ExpressibleByArgument")
struct ToolExpressibleByArgumentTests {

    @Test("accepts swiftcardano in three written forms")
    func acceptsSwiftCardanoAliases() {
        #expect(Tool(argument: "swiftcardano") == .swiftCardano)
        #expect(Tool(argument: "swift-cardano") == .swiftCardano)
        #expect(Tool(argument: "swift_cardano") == .swiftCardano)
    }

    @Test("accepts cardano-cli in three written forms")
    func acceptsCardanoCLIAliases() {
        #expect(Tool(argument: "cardanocli") == .cardanoCLI)
        #expect(Tool(argument: "cardano-cli") == .cardanoCLI)
        #expect(Tool(argument: "cardano_cli") == .cardanoCLI)
    }

    @Test("is case insensitive")
    func caseInsensitive() {
        #expect(Tool(argument: "SwiftCardano") == .swiftCardano)
        #expect(Tool(argument: "CARDANO-CLI") == .cardanoCLI)
    }

    @Test("trims surrounding whitespace")
    func trimsWhitespace() {
        #expect(Tool(argument: "  swiftcardano  ") == .swiftCardano)
    }

    @Test("returns nil for unknown values")
    func rejectsUnknown() {
        #expect(Tool(argument: "lucid") == nil)
        #expect(Tool(argument: "") == nil)
    }

    @Test("description reflects the case")
    func description() {
        #expect(Tool.swiftCardano.description == "SwiftCardano")
        #expect(Tool.cardanoCLI.description == "Cardano CLI")
    }
}

@Suite("WhichPeriod+ExpressibleByArgument")
struct WhichPeriodExpressibleByArgumentTests {

    @Test("accepts current and next case-insensitively")
    func acceptsBoth() {
        #expect(WhichPeriod(argument: "current") == .current)
        #expect(WhichPeriod(argument: "next") == .next)
        #expect(WhichPeriod(argument: "CURRENT") == .current)
        #expect(WhichPeriod(argument: "Next") == .next)
    }

    @Test("trims surrounding whitespace")
    func trimsWhitespace() {
        #expect(WhichPeriod(argument: "  current  ") == .current)
    }

    @Test("returns nil for unknown values")
    func rejectsUnknown() {
        #expect(WhichPeriod(argument: "previous") == nil)
        #expect(WhichPeriod(argument: "") == nil)
    }
}

@Suite("KeyGenMethod boolean classifiers")
struct KeyGenMethodClassifierTests {

    @Test("isEncryptedType is true exactly for enc, hybridEnc, hybridMultiEnc")
    func isEncryptedType() {
        let encrypted: Set<KeyGenMethod> = [.enc, .hybridEnc, .hybridMultiEnc]
        for c in KeyGenMethod.allCases {
            #expect(c.isEncryptedType == encrypted.contains(c), "\(c)")
        }
    }

    @Test("isHardwareType is true exactly for hw, hwMulti, hybrid, hybridMulti, hybridEnc, hybridMultiEnc")
    func isHardwareType() {
        let hardware: Set<KeyGenMethod> = [.hw, .hwMulti, .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc]
        for c in KeyGenMethod.allCases {
            #expect(c.isHardwareType == hardware.contains(c), "\(c)")
        }
    }

    @Test("isMultisigType is true exactly for hwMulti, hybridMulti, hybridMultiEnc")
    func isMultisigType() {
        let multi: Set<KeyGenMethod> = [.hwMulti, .hybridMulti, .hybridMultiEnc]
        for c in KeyGenMethod.allCases {
            #expect(c.isMultisigType == multi.contains(c), "\(c)")
        }
    }

    @Test("isHybridType is true exactly for hybrid, hybridMulti, hybridEnc, hybridMultiEnc")
    func isHybridType() {
        let hybrid: Set<KeyGenMethod> = [.hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc]
        for c in KeyGenMethod.allCases {
            #expect(c.isHybridType == hybrid.contains(c), "\(c)")
        }
    }
}

@Suite("StartStopChoice")
struct StartStopChoiceTests {

    @Test("description matches the case")
    func description() {
        #expect(StartStopChoice.start.description == "Start process")
        #expect(StartStopChoice.stop.description == "Stop process")
    }
}

@Suite("SigningMethod")
struct SigningMethodTests {

    @Test("isHardware is true only for hardwareWallet")
    func isHardware() {
        let sw = SigningMethod.softwareKey(.init("/tmp/x.skey"))
        let hw = SigningMethod.hardwareWallet(.init("/tmp/x.hwsfile"))
        #expect(sw.isHardware == false)
        #expect(hw.isHardware == true)
    }

    @Test("path extracts the underlying FilePath")
    func pathExtraction() {
        let p = FilePath("/tmp/x.skey")
        let sw = SigningMethod.softwareKey(p)
        let hw = SigningMethod.hardwareWallet(p)
        #expect(sw.path == p)
        #expect(hw.path == p)
    }
}

// MARK: - Simple raw-value enums

@Suite("TransactionType")
struct TransactionTypeTests {

    @Test("description returns the rawValue for every case")
    func descriptionMatchesRawValue() {
        for c in TransactionType.allCases {
            #expect(c.description == c.rawValue)
            #expect(!c.rawValue.isEmpty)
        }
    }

    @Test("raw values match the documented PascalCase names")
    func rawValuesAreCorrect() {
        #expect(TransactionType.transaction.rawValue == "Transaction")
        #expect(TransactionType.assetMinting.rawValue == "AssetMinting")
        #expect(TransactionType.assetBurning.rawValue == "AssetBurning")
        #expect(TransactionType.withdrawal.rawValue == "Withdrawal")
        #expect(TransactionType.stakeKeyRegistration.rawValue == "StakeKeyRegistration")
        #expect(TransactionType.stakeKeyDeRegistration.rawValue == "StakeKeyDeRegistration")
        #expect(TransactionType.delegationCertRegistration.rawValue == "DelegationCertRegistration")
        #expect(TransactionType.poolRegistration.rawValue == "PoolRegistration")
        #expect(TransactionType.poolReRegistration.rawValue == "PoolReRegistration")
        #expect(TransactionType.poolRetirement.rawValue == "PoolRetirement")
    }

    @Test("allCases lists every variant exactly once")
    func allCasesCountTen() {
        #expect(TransactionType.allCases.count == 10)
    }
}

@Suite("WitnessType")
struct WitnessTypeTests {

    @Test("description equals rawValue")
    func descriptionEqualsRawValue() {
        for c in WitnessType.allCases {
            #expect(c.description == c.rawValue)
        }
    }

    @Test("raw values are 'local' and 'external'")
    func rawValues() {
        let values = Set(WitnessType.allCases.map(\.rawValue))
        #expect(values == ["local", "external"])
    }
}

@Suite("SPORelayType")
struct SPORelayTypeTests {

    @Test("description equals rawValue")
    func descriptionEqualsRawValue() {
        for c in SPORelayType.allCases {
            #expect(c.description == c.rawValue)
        }
    }

    @Test("raw values are 'ip' and 'dns'")
    func rawValues() {
        let values = Set(SPORelayType.allCases.map(\.rawValue))
        #expect(values == ["ip", "dns"])
    }
}

@Suite("HostType")
struct HostTypeTests {

    @Test("description equals rawValue")
    func descriptionEqualsRawValue() {
        for c in HostType.allCases {
            #expect(c.description == c.rawValue)
        }
    }

    @Test("raw values cover ipv4, ipv6, single, multi")
    func rawValues() {
        let values = Set(HostType.allCases.map(\.rawValue))
        #expect(values == ["ipv4", "ipv6", "single", "multi"])
    }
}

@Suite("ConfigFileType")
struct ConfigFileTypeTests {

    @Test("description equals rawValue")
    func descriptionEqualsRawValue() {
        for c in ConfigFileType.allCases {
            #expect(c.description == c.rawValue)
        }
    }

    @Test("defaultValueDescription is 'json' (used by ArgumentParser help text)")
    func defaultValueDescription() {
        for c in ConfigFileType.allCases {
            #expect(c.defaultValueDescription == "json")
        }
    }

    @Test("raw values cover json, toml, yaml")
    func rawValues() {
        let values = Set(ConfigFileType.allCases.map(\.rawValue))
        #expect(values == ["json", "toml", "yaml"])
    }
}

@Suite("ConfigNetwork")
struct ConfigNetworkTests {

    @Test("description equals rawValue")
    func descriptionEqualsRawValue() {
        for c in ConfigNetwork.allCases {
            #expect(c.description == c.rawValue)
        }
    }

    @Test("raw values cover the five named Cardano networks")
    func rawValues() {
        let values = Set(ConfigNetwork.allCases.map(\.rawValue))
        #expect(values == ["mainnet", "preprod", "preview", "guildnet", "sanchonet"])
    }

    @Test("network mapping returns the matching SwiftCardanoCore Network for every case")
    func networkMapping() {
        #expect(ConfigNetwork.mainnet.network == .mainnet)
        #expect(ConfigNetwork.preprod.network == .preprod)
        #expect(ConfigNetwork.preview.network == .preview)
        #expect(ConfigNetwork.guildnet.network == .guildnet)
        #expect(ConfigNetwork.sanchonet.network == .sanchonet)
    }
}

// MARK: - AlignedChoiceDescribable enums (name + details non-empty for every case)

@Suite("GetAddressBy")
struct GetAddressByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in GetAddressBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("GetTransactionBy")
struct GetTransactionByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in GetTransactionBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("EnterAddressBy")
struct EnterAddressByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in EnterAddressBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }

    @Test("covers adahandle, address, and path")
    func allRawValues() {
        let values = Set(EnterAddressBy.allCases.map(\.rawValue))
        #expect(values == ["adahandle", "address", "path"])
    }
}

@Suite("EnterDRepBy")
struct EnterDRepByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in EnterDRepBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("EnterPoolOperatorBy")
struct EnterPoolOperatorByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in EnterPoolOperatorBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("EnterCommitteeColdCredentialBy")
struct EnterCommitteeColdCredentialByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in EnterCommitteeColdCredentialBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("EnterCommitteeHotCredentialBy")
struct EnterCommitteeHotCredentialByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in EnterCommitteeHotCredentialBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("EnterDRepCredentialBy")
struct EnterDRepCredentialByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in EnterDRepCredentialBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("EnterAssetMetaBy")
struct EnterAssetMetaByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in EnterAssetMetaBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("MoveInstantaneousRewardSourceOption")
struct MoveInstantaneousRewardSourceOptionTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in MoveInstantaneousRewardSourceOption.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }

    @Test("covers reserves and treasury")
    func rawValues() {
        let values = Set(MoveInstantaneousRewardSourceOption.allCases.map(\.rawValue))
        #expect(values == ["reserves", "treasury"])
    }
}

@Suite("EnterVoterBy")
struct EnterVoterByTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in EnterVoterBy.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }

    @Test("covers all 5 voter filter modes")
    func rawValues() {
        let values = Set(EnterVoterBy.allCases.map(\.rawValue))
        #expect(values == ["none", "drep", "spo", "cc-cold", "cc-hot"])
    }
}

@Suite("VoteActionTypeFilter")
struct VoteActionTypeFilterTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in VoteActionTypeFilter.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }

    @Test("covers every governance action type plus 'any'")
    func rawValues() {
        let values = Set(VoteActionTypeFilter.allCases.map(\.rawValue))
        #expect(values == [
            "any", "parameter-change", "hard-fork", "treasury-withdrawal",
            "no-confidence", "update-committee", "new-constitution", "info"
        ])
    }
}

@Suite("VoterRole")
struct VoterRoleTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in VoterRole.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }

    @Test("keyFileSuffix returns the file-extension stem for each role")
    func keyFileSuffix() {
        #expect(VoterRole.drep.keyFileSuffix == "drep")
        #expect(VoterRole.spo.keyFileSuffix == "node")
        #expect(VoterRole.ccHot.keyFileSuffix == "cc-hot")
    }

    @Test("intentionally omits cc-cold (only authorizes the hot key, doesn't vote)")
    func excludesCcCold() {
        let values = Set(VoterRole.allCases.map(\.rawValue))
        #expect(!values.contains("cc-cold"))
        #expect(values == ["drep", "spo", "cc-hot"])
    }
}

@Suite("GovernanceActionType")
struct GovernanceActionTypeTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in GovernanceActionType.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }

    @Test("fileSlug returns a non-empty filename-safe stem for each case")
    func fileSlugPopulated() {
        for c in GovernanceActionType.allCases {
            #expect(!c.fileSlug.isEmpty)
        }
    }

    @Test("fileSlug uses 'hardfork' for hardForkInitiation (matches bash convention)")
    func hardforkSlugQuirk() {
        // Most slugs match rawValue; hardForkInitiation is the only intentional divergence.
        #expect(GovernanceActionType.hardForkInitiation.rawValue == "hard-fork-initiation")
        #expect(GovernanceActionType.hardForkInitiation.fileSlug == "hardfork")
    }

    @Test("covers every Conway governance action variant")
    func rawValues() {
        let values = Set(GovernanceActionType.allCases.map(\.rawValue))
        #expect(values == [
            "info", "treasury-withdrawal", "no-confidence",
            "new-constitution", "hard-fork-initiation", "update-committee", "parameter-change"
        ])
    }
}

@Suite("VoteChoice")
struct VoteChoiceTests {
    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in VoteChoice.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }

    @Test("asCoreVote maps each choice to the matching SwiftCardanoCore.Vote")
    func asCoreVoteMapping() {
        #expect(VoteChoice.yes.asCoreVote == .yes)
        #expect(VoteChoice.no.asCoreVote == .no)
        #expect(VoteChoice.abstain.asCoreVote == .abstain)
    }

    @Test("covers yes, no, abstain")
    func rawValues() {
        let values = Set(VoteChoice.allCases.map(\.rawValue))
        #expect(values == ["yes", "no", "abstain"])
    }
}

@Suite("KeyGenMethod descriptions")
struct KeyGenMethodDescriptionsTests {

    @Test("every case has non-empty name and details")
    func nameAndDetailsPopulated() {
        for c in KeyGenMethod.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}
