import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("PaymentAddressFiles")
struct PaymentAddressFilesTests {

    @Test("recognises .payment.addr and enterprise .addr files, but not stake files")
    func isPaymentAddressFile() {
        #expect(PaymentAddressFiles.isPaymentAddressFile("owner.payment.addr"))
        #expect(PaymentAddressFiles.isPaymentAddressFile("owner.addr"))
        #expect(!PaymentAddressFiles.isPaymentAddressFile("owner.stake.addr"))
        #expect(!PaymentAddressFiles.isPaymentAddressFile("owner.payment.skey"))
        #expect(!PaymentAddressFiles.isPaymentAddressFile("owner.payment.vkey"))
    }

    @Test("strips address suffixes down to the bare name")
    func stem() {
        #expect(PaymentAddressFiles.stem(of: "owner.payment.addr") == "owner")
        #expect(PaymentAddressFiles.stem(of: "owner.addr") == "owner")
        #expect(PaymentAddressFiles.stem(of: "owner.payment") == "owner")
        #expect(PaymentAddressFiles.stem(of: "owner.stake.addr") == "owner")
        #expect(PaymentAddressFiles.stem(of: "owner") == "owner")
    }

    @Test("candidate file names prefer .payment.addr over .addr")
    func candidates() {
        #expect(PaymentAddressFiles.candidateFileNames(for: "owner") == ["owner.payment.addr", "owner.addr"])
        #expect(PaymentAddressFiles.candidateFileNames(for: "owner.payment") == ["owner.payment.addr", "owner.addr"])
        #expect(PaymentAddressFiles.candidateFileNames(for: "owner.addr") == ["owner.payment.addr", "owner.addr"])
    }

    @Test("resolves an enterprise <name>.addr file when no .payment.addr exists")
    func resolvesEnterpriseFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir.string) }
        try "addr_test1...".write(toFile: dir.appending("ent.addr").string, atomically: true, encoding: .utf8)

        #expect(PaymentAddressFiles.resolve(name: "ent", in: dir) == dir.appending("ent.addr"))
        #expect(PaymentAddressFiles.resolve(name: "ent.addr", in: dir) == dir.appending("ent.addr"))
        #expect(PaymentAddressFiles.resolve(name: "missing", in: dir) == nil)
    }

    @Test("prefers <name>.payment.addr when both layouts exist")
    func prefersPaymentAddr() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: dir.string) }
        try "a".write(toFile: dir.appending("owner.addr").string, atomically: true, encoding: .utf8)
        try "b".write(toFile: dir.appending("owner.payment.addr").string, atomically: true, encoding: .utf8)
        try "c".write(toFile: dir.appending("owner.stake.addr").string, atomically: true, encoding: .utf8)

        #expect(PaymentAddressFiles.resolve(name: "owner", in: dir) == dir.appending("owner.payment.addr"))
        #expect(try PaymentAddressFiles.list(in: dir) == ["owner.addr", "owner.payment.addr"])
    }

    private func makeTempDir() throws -> FilePath {
        let path = FilePath(NSTemporaryDirectory()).appending("scm-paf-\(UUID().uuidString)")
        try FileManager.default.createDirectory(atPath: path.string, withIntermediateDirectories: true)
        return path
    }
}
