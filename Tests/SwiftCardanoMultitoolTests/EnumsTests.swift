import SystemPackage
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

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

@Suite("ConfigNetwork")
struct ConfigNetworkTests {

    @Test("network mapping returns the matching SwiftCardanoCore Network for every case")
    func networkMapping() {
        #expect(ConfigNetwork.mainnet.network == .mainnet)
        #expect(ConfigNetwork.preprod.network == .preprod)
        #expect(ConfigNetwork.preview.network == .preview)
        #expect(ConfigNetwork.guildnet.network == .guildnet)
        #expect(ConfigNetwork.sanchonet.network == .sanchonet)
    }
}

@Suite("VoterRole")
struct VoterRoleTests {

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

    @Test("fileSlug uses 'hardfork' for hardForkInitiation (matches bash convention)")
    func hardforkSlugQuirk() {
        // Most slugs match rawValue; hardForkInitiation is the only intentional divergence.
        #expect(GovernanceActionType.hardForkInitiation.rawValue == "hard-fork-initiation")
        #expect(GovernanceActionType.hardForkInitiation.fileSlug == "hardfork")
    }
}

@Suite("VoteChoice")
struct VoteChoiceTests {

    @Test("asCoreVote maps each choice to the matching SwiftCardanoCore.Vote")
    func asCoreVoteMapping() {
        #expect(VoteChoice.yes.asCoreVote == .yes)
        #expect(VoteChoice.no.asCoreVote == .no)
        #expect(VoteChoice.abstain.asCoreVote == .abstain)
    }
}
