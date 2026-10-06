import ArgumentParser
import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.PoolID")
struct PoolIDTests {
    private let poolIdHex = "8a219b698d3b6e034391ae84cee62f1d76b6fbc45ddfe4e31e0d4b60"

    @Test("parses --pool-name and a hex --pool-operator")
    func parses() throws {
        let cmd = try GenerateMainCommand.PoolID.parse(["--pool-name", "mypool", "--pool-operator", poolIdHex])
        #expect(cmd.poolName == "mypool")
        #expect(try cmd.poolOperator?.id(.hex) == poolIdHex)
    }

    @Test("writes <name>.pool.id and <name>.pool.id-bech")
    func writesFiles() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-pool-id-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let prefix = dir.appendingPathComponent("mypool").path
        var cmd = try GenerateMainCommand.PoolID.parse(["--pool-name", prefix, "--pool-operator", poolIdHex])
        try await cmd.run()

        let hex = try String(contentsOfFile: "\(prefix).pool.id", encoding: .utf8)
        let bech = try String(contentsOfFile: "\(prefix).pool.id-bech", encoding: .utf8)
        #expect(hex == poolIdHex)
        #expect(bech.hasPrefix("pool1"))

        // The bech32 file round-trips to the same pool as a --pool-operator input
        let fromFile = try GenerateMainCommand.PoolID.parse(["--pool-name", "x", "--pool-operator", "\(prefix).pool.id-bech"])
        #expect(try fromFile.poolOperator?.id(.hex) == poolIdHex)
    }
}
