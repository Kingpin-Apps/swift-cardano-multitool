import SystemPackage
import Testing
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
