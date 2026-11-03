import Foundation
import Logging
import Noora
import SwiftCardanoChain
import UTxORPCClient

/// How long the `[utxorpc]` server has to answer `ReadTip` before `scm` goes on without it.
let utxorpcHealthTimeout: Duration = .seconds(5)

/// How many slots the `[utxorpc]` server's tip may trail the base context's
/// before `scm` treats it as out of date: ten minutes of mainnet slots.
let utxorpcMaxTipLag = 600

/// Why the `[utxorpc]` server was left out.
enum UTxORPCSkipReason: Error, Equatable {
    case timedOut
    case behind(serverSlot: Int, baseSlot: Int)
}

/// Puts the `[utxorpc]` server in front of `base`, which then answers only
/// what UTxO RPC can't: stake, pool and governance queries.
///
/// Returns `base` unchanged when there is no `[utxorpc]` block, or when the
/// server doesn't answer `ReadTip` within ``utxorpcHealthTimeout``, or when
/// its tip trails `base`'s by more than ``utxorpcMaxTipLag`` slots (a local
/// node that is still syncing, say).
func withUTxORPC(
    _ base: any ChainContext,
    config: MultitoolConfig,
    logger: Logger
) async -> any ChainContext {
    guard let utxorpc = config.utxorpc else { return base }

    let connection: UTxORPCConnection
    do {
        connection = try UTxORPCConnection(endpoint: try utxorpc.endpoint())
    } catch {
        warnUTxORPCSkipped(utxorpc, reason: "\(error)")
        return base
    }

    let context = UTxORPCChainContext(
        connector: UTxORPCConnectionConnector(connection: connection),
        network: config.cardano?.network ?? .mainnet,
        wrapping: base
    )

    do {
        let serverSlot = try await withTimeout(utxorpcHealthTimeout) {
            try await context.lastBlockSlot()
        }
        // The base context may itself be unreachable; then there is nothing to compare.
        if let baseSlot = try? await base.lastBlockSlot(), serverSlot + utxorpcMaxTipLag < baseSlot {
            throw UTxORPCSkipReason.behind(serverSlot: serverSlot, baseSlot: baseSlot)
        }
        logger.info("Using UTxO RPC at \(utxorpc.url ?? "") in front of \(base.name).")
        return context
    } catch {
        await connection.close()
        switch error {
            case UTxORPCSkipReason.timedOut:
                warnUTxORPCSkipped(utxorpc, reason: "it did not answer within \(utxorpcHealthTimeout)")
            case UTxORPCSkipReason.behind(let serverSlot, let baseSlot):
                warnUTxORPCSkipped(
                    utxorpc,
                    reason: "its tip (slot \(serverSlot)) is \(baseSlot - serverSlot) slots behind \(base.name)"
                )
            default:
                warnUTxORPCSkipped(utxorpc, reason: "\(error)")
        }
        return base
    }
}

private func warnUTxORPCSkipped(_ utxorpc: UTxORPCConfig, reason: String) {
    // gRPC error messages often end in a full stop already.
    let reason = reason.hasSuffix(".") ? String(reason.dropLast()) : reason
    noora.warning(
        .alert(
            "Not using UTxO RPC at \(.primary(utxorpc.url ?? "")): \(reason).",
            takeaway: "Carrying on without it."
        )
    )
    print()
}

/// Runs `operation`, throwing ``UTxORPCSkipReason/timedOut`` if it takes longer than `timeout`.
private func withTimeout<T: Sendable>(
    _ timeout: Duration,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw UTxORPCSkipReason.timedOut
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw UTxORPCSkipReason.timedOut }
        return result
    }
}
