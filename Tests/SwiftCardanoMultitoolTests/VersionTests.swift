import Testing
@testable import SwiftCardanoMultitool

@Suite("Version")
struct VersionTests {

    @Test("number is a non-empty semantic-version string")
    func numberIsSemver() {
        let value = Version.number
        #expect(!value.isEmpty)
        let parts = value.split(separator: ".")
        #expect(parts.count == 3, "expected MAJOR.MINOR.PATCH, got '\(value)'")
        for part in parts {
            #expect(UInt(part) != nil, "version component '\(part)' is not numeric")
        }
    }
}
