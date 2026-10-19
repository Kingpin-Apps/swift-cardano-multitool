import Foundation
import ArgumentParser
import Noora

/// What `scm ping` asks a node for.
enum PingMode: String, CaseIterable, Sendable, ExpressibleByArgument, AlignedChoiceDescribable {
    case ping
    case tip
    case query

    var name: String {
        switch self {
            case .ping: return "Ping"
            case .tip: return "Tip"
            case .query: return "Query"
        }
    }

    var details: String {
        switch self {
            case .ping: return "Time keep-alive round trips over one connection."
            case .tip: return "Ask the node for its chain tip over chain-sync."
            case .query: return "List every protocol version the node supports."
        }
    }
}

struct PingMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ping",
        abstract: "Ping cardano-node relays, or read a node's tip or supported versions.",
        usage: """
        scm ping relay.example.com:3001
        scm ping backbone.cardano.iog.io:3001 [2001:db8::1]:3001 --count 10
        scm ping backbone.cardano.iog.io:3001 --mode tip
        scm ping preview-node.play.dev.cardano.org:3001 --network-magic 2 --mode query --json
        scm ping ~/cardano/db/node.socket --mode tip
        """,
        discussion: """
        Talks to nodes directly, so no API key is needed. A host:port is a \
        relay, reached over the node-to-node protocol. A path (anything with \
        a /) is a local node's socket, reached over node-to-client. --mode \
        picks what to do with each node:

          ping   Connect once, then send --count keep-alives and time each \
        round trip. The connect and handshake time is shown once. Relays only.
          tip    Ask the node for its current chain tip (slot, block hash, \
        block number) over chain-sync.
          query  List every protocol version the node supports, with its \
        network magic, diffusion mode, peer sharing and Peras flags.

        The handshake must use the node's network magic. By default it comes \
        from the network in your scm config, or mainnet when there is no \
        config; pass --network-magic for a node on another network.
        """
    )

    @Argument(help: "Nodes as host:port, [ipv6]:port, host (port 3001), or a socket path.")
    var nodes: [RemoteNodeAddress] = []

    @Option(help: "What to ask each node: ping, tip, or query.")
    var mode: PingMode = .ping

    @Option(name: .shortAndLong, help: "Number of keep-alives to send to each node (ping mode).")
    var count: Int = 4

    @Option(name: .shortAndLong, help: "Seconds to wait between keep-alives (ping mode).")
    var interval: Double = 1

    @Option(name: [.customShort("m"), .long], help: "Network magic for the handshake. Defaults to the network in your scm config.")
    var networkMagic: UInt32?

    @Option(name: .shortAndLong, help: "Seconds to wait for each answer.")
    var timeout: Double = 10

    @Flag(name: .shortAndLong, help: "Output as JSON instead of formatted text.")
    var json: Bool = false

    mutating func validate() throws {
        guard count > 0 else { throw ValidationError("--count must be at least 1.") }
        guard interval >= 0 else { throw ValidationError("--interval cannot be negative.") }
        guard timeout > 0 else { throw ValidationError("--timeout must be greater than 0.") }
        if mode == .ping, let socket = nodes.first(where: \.isSocket) {
            throw ValidationError(RemoteNodeError.pingNeedsTCP(socket).errorDescription ?? "Ping mode needs a relay.")
        }
    }

    mutating func wizard() {
        mode = noora.singleChoicePrompt(
            title: "Mode",
            question: "What should scm ask the node?"
        )
        let answer = noora.textPrompt(
            title: "Node",
            prompt: mode == .ping
                ? "Enter the relay (host:port):"
                : "Enter the relay (host:port) or a local node's socket path:",
            validationRules: [NonEmptyValidationRule(error: "The node address cannot be empty.")]
        )
        if let node = RemoteNodeAddress(argument: answer) {
            nodes = [node]
        }
    }

    mutating func run() async throws {
        if nodes.isEmpty, isInteractiveSession() {
            wizard()
            try validate()
        }
        guard !nodes.isEmpty else {
            throw ValidationError("Give at least one node, as host:port or a socket path.")
        }

        let magic = try await resolveNetworkMagic(networkMagic)

        let allAnswered: Bool
        switch mode {
            case .ping: allAnswered = try await runPing(magic: magic)
            case .tip: allAnswered = try await runTip(magic: magic)
            case .query: allAnswered = try await runQuery(magic: magic)
        }

        // Exit non-zero when a node never answered, so scripts can use `scm ping` as a health check.
        if !allAnswered {
            throw ExitCode.failure
        }
    }

    // MARK: - Modes

    private func runPing(magic: UInt32) async throws -> Bool {
        var summaries: [PingSummary] = []
        for node in nodes {
            if !json {
                formatPrint("\nPinging \(.primary(node.description)) \(.muted("(magic \(magic))"))")
            }

            var connection: RemotePingConnection?
            var handshakes: [Double] = []
            var version: UInt16?
            var results: [RemotePingResult] = []

            for sequence in 1...count {
                // Connect on the first ping, and again after a failure.
                if connection == nil {
                    do {
                        let opened = try await openPingConnection(node, networkMagic: magic, timeoutSeconds: timeout)
                        connection = opened
                        handshakes.append(opened.handshakeMilliseconds)
                        version = version ?? opened.nodeToNodeVersion
                        if !json { printConnected(opened, reconnect: handshakes.count > 1) }
                    } catch {
                        let result = RemotePingResult(sequence: sequence, milliseconds: nil, error: describeRemoteError(error))
                        results.append(result)
                        if !json { printPing(result) }
                        try await pause(after: sequence)
                        continue
                    }
                }

                guard let open = connection else { continue }
                let result = await sendPing(on: open, address: node, timeoutSeconds: timeout, sequence: sequence)
                results.append(result)
                if !json { printPing(result) }
                if result.milliseconds == nil {
                    await open.connection.close()
                    connection = nil
                }
                try await pause(after: sequence)
            }
            await connection?.connection.close()

            let summary = PingSummary(
                node: node.description,
                networkMagic: magic,
                nodeToNodeVersion: version,
                handshakeMilliseconds: handshakes,
                pings: results
            )
            if !json { printSummary(summary) }
            summaries.append(summary)
        }

        if json { try printJSON(summaries) }
        return !summaries.contains { $0.received == 0 }
    }

    private func pause(after sequence: Int) async throws {
        if sequence < count, interval > 0 {
            try await Task.sleep(for: .seconds(interval))
        }
    }

    private func runTip(magic: UInt32) async throws -> Bool {
        var results: [RemoteNodeAnswer<RemoteTip>] = []
        for node in nodes {
            let answer: RemoteNodeAnswer<RemoteTip>
            do {
                answer = .init(node: node, value: try await queryRemoteTip(node, networkMagic: magic, timeoutSeconds: timeout))
            } catch {
                answer = .init(node: node, error: error)
            }
            results.append(answer)

            guard !json else { continue }
            formatPrint("\nTip of \(.primary(node.description)) \(.muted("(magic \(magic))"))")
            if let tip = answer.value {
                formatPrint("  slot   \(.primary(tip.slot.map(String.init) ?? "origin"))")
                formatPrint("  block  \(.primary(String(tip.block)))")
                formatPrint("  hash   \(.primary(tip.hash ?? "-"))")
                formatPrint("  \(.muted("\(versionLabel(tip.version, socket: node.isSocket)), \(formatMs(tip.milliseconds)) ms"))")
            } else {
                formatPrint("  \(.danger("failed: \(answer.error ?? "unknown error")"))")
            }
        }

        if json { try printJSON(results) }
        return results.allSatisfy { $0.value != nil }
    }

    private func runQuery(magic: UInt32) async throws -> Bool {
        var results: [RemoteNodeAnswer<RemoteVersions>] = []
        for node in nodes {
            let answer: RemoteNodeAnswer<RemoteVersions>
            do {
                answer = .init(node: node, value: try await queryRemoteVersions(node, networkMagic: magic, timeoutSeconds: timeout))
            } catch {
                answer = .init(node: node, error: error)
            }
            results.append(answer)

            guard !json else { continue }
            formatPrint("\nVersions of \(.primary(node.description)) \(.muted("(magic \(magic))"))")
            if let table = answer.value {
                for v in table.versions {
                    var details = ["magic \(v.networkMagic)"]
                    if let mode = v.diffusionMode { details.append(mode) }
                    if let ps = v.peerSharing { details.append("peer sharing \(ps ? "on" : "off")") }
                    if let peras = v.perasSupport { details.append("Peras \(peras ? "on" : "off")") }
                    formatPrint("  \(.primary(versionLabel(v.version, socket: node.isSocket)))  \(.muted(details.joined(separator: ", ")))")
                }
                formatPrint("  \(.muted("\(formatMs(table.milliseconds)) ms"))")
            } else {
                formatPrint("  \(.danger("failed: \(answer.error ?? "unknown error")"))")
            }
        }

        if json { try printJSON(results) }
        return results.allSatisfy { $0.value != nil }
    }

    // MARK: - Output

    private func printConnected(_ connection: RemotePingConnection, reconnect: Bool) {
        let version = connection.nodeToNodeVersion.map { ", NtN v\($0)" } ?? ""
        let verb = reconnect ? "reconnected" : "connected"
        formatPrint("  \(.muted("\(verb): handshake \(formatMs(connection.handshakeMilliseconds)) ms\(version)"))")
    }

    private func printPing(_ result: RemotePingResult) {
        if let ms = result.milliseconds {
            formatPrint("  seq=\(result.sequence) time=\(.primary(formatMs(ms))) ms")
        } else {
            formatPrint("  seq=\(result.sequence) \(.danger("failed: \(result.error ?? "unknown error")"))")
        }
    }

    private func printSummary(_ summary: PingSummary) {
        var line = "  \(summary.sent) sent, \(summary.received) received, \(formatMs(summary.lossPercent))% lost"
        if let min = summary.minMilliseconds, let avg = summary.avgMilliseconds, let max = summary.maxMilliseconds {
            line += "; min/avg/max = \(formatMs(min))/\(formatMs(avg))/\(formatMs(max)) ms"
        }
        formatPrint("\(.muted(line))")
    }

    private func versionLabel(_ version: UInt16?, socket: Bool) -> String {
        "\(socket ? "NtC" : "NtN") v\(version.map(String.init) ?? "?")"
    }

    private func printJSON<T: Codable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try noora.json(value, encoder: encoder)
    }
}

