import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import Logging
import SwiftCardanoChain
import Testing
import UTxORPC

@testable import SwiftCardanoMultitool

/// Answers `ReadTip` with a fixed slot; everything else is unimplemented.
private struct TipOnlySync: Utxorpc_V1beta_Sync_SyncService.SimpleServiceProtocol {
    let slot: UInt64

    func fetchBlock(
        request: Utxorpc_V1beta_Sync_FetchBlockRequest, context: ServerContext
    ) async throws -> Utxorpc_V1beta_Sync_FetchBlockResponse {
        throw RPCError(code: .unimplemented, message: "fetchBlock")
    }

    func dumpHistory(
        request: Utxorpc_V1beta_Sync_DumpHistoryRequest, context: ServerContext
    ) async throws -> Utxorpc_V1beta_Sync_DumpHistoryResponse {
        throw RPCError(code: .unimplemented, message: "dumpHistory")
    }

    func followTip(
        request: Utxorpc_V1beta_Sync_FollowTipRequest,
        response: RPCWriter<Utxorpc_V1beta_Sync_FollowTipResponse>,
        context: ServerContext
    ) async throws {
        throw RPCError(code: .unimplemented, message: "followTip")
    }

    func readTip(
        request: Utxorpc_V1beta_Sync_ReadTipRequest, context: ServerContext
    ) async throws -> Utxorpc_V1beta_Sync_ReadTipResponse {
        .with { $0.tip = .with { $0.slot = slot } }
    }
}

@Suite("withUTxORPC")
struct UTxORPCUtilsTests {

    let logger = Logger(label: "test")

    func config(_ utxorpc: UTxORPCConfig?) -> MultitoolConfig {
        MultitoolConfig(utxorpc: utxorpc, tokenMetaServer: TokenMetaServerURLs(), adaHandlePolicy: AdaHandlePolicyIds())
    }

    func base(slot: Int?) -> MockChainContext {
        let base = MockChainContext(name: "Base")
        if let slot { base.stubLastBlockSlot = { slot } }
        return base
    }

    /// Runs `body` with a UTxO RPC server whose tip is at `slot`, on a loopback port.
    func withServer(slot: UInt64, _ body: (String) async throws -> Void) async throws {
        let transport = HTTP2ServerTransport.Posix(
            address: .ipv4(host: "127.0.0.1", port: 0),
            transportSecurity: .plaintext
        )
        try await withGRPCServer(transport: transport, services: [TipOnlySync(slot: slot)]) { server in
            let address = try #require(try await server.listeningAddress?.ipv4)
            try await body("http://127.0.0.1:\(address.port)")
        }
    }

    @Test("without a [utxorpc] block the base context is used as is")
    func noBlock() async {
        let context = await withUTxORPC(base(slot: 100), config: config(nil), logger: logger)
        #expect(context.name == "Base")
    }

    @Test("a server that is up and current goes in front of the base context")
    func currentServerWraps() async throws {
        try await withServer(slot: 1_000) { url in
            let context = await withUTxORPC(base(slot: 1_100), config: config(UTxORPCConfig(url: url)), logger: logger)
            #expect(context.name == "UTxO RPC + Base")
            let slot = try await context.lastBlockSlot()
            #expect(slot == 1_000)
        }
    }

    @Test("a base context that can't report its tip doesn't keep the server out")
    func baseWithoutTip() async throws {
        try await withServer(slot: 1_000) { url in
            let context = await withUTxORPC(base(slot: nil), config: config(UTxORPCConfig(url: url)), logger: logger)
            #expect(context.name == "UTxO RPC + Base")
        }
    }

    @Test("a server whose tip trails the base context's is left out")
    func laggingServerSkipped() async throws {
        try await withServer(slot: 1_000) { url in
            let behind = 1_000 + utxorpcMaxTipLag + 1
            let context = await withUTxORPC(base(slot: behind), config: config(UTxORPCConfig(url: url)), logger: logger)
            #expect(context.name == "Base")
        }
    }

    @Test("an unreachable server is left out")
    func unreachableSkipped() async {
        let missing = UTxORPCConfig(url: "unix:///tmp/scm-tests-no-such-rpc.sock")
        let context = await withUTxORPC(base(slot: 100), config: config(missing), logger: logger)
        #expect(context.name == "Base")
    }

    @Test("a bad [utxorpc] block is left out rather than failing the command")
    func badBlockSkipped() async {
        let bad = UTxORPCConfig(url: "http://127.0.0.1:9", apiVersion: "v2")
        let context = await withUTxORPC(base(slot: 100), config: config(bad), logger: logger)
        #expect(context.name == "Base")
    }
}
