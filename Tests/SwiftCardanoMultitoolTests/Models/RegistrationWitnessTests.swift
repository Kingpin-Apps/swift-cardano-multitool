import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("RegistrationWitness")
struct RegistrationWitnessTests {

    @Test("succeeds with no type")
    func nilTypeAllowed() throws {
        let w = try RegistrationWitness()
        #expect(w.type == nil)
        #expect(w.witnesses.isEmpty)
        #expect(w.hardwareWalletIncluded == false)
    }

    @Test("accepts poolRegistration as a valid type")
    func acceptsPoolRegistration() throws {
        let w = try RegistrationWitness(type: .poolRegistration)
        #expect(w.type == .poolRegistration)
    }

    @Test("accepts poolReRegistration as a valid type")
    func acceptsPoolReRegistration() throws {
        let w = try RegistrationWitness(type: .poolReRegistration)
        #expect(w.type == .poolReRegistration)
    }

    @Test("accepts poolRetirement as a valid type")
    func acceptsPoolRetirement() throws {
        let w = try RegistrationWitness(type: .poolRetirement)
        #expect(w.type == .poolRetirement)
    }

    @Test("rejects an unrelated transaction type")
    func rejectsTransactionType() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try RegistrationWitness(type: .transaction)
        }
    }

    @Test("rejects withdrawal type")
    func rejectsWithdrawal() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try RegistrationWitness(type: .withdrawal)
        }
    }

    @Test("preserves the supplied id and date")
    func preservesIdAndDate() throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let w = try RegistrationWitness(id: id, date: date)
        #expect(w.id == id)
        #expect(w.date == date)
    }
}