/// One node's answer in tip or query mode: either the value or why it failed.
struct RemoteNodeAnswer<Value: Codable & Sendable>: Codable, Sendable {
    let node: String
    let value: Value?
    let error: String?

    init(node: RemoteNodeAddress, value: Value) {
        self.node = node.description
        self.value = value
        self.error = nil
    }

    init(node: RemoteNodeAddress, error: any Error) {
        self.node = node.description
        self.value = nil
        self.error = describeRemoteError(error)
    }

    // Flatten the value into the node's object, so JSON reads {"node", "slot", …} or {"node", "error"}.
    func encode(to encoder: any Encoder) throws {
        if let value {
            try value.encode(to: encoder)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(node, forKey: .node)
            try container.encode(error, forKey: .error)
        }
    }
}

/// The results of pinging one node, with the usual ping statistics.
///
/// Times are keep-alive round trips. The connect + handshake time of each
/// connection (more than one when a failure forced a reconnect) is kept apart.
struct PingSummary: Codable, Sendable {
    let node: String
    let networkMagic: UInt32
    let nodeToNodeVersion: UInt16?
    let handshakeMilliseconds: [Double]
    let sent: Int
    let received: Int
    let lossPercent: Double
    let minMilliseconds: Double?
    let avgMilliseconds: Double?
    let maxMilliseconds: Double?
    let pings: [RemotePingResult]

    init(
        node: String,
        networkMagic: UInt32,
        nodeToNodeVersion: UInt16? = nil,
        handshakeMilliseconds: [Double] = [],
        pings: [RemotePingResult]
    ) {
        let times = pings.compactMap(\.milliseconds)
        self.node = node
        self.networkMagic = networkMagic
        self.nodeToNodeVersion = nodeToNodeVersion
        self.handshakeMilliseconds = handshakeMilliseconds
        self.sent = pings.count
        self.received = times.count
        self.lossPercent = pings.isEmpty ? 0 : Double(pings.count - times.count) / Double(pings.count) * 100
        self.minMilliseconds = times.min()
        self.avgMilliseconds = times.isEmpty ? nil : times.reduce(0, +) / Double(times.count)
        self.maxMilliseconds = times.max()
        self.pings = pings
    }
}

private func formatMs(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
}
