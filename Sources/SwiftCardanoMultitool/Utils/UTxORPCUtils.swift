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

/// How long a health check's result is reused before the server is checked again.
let utxorpcHealthCacheTTL: TimeInterval = 20

/// Where health check results are kept between `scm` runs: each command is a
/// new process, so an in-memory cache would never be hit.
let utxorpcHealthCacheFile = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".scm/utxorpc-health.json")

/// The last health check of one server, keyed by URL in the cache file.
struct UTxORPCHealth: Codable, Equatable {
    let checkedAt: Date
    /// Why the server was left out, or `nil` when it passed.
    let skipReason: String?
}

func readUTxORPCHealth(url: String, from file: URL, now: Date = Date()) -> UTxORPCHealth? {
    guard let data = try? Data(contentsOf: file),
          let entries = try? JSONDecoder().decode([String: UTxORPCHealth].self, from: data),
          let entry = entries[url],
          now.timeIntervalSince(entry.checkedAt) < utxorpcHealthCacheTTL,
          entry.checkedAt <= now
    else { return nil }
    return entry
}

func writeUTxORPCHealth(_ health: UTxORPCHealth, url: String, to file: URL) {
    // A cache that can't be written only costs a re-check next time.
    var entries = (try? Data(contentsOf: file))
        .flatMap { try? JSONDecoder().decode([String: UTxORPCHealth].self, from: $0) } ?? [:]
    entries[url] = health
    try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? JSONEncoder().encode(entries).write(to: file, options: .atomic)
}

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
///
/// The outcome is kept in `cacheFile` for ``utxorpcHealthCacheTTL``, so
/// commands run back to back check the server once, and an unreachable one
/// doesn't cost a timeout each time. `nil` turns the cache off.
func withUTxORPC(
    _ base: any ChainContext,
    config: MultitoolConfig,
    logger: Logger,
    cacheFile: URL? = utxorpcHealthCacheFile
) async -> any ChainContext {
    guard let utxorpc = config.utxorpc, let url = utxorpc.url else { return base }

    let cached = cacheFile.flatMap { readUTxORPCHealth(url: url, from: $0) }
    if let reason = cached?.skipReason {
        let reason = reason.hasSuffix(".") ? String(reason.dropLast()) : reason
        warnUTxORPCSkipped(utxorpc, reason: "\(reason) (checked under \(Int(utxorpcHealthCacheTTL)) s ago)")
        return base
    }
    func remember(_ skipReason: String?) {
        if let cacheFile {
            writeUTxORPCHealth(UTxORPCHealth(checkedAt: Date(), skipReason: skipReason), url: url, to: cacheFile)
        }
    }

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

    if cached != nil {
        logger.info("Using UTxO RPC at \(url) in front of \(base.name) (checked under \(Int(utxorpcHealthCacheTTL)) s ago).")
        return context
    }

    do {
        let serverSlot = try await withTimeout(utxorpcHealthTimeout) {
            try await context.lastBlockSlot()
        }
        // The base context may itself be unreachable; then there is nothing to compare.
        if let baseSlot = try? await base.lastBlockSlot(), serverSlot + utxorpcMaxTipLag < baseSlot {
            throw UTxORPCSkipReason.behind(serverSlot: serverSlot, baseSlot: baseSlot)
        }
        logger.info("Using UTxO RPC at \(url) in front of \(base.name).")
        remember(nil)
        return context
    } catch {
        await connection.close()
        let reason = switch error {
            case UTxORPCSkipReason.timedOut:
                "it did not answer within \(utxorpcHealthTimeout)"
            case UTxORPCSkipReason.behind(let serverSlot, let baseSlot):
                "its tip (slot \(serverSlot)) is \(baseSlot - serverSlot) slots behind \(base.name)"
            default:
                "\(error)"
        }
        remember(reason)
        warnUTxORPCSkipped(utxorpc, reason: reason)
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
