import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("TransactionWitness")
struct TransactionWitnessTests {

    @Test("default init synthesises id and dateCreated")
    func defaultInit() {
        let before = Date(timeIntervalSinceNow: -1)
        let w = TransactionWitness()
        let after = Date(timeIntervalSinceNow: 1)
        #expect(w.id.uuidString.count == 36)
        #expect(w.dateCreated >= before && w.dateCreated <= after)
        #expect(w.name == nil)
        #expect(w.type == nil)
    }

    @Test("preserves explicitly supplied id and dateCreated")
    func preservesIdAndDate() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let w = TransactionWitness(id: id, dateCreated: date)
        #expect(w.id == id)
        #expect(w.dateCreated == date)
    }

    @Test("JSON round-trip preserves scalar fields and snake-cased keys")
    func jsonRoundTrip() throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let w = TransactionWitness(
            name: "alice",
            id: id,
            dateCreated: date,
            type: .poolRegistration,
            ttl: 12345,
            signingName: "alice.payment",
            signingVkey: FilePath("/k/alice.vkey"),
            poolFile: FilePath("/p/alice.pool.json"),
            poolMetaTicker: "ALICE"
        )
        let data = try JSONEncoder().encode(w)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"date_created\""))
        #expect(json.contains("\"signing_vkey\""))
        #expect(json.contains("\"pool_file\""))
        #expect(json.contains("\"pool_meta_ticker\""))

        let decoded = try JSONDecoder().decode(TransactionWitness.self, from: data)
        #expect(decoded.name == "alice")
        #expect(decoded.id == id)
        #expect(decoded.type == .poolRegistration)
        #expect(decoded.ttl == 12345)
        #expect(decoded.signingName == "alice.payment")
        #expect(decoded.poolMetaTicker == "ALICE")
    }
}
