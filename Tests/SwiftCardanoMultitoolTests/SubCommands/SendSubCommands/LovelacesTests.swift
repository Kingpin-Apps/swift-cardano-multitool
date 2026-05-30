import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("SendMainCommand.Lovelaces")
struct SendLovelacesTests {

    @Test("configuration commandName is 'lovelaces'")
    func commandName() {
        #expect(SendMainCommand.Lovelaces.configuration.commandName == "lovelaces")
    }

    @Test("default parse leaves amount nil")
    func defaults() throws {
        let cmd = try SendMainCommand.Lovelaces.parse([])
        #expect(cmd.amount == nil)
    }

    @Test("validate accepts 'min' as a special amount")
    func validateMinAmount() throws {
        var cmd = try SendMainCommand.Lovelaces.parse(["--amount", "min"])
        try cmd.validate()
        #expect(cmd.amount == "min")
    }

    @Test("validate accepts 'MIN' (case insensitive)")
    func validateCaseInsensitiveMin() throws {
        var cmd = try SendMainCommand.Lovelaces.parse(["--amount", "MIN"])
        try cmd.validate()
    }

    @Test("validate accepts a positive integer amount")
    func validatePositiveInteger() throws {
        var cmd = try SendMainCommand.Lovelaces.parse(["--amount", "5000000"])
        try cmd.validate()
        #expect(cmd.amount == "5000000")
    }

    @Test("validate rejects a non-numeric amount that isn't 'min'")
    func validateRejectsGarbage() throws {
        // ArgumentParser surfaces validation failures as a CommandError wrapping the underlying ValidationError.
        #expect(throws: (any Error).self) {
            _ = try SendMainCommand.Lovelaces.parse(["--amount", "abc"])
        }
    }

    @Test("validate rejects zero amount")
    func validateRejectsZero() throws {
        #expect(throws: (any Error).self) {
            _ = try SendMainCommand.Lovelaces.parse(["--amount", "0"])
        }
    }
}
