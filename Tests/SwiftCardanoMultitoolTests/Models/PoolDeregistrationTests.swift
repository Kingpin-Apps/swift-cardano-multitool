import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("PoolDeregistration")
struct PoolDeregistrationTests {

    @Test("defaults all fields to nil")
    func defaultsAllNil() {
        let d = PoolDeregistration()
        #expect(d.certificate == nil)
        #expect(d.epoch == nil)
        #expect(d.payeeName == nil)
        #expect(d.payeeAddress == nil)
    }

    @Test("JSON round-trip preserves snake-cased keys")
    func jsonRoundTrip() throws {
        let d = PoolDeregistration(
            submitted: nil,
            certCreated: nil,
            certificate: FilePath("/c/pool.deregistration.cert"),
            epoch: 500,
            proof: "abcd1234",
            payeeName: "payee",
            payeeAddress: "addr1...",
            payeeSkey: FilePath("/k/payee.skey"),
            payeeHwsFile: FilePath("/k/payee.hwsfile")
        )
        let data = try JSONEncoder().encode(d)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"payee_name\""))
        #expect(json.contains("\"payee_address\""))
        #expect(json.contains("\"payee_skey\""))
        #expect(json.contains("\"payee_hws_file\""))

        let decoded = try JSONDecoder().decode(PoolDeregistration.self, from: data)
        #expect(decoded.payeeName == "payee")
        #expect(decoded.payeeAddress == "addr1...")
        #expect(decoded.epoch == 500)
        #expect(decoded.proof == "abcd1234")
    }
}
