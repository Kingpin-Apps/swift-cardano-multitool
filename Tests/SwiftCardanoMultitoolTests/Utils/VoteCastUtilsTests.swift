import Foundation
import Testing
import SystemPackage
@testable import SwiftCardanoMultitool

@Suite("VoteCastUtils")
struct VoteCastUtilsTests {

    // MARK: - inferVoterRole

    @Test("infers .drep from a .drep.vkey suffix")
    func inferDRep() throws {
        let role = try inferVoterRole(from: FilePath("/some/dir/myDRep.drep.vkey"))
        #expect(role == .drep)
    }

    @Test("infers .spo from a .node.vkey suffix")
    func inferSPO() throws {
        let role = try inferVoterRole(from: FilePath("/some/dir/myNode.node.vkey"))
        #expect(role == .spo)
    }

    @Test("infers .ccHot from a .cc-hot.vkey suffix")
    func inferCCHot() throws {
        let role = try inferVoterRole(from: FilePath("/some/dir/myCom.cc-hot.vkey"))
        #expect(role == .ccHot)
    }

    @Test("case-insensitive suffix match")
    func inferCaseInsensitive() throws {
        let role = try inferVoterRole(from: FilePath("/dir/X.DREP.VKEY"))
        #expect(role == .drep)
    }

    @Test("throws when the suffix is unrecognised")
    func inferRejectsUnknownSuffix() {
        #expect(throws: (any Error).self) {
            _ = try inferVoterRole(from: FilePath("/dir/x.payment.vkey"))
        }
    }

    @Test("throws when there is no recognised suffix at all")
    func inferRejectsBareName() {
        #expect(throws: (any Error).self) {
            _ = try inferVoterRole(from: FilePath("/dir/x"))
        }
    }

    // MARK: - parseAnchorArguments

    @Test("returns nil when both url and hash are nil")
    func anchorBothNil() throws {
        #expect(try parseAnchorArguments(url: nil, hash: nil) == nil)
    }

    @Test("throws when only url is provided")
    func anchorOnlyUrl() {
        #expect(throws: (any Error).self) {
            _ = try parseAnchorArguments(url: "https://example.com/x", hash: nil)
        }
    }

    @Test("throws when only hash is provided")
    func anchorOnlyHash() {
        #expect(throws: (any Error).self) {
            _ = try parseAnchorArguments(url: nil, hash: String(repeating: "a", count: 64))
        }
    }

    @Test("accepts a valid url + 64-hex hash pair")
    func anchorValidPair() throws {
        let hash = String(repeating: "a", count: 64)
        let anchor = try parseAnchorArguments(
            url: "https://example.com/anchor.json",
            hash: hash
        )
        #expect(anchor != nil)
        #expect(anchor?.anchorDataHash.payload == hash.hexStringToData)
        #expect(anchor?.anchorUrl.absoluteString == "https://example.com/anchor.json")
    }

    @Test("lowercases an uppercase hex hash")
    func anchorUppercaseHashGetsLowered() throws {
        let upper = String(repeating: "A", count: 64)
        let lower = String(repeating: "a", count: 64)
        let anchor = try parseAnchorArguments(
            url: "https://example.com/x",
            hash: upper
        )
        #expect(anchor?.anchorDataHash.payload == lower.hexStringToData)
    }

    @Test("trims surrounding whitespace from both inputs")
    func anchorTrimsWhitespace() throws {
        let hash = "  " + String(repeating: "a", count: 64) + "  "
        let anchor = try parseAnchorArguments(
            url: "  https://example.com/x  ",
            hash: hash
        )
        #expect(anchor != nil)
    }

    @Test("rejects a hash that is the wrong length")
    func anchorRejectsBadLengthHash() {
        let short = String(repeating: "a", count: 63)
        #expect(throws: (any Error).self) {
            _ = try parseAnchorArguments(url: "https://example.com/x", hash: short)
        }
    }

    @Test("rejects a hash containing non-hex characters")
    func anchorRejectsNonHex() {
        let bad = "z" + String(repeating: "a", count: 63)
        #expect(throws: (any Error).self) {
            _ = try parseAnchorArguments(url: "https://example.com/x", hash: bad)
        }
    }
}
