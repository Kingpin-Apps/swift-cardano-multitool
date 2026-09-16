import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("PoolOperator+ExpressibleByArgument")
struct PoolOperatorExpressibleByArgumentTests {

    @Test("accepts a valid bech32 pool ID")
    func acceptsBech32() {
        let id = "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt"
        #expect(PoolOperator(argument: id) != nil)
    }

    @Test("accepts a 56-character hex string")
    func acceptsHex() {
        let hex = String(repeating: "ab", count: 28)
        #expect(PoolOperator(argument: hex) != nil)
    }

    @Test("accepts a hex string with 0x prefix")
    func acceptsHexWithPrefix() {
        let hex = "0x" + String(repeating: "ab", count: 28)
        #expect(PoolOperator(argument: hex) != nil)
    }

    @Test("returns nil for hex that is not a 28-byte pool hash")
    func rejectsShortHex() {
        #expect(PoolOperator(argument: "abcd") == nil)
    }

    @Test("accepts the cold verification key as pool_vk bech32 or 64-character hex")
    func acceptsColdVerificationKeyText() throws {
        let pair = try StakePoolKeyPair.generate()
        let expected = try pair.verificationKey.poolKeyHash()
        let payload = pair.verificationKey.payload

        #expect(PoolOperator(argument: payload.toHex)?.poolKeyHash == expected)
        let bech32 = try #require(Bech32().encode(hrp: "pool_vk", witprog: payload))
        #expect(PoolOperator(argument: bech32)?.poolKeyHash == expected)
        #expect(PoolOperator(argument: try PoolOperator(poolKeyHash: expected).toBech32())?.poolKeyHash == expected)
    }

    @Test("derives the pool hash from .node.vkey and .node.skey files")
    func acceptsColdKeyFiles() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try StakePoolKeyPair.generate()
        let expected = try pair.verificationKey.poolKeyHash()
        let vkeyPath = dir.appendingPathComponent("test.node.vkey").path
        let skeyPath = dir.appendingPathComponent("test.node.skey").path
        try pair.verificationKey.save(to: vkeyPath)
        try pair.signingKey.save(to: skeyPath)

        #expect(PoolOperator(argument: vkeyPath)?.poolKeyHash == expected)
        #expect(PoolOperator(argument: skeyPath)?.poolKeyHash == expected)
    }

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(PoolOperator(argument: "") == nil)
    }

    @Test("returns nil for an unprefixed non-hex non-existent file name")
    func rejectsGarbage() {
        #expect(PoolOperator(argument: "no_such_file_anywhere_xyz") == nil)
    }

    @Test("trims surrounding whitespace before parsing")
    func trimsWhitespace() {
        let id = "  pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt  "
        #expect(PoolOperator(argument: id) != nil)
    }
}
