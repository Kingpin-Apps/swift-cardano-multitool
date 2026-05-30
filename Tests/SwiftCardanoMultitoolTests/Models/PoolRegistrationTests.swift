import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("PoolRegistration")
struct PoolRegistrationTests {

    @Test("defaults all fields to nil")
    func defaultsAllNil() {
        let r = PoolRegistration()
        #expect(r.witness == nil)
        #expect(r.certificate == nil)
        #expect(r.epoch == nil)
        #expect(r.submitted == nil)
    }

    @Test("getCertificate throws when certificate path is missing")
    func getCertificateThrowsWhenMissing() {
        let r = PoolRegistration()
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try r.getCertificate()
        }
    }

    @Test("JSON round-trip preserves snake-cased keys and scalar fields")
    func jsonRoundTrip() throws {
        let r = PoolRegistration(
            witness: nil,
            certCreated: nil,
            certificate: FilePath("/c/pool.cert"),
            protectionKey: "key123",
            epoch: 482,
            submitted: nil,
            submittedStatus: "ok",
            proof: "deadbeef"
        )
        let data = try JSONEncoder().encode(r)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"protection_key\""))
        #expect(json.contains("\"submitted_status\""))

        let decoded = try JSONDecoder().decode(PoolRegistration.self, from: data)
        #expect(decoded.protectionKey == "key123")
        #expect(decoded.epoch == 482)
        #expect(decoded.submittedStatus == "ok")
        #expect(decoded.proof == "deadbeef")
    }
}
