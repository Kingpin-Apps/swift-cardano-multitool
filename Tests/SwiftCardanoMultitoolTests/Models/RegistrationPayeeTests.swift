import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("RegistrationPayee")
struct RegistrationPayeeTests {

    @Test("preserves all init values")
    func preservesInitValues() {
        let payee = RegistrationPayee(
            name: "alice",
            amount: 500_000_000,
            amountReturn: 1_500_000,
            address: "addr1xyz",
            skey: FilePath("/keys/alice.payment.skey")
        )
        #expect(payee.name == "alice")
        #expect(payee.amount == 500_000_000)
        #expect(payee.amountReturn == 1_500_000)
        #expect(payee.address == "addr1xyz")
        #expect(payee.skey == FilePath("/keys/alice.payment.skey"))
    }

    @Test("name-only init leaves other fields nil")
    func nameOnly() {
        let payee = RegistrationPayee(name: "bob")
        #expect(payee.amount == nil)
        #expect(payee.amountReturn == nil)
        #expect(payee.address == nil)
        #expect(payee.skey == nil)
    }

    @Test("JSON round-trip preserves snake-cased keys")
    func jsonRoundTrip() throws {
        let payee = RegistrationPayee(
            name: "alice",
            amount: 100,
            amountReturn: 50,
            address: "addr1...",
            skey: FilePath("/k/x.skey")
        )
        let data = try JSONEncoder().encode(payee)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"amount_return\""))

        let decoded = try JSONDecoder().decode(RegistrationPayee.self, from: data)
        #expect(decoded.name == "alice")
        #expect(decoded.amount == 100)
        #expect(decoded.amountReturn == 50)
        #expect(decoded.address == "addr1...")
    }
}
