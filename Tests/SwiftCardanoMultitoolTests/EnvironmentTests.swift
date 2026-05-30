import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

// Serialized because tests share process-wide environment state.
@Suite("Environment", .serialized)
struct EnvironmentTests {

    @Test("get returns nil when the variable is unset")
    func getNilWhenUnset() {
        Environment.set(.blockfrostProjectId, value: nil)
        #expect(Environment.get(.blockfrostProjectId) == nil)
    }

    @Test("set and get round-trip a string value")
    func setAndGetRoundtrip() {
        Environment.set(.blockfrostProjectId, value: "preview-xyz")
        defer { Environment.set(.blockfrostProjectId, value: nil) }
        #expect(Environment.get(.blockfrostProjectId) == "preview-xyz")
    }

    @Test("set with nil unsets the variable")
    func setNilUnsets() {
        Environment.set(.blockfrostProjectId, value: "tmp")
        Environment.set(.blockfrostProjectId, value: nil)
        #expect(Environment.get(.blockfrostProjectId) == nil)
    }

    @Test("getFilePath returns a FilePath wrapping the raw value")
    func getFilePathWrapsValue() {
        Environment.set(.config, value: "/etc/scm/config.toml")
        defer { Environment.set(.config, value: nil) }
        #expect(Environment.getFilePath(.config) == FilePath("/etc/scm/config.toml"))
    }

    @Test("getFilePath returns nil when unset")
    func getFilePathNilWhenUnset() {
        Environment.set(.config, value: nil)
        #expect(Environment.getFilePath(.config) == nil)
    }

    @Test("getBool returns true for '1', 'true', 'yes' (case insensitive)")
    func getBoolTrueValues() {
        for raw in ["1", "true", "TRUE", "True", "yes", "YES"] {
            Environment.set(.skipPrompt, value: raw)
            defer { Environment.set(.skipPrompt, value: nil) }
            #expect(Environment.getBool(.skipPrompt) == true, "value: \(raw)")
        }
    }

    @Test("getBool returns false for other values")
    func getBoolFalseValues() {
        for raw in ["0", "false", "no", "anything", ""] {
            Environment.set(.skipPrompt, value: raw)
            defer { Environment.set(.skipPrompt, value: nil) }
            #expect(Environment.getBool(.skipPrompt) == false, "value: \(raw)")
        }
    }

    @Test("getBool returns false when the variable is unset")
    func getBoolFalseWhenUnset() {
        Environment.set(.skipPrompt, value: nil)
        #expect(Environment.getBool(.skipPrompt) == false)
    }
}
