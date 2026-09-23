import Testing
import Foundation
import ArgumentParser
@testable import SwiftCardanoMultitool

@Suite("PasswordUtils.getDecryptionPassword", .serialized)
struct DecryptionPasswordTests {

    static let envKey = Environment.decryptPassword.rawValue

    /// Run `body` with CARDANO_MULTITOOL_DECRYPT_PASSWORD set, restoring it afterwards.
    func withEnvPassword(_ value: String?, _ body: () async throws -> Void) async rethrows {
        let previous = ProcessInfo.processInfo.environment[Self.envKey]
        if let value {
            setenv(Self.envKey, value, 1)
        } else {
            unsetenv(Self.envKey)
        }
        defer {
            if let previous { setenv(Self.envKey, previous, 1) } else { unsetenv(Self.envKey) }
        }
        try await body()
    }

    @Test("uses the environment password when it is set and strong")
    func usesEnvironmentPassword() async throws {
        try await withEnvPassword("Str0ng!Passw0rd#2026") {
            let (password, fromEnvironment) = try await PasswordUtils.getDecryptionPassword(
                prompt: "unused"
            )
            #expect(password == "Str0ng!Passw0rd#2026")
            #expect(fromEnvironment == true)
        }
    }

    @Test("rejects a weak environment password instead of falling back to a prompt")
    func rejectsWeakEnvironmentPassword() async throws {
        try await withEnvPassword("short") {
            // Assert the specific error: a fallthrough to the interactive prompt would also
            // throw in a non-TTY test process, which would pass a looser expectation.
            await #expect(throws: ExitCode.validationFailure) {
                _ = try await PasswordUtils.getDecryptionPassword(prompt: "unused")
            }
        }
    }

    @Test("an empty environment value is treated as set and rejected")
    func rejectsEmptyEnvironmentPassword() async throws {
        try await withEnvPassword("") {
            // Assert the specific error: a fallthrough to the interactive prompt would also
            // throw in a non-TTY test process, which would pass a looser expectation.
            await #expect(throws: ExitCode.validationFailure) {
                _ = try await PasswordUtils.getDecryptionPassword(prompt: "unused")
            }
        }
    }
}
