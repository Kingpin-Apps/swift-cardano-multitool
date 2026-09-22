import Foundation
import SwiftCardanoCore
import Testing

@testable import SwiftCardanoMultitool

/// `query drep` accepts the same breadth of inputs as `query pool` and
/// `query address`: bech32 in either CIP form, hex with or without the CIP-129
/// header byte, a key or ID file, or a bare name to look up in the directory.
@Suite("DRep.init(argument:)")
struct DRepArgumentParsingTests {

    /// The DRep registered on the throw-away devnet these were written against.
    static let keyHashHex = "6ab890434e8d93592c97252de87034fb39a986bbdea9dd075d3f575d"
    static let cip105 = "drep1d2ufqs6w3kf4jtyhy5k7sup5lvu6np4mm65a6p6a8at46ne0qdv"
    static let cip129 = "drep1yf4t3yzrf6xexkfvjujjm6rsxnann2vxh002nhg8t5l4whgx4lj72"

    private func keyHash(_ drep: DRep?) -> String? {
        guard case let .verificationKeyHash(hash) = drep?.credential else { return nil }
        return hash.payload.toHex
    }

    @Test(
        "every spelling of one DRep resolves to the same key hash",
        arguments: [
            cip105,
            cip129,
            keyHashHex,
            "0x" + keyHashHex,
            // CIP-129 hex: 0x22 = drep key type (0b0010) | key hash (0b0010).
            "22" + keyHashHex,
        ]
    )
    func allSpellingsAgree(argument: String) {
        #expect(keyHash(DRep(argument: argument)) == Self.keyHashHex)
    }

    @Test("the predefined DReps are recognised by name and by bech32 spelling")
    func predefinedDReps() {
        for spelling in ["always-abstain", "alwaysAbstain", "abstain", "drep_always_abstain"] {
            #expect(DRep(argument: spelling)?.credential == .alwaysAbstain, "\(spelling)")
        }
        for spelling in ["always-no-confidence", "no-confidence", "drep_always_no_confidence"] {
            #expect(
                DRep(argument: spelling)?.credential == .alwaysNoConfidence, "\(spelling)")
        }
    }

    @Test("a CIP-129 header naming a non-DRep key type is rejected")
    func rejectsForeignKeyType() {
        // 0x02 is a committee-hot key hash, not a DRep; reading it as a DRep
        // would silently query the wrong credential.
        #expect(DRep(argument: "02" + Self.keyHashHex) == nil)
    }

    @Test("a hash of the wrong length is rejected")
    func rejectsWrongLength() {
        #expect(DRep(argument: "abcd") == nil)
        #expect(DRep(argument: String(repeating: "ab", count: 27)) == nil)
    }

    @Test("garbage is rejected rather than resolving to something arbitrary")
    func rejectsGarbage() {
        #expect(DRep(argument: "") == nil)
        #expect(DRep(argument: "not-a-drep") == nil)
        // Starts with "drep" but is not valid bech32 — must fall through and fail,
        // not return a half-built value.
        #expect(DRep(argument: "drep1notvalidbech32") == nil)
    }

    @Test("a key file, an ID file and a bare name all resolve to the same DRep")
    func resolvesFromFiles() throws {
        // `generate drep` writes <name>.drep.vkey, .drep.skey and .drep.id side by
        // side, so all three are present at once — the case that previously
        // resolved to nothing because more than one candidate matched.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("drep-args-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data(Self.cip105.utf8).write(to: dir.appendingPathComponent("mydrep.drep.id"))

        WorkingDirectory.withCurrent(dir.path) {
            // Bare name, resolved against the current directory.
            #expect(keyHash(DRep(argument: "mydrep")) == Self.keyHashHex)
            // Explicit file name.
            #expect(keyHash(DRep(argument: "mydrep.drep.id")) == Self.keyHashHex)
            // A name with no matching file stays unresolved.
            #expect(DRep(argument: "absent") == nil)
        }
    }
}
