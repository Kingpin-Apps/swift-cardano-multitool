import Foundation
import ArgumentParser
import Noora

/// What `scm ping` asks a remote node for.
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
            case .ping: return "Time repeated connect + handshake round trips."
            case .tip: return "Ask the node for its chain tip over chain-sync."
            case .query: return "Show the handshake parameters the node agreed to."
        }
    }
}

struct PingMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ping",
        abstract: "Ping remote cardano-node relays, or read their tip or handshake parameters.",
        usage: """
        scm ping relay.example.com:3001
        scm ping backbone.cardano.iog.io:3001 [2001:db8::1]:3001 --count 10
        scm ping backbone.cardano.iog.io:3001 --mode tip
        scm ping preview-node.play.dev.cardano.org:3001 --network-magic 2 --mode query --json
        """,
        discussion: """
        Talks to remote nodes over the node-to-node protocol, so no local node \
        or API key is needed. --mode picks what to do with each node:

          ping   Open a TCP connection, negotiate the handshake, and close it, \
        --count times. The time shown is that whole round trip: roughly two \
        network round trips plus the node's handshake time.
          tip    Ask the node for its current chain tip (slot, block hash, \
        block number) over chain-sync.
          query  Show the handshake parameters the node agreed to: protocol \
        version, network magic, diffusion mode and peer sharing.

        The handshake must use the node's network magic. By default it comes \
        from the network in your scm config, or mainnet when there is no \
        config; pass --network-magic for a node on another network.
        """
    )

    @Argument(help: "Remote nodes as host:port, [ipv6]:port, or host (port 3001).")
    var nodes: [RemoteNodeAddress] = []

    @Option(help: "What to ask each node: ping, tip, or query.")
    var mode: PingMode = .ping

    @Option(name: .shortAndLong, help: "Number of pings to send to each node (ping mode).")
    var count: Int = 4

    @Option(name: .shortAndLong, help: "Seconds to wait between pings (ping mode).")
    var interval: Double = 1

    @Option(name: [.customShort("m"), .long], help: "Network magic for the handshake. Defaults to the network in your scm config.")
    var networkMagic: UInt32?

    @Option(name: .shortAndLong, help: "Seconds to wait for each node to answer.")
    var timeout: Double = 10

    @Flag(name: .shortAndLong, help: "Output as JSON instead of formatted text.")
    var json: Bool = false

    mutating func validate() throws {
        guard count > 0 else { throw ValidationError("--count must be at least 1.") }
        guard interval >= 0 else { throw ValidationError("--interval cannot be negative.") }
        guard timeout > 0 else { throw ValidationError("--timeout must be greater than 0.") }
    }

    mutating func wizard() {
        let answer = noora.textPrompt(
            title: "Remote Node",
            prompt: "Enter the node (host:port):",
            validationRules: [NonEmptyValidationRule(error: "The node address cannot be empty.")]
        )
        if let node = RemoteNodeAddress(argument: answer) {
            nodes = [node]
        }
        mode = noora.singleChoicePrompt(
            title: "Mode",
            question: "What should scm ask the node?"
        )
    }

    mutating func run() async throws {
        if nodes.isEmpty, isInteractiveSession() {
            wizard()
        }
        guard !nodes.isEmpty else {
            throw ValidationError("Give at least one node, as host:port.")
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

            var results: [RemotePingResult] = []
            for sequence in 1...count {
                let result = await pingRemoteNode(node, networkMagic: magic, timeoutSeconds: timeout, sequence: sequence)
                results.append(result)
                if !json { printPing(result) }
                if sequence < count, interval > 0 {
                    try await Task.sleep(for: .seconds(interval))
                }
            }

            let summary = PingSummary(node: node.description, networkMagic: magic, pings: results)
            if !json { printSummary(summary) }
            summaries.append(summary)
        }

        if json { try printJSON(summaries) }
        return !summaries.contains { $0.received == 0 }
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
                formatPrint("  \(.muted("NtN v\(tip.nodeToNodeVersion.map(String.init) ?? "?"), \(formatMs(tip.milliseconds)) ms"))")
            } else {
                formatPrint("  \(.danger("failed: \(answer.error ?? "unknown error")"))")
            }
        }

        if json { try printJSON(results) }
        return results.allSatisfy { $0.value != nil }
    }

    private func runQuery(magic: UInt32) async throws -> Bool {
        var results: [RemoteNodeAnswer<RemoteHandshake>] = []
        for node in nodes {
            let answer: RemoteNodeAnswer<RemoteHandshake>
            do {
                answer = .init(node: node, value: try await queryRemoteHandshake(node, networkMagic: magic, timeoutSeconds: timeout))
            } catch {
                answer = .init(node: node, error: error)
            }
            results.append(answer)

            guard !json else { continue }
            formatPrint("\nHandshake with \(.primary(node.description)) \(.muted("(magic \(magic))"))")
            if let handshake = answer.value {
                formatPrint("  version         \(.primary("NtN v\(handshake.nodeToNodeVersion)"))")
                formatPrint("  network magic   \(.primary(String(handshake.networkMagic)))")
                formatPrint("  diffusion mode  \(.primary(handshake.diffusionMode))")
                formatPrint("  peer sharing    \(.primary(handshake.peerSharing.map { $0 ? "enabled" : "disabled" } ?? "-"))")
                formatPrint("  \(.muted("\(formatMs(handshake.milliseconds)) ms"))")
            } else {
                formatPrint("  \(.danger("failed: \(answer.error ?? "unknown error")"))")
            }
        }

        if json { try printJSON(results) }
        return results.allSatisfy { $0.value != nil }
    }

    // MARK: - Output

    private func printPing(_ result: RemotePingResult) {
        if let ms = result.milliseconds {
            let version = result.nodeToNodeVersion.map { " NtN v\($0)" } ?? ""
            formatPrint("  seq=\(result.sequence) time=\(.primary(formatMs(ms))) ms\(.muted(version))")
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

    private func printJSON<T: Codable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
struct PingSummary: Codable, Sendable {
    let node: String
    let networkMagic: UInt32
    let sent: Int
    let received: Int
    let lossPercent: Double
    let minMilliseconds: Double?
    let avgMilliseconds: Double?
    let maxMilliseconds: Double?
    let nodeToNodeVersion: UInt16?
    let pings: [RemotePingResult]

    init(node: String, networkMagic: UInt32, pings: [RemotePingResult]) {
        let times = pings.compactMap(\.milliseconds)
        self.node = node
        self.networkMagic = networkMagic
        self.sent = pings.count
        self.received = times.count
        self.lossPercent = pings.isEmpty ? 0 : Double(pings.count - times.count) / Double(pings.count) * 100
        self.minMilliseconds = times.min()
        self.avgMilliseconds = times.isEmpty ? nil : times.reduce(0, +) / Double(times.count)
        self.maxMilliseconds = times.max()
        self.nodeToNodeVersion = pings.lazy.compactMap(\.nodeToNodeVersion).first
        self.pings = pings
    }
}

private func formatMs(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
}
