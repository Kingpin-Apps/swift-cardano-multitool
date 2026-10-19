import Foundation
import ArgumentParser
import SwiftCardanoCore
import SwiftCardanoNetwork

// MARK: - Node address

/// A cardano-node to talk to: a relay over TCP (node-to-node), or a local
/// node's Unix socket (node-to-client).
///
/// Parses `host:port`, `[ipv6]:port`, a bare host, or a bare IPv6 address as
/// TCP; the port defaults to 3001, the usual relay port. Anything containing a
/// `/` is a socket path, e.g. `./node.socket` or `~/cardano/db/node.socket`.
enum RemoteNodeAddress: Equatable, Sendable, CustomStringConvertible, ExpressibleByArgument {
    static let defaultPort = 3001

    case tcp(host: String, port: Int)
    case socket(path: String)

    init(host: String, port: Int = RemoteNodeAddress.defaultPort) {
        self = .tcp(host: host, port: port)
    }

    init?(argument: String) {
        let value = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.contains("/") {
            // Host names and IP addresses never contain a slash.
            self = .socket(path: (value as NSString).expandingTildeInPath)
        } else if value.hasPrefix("[") {
            // [ipv6] or [ipv6]:port
            guard let close = value.firstIndex(of: "]") else { return nil }
            let host = String(value[value.index(after: value.startIndex)..<close])
            let rest = value[value.index(after: close)...]
            guard !host.isEmpty else { return nil }
            if rest.isEmpty {
                self.init(host: host)
            } else {
                guard rest.hasPrefix(":"), let port = Self.port(rest.dropFirst()) else { return nil }
                self.init(host: host, port: port)
            }
        } else if value.filter({ $0 == ":" }).count == 1 {
            let parts = value.split(separator: ":", omittingEmptySubsequences: false)
            guard !parts[0].isEmpty, let port = Self.port(parts[1]) else { return nil }
            self.init(host: String(parts[0]), port: port)
        } else {
            // A bare host name, IPv4 address, or unbracketed IPv6 address.
            self.init(host: value)
        }
    }

    private static func port(_ text: Substring) -> Int? {
        guard let port = Int(text), (1...65_535).contains(port) else { return nil }
        return port
    }

    var isSocket: Bool {
        if case .socket = self { return true }
        return false
    }

    /// `node-to-node` for TCP relays, `node-to-client` for sockets.
    var protocolName: String {
        isSocket ? "node-to-client" : "node-to-node"
    }

    var description: String {
        switch self {
            case .tcp(let host, let port):
                return host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
            case .socket(let path):
                return path
        }
    }
}

// MARK: - Network magic

/// The network magic for `network`, as the handshake expects it.
func networkMagic(for network: Network) -> UInt32 {
    UInt32(network.testnetMagic ?? 764_824_073)
}

/// Resolve the magic to send in the handshake: the explicit `--network-magic`
/// when given, otherwise the network of the active scm config, otherwise mainnet.
///
/// Pinging a relay should not need a config file, so a missing one falls back
/// to mainnet. A wrong guess is cheap: the node's refusal names its real magic.
func resolveNetworkMagic(_ explicit: UInt32?) async throws -> UInt32 {
    if let explicit { return explicit }
    if Configs.override == nil {
        guard let path = Environment.getFilePath(.config),
              FileManager.default.fileExists(atPath: path.string) else {
            return networkMagic(for: .mainnet)
        }
    }
    let config = try await MultitoolConfig.load(quiet: true)
    return networkMagic(for: config.cardano?.network ?? .mainnet)
}

// MARK: - Connecting

enum RemoteNodeError: Error, LocalizedError {
    case timedOut(RemoteNodeAddress, seconds: Double)
    case noTip(RemoteNodeAddress)
    case pingNeedsTCP(RemoteNodeAddress)
    case noSocket(String)

    var errorDescription: String? {
        switch self {
            case .timedOut(let address, let seconds):
                return "No answer from \(address) within \(seconds.formatted())s."
            case .noTip(let address):
                return "\(address) closed the chain-sync stream without reporting a tip."
            case .pingNeedsTCP(let address):
                return "\(address) is a socket. Ping mode uses keep-alive, which is node-to-node only; use --mode tip or --mode query for a socket."
            case .noSocket(let path):
                return "no socket at \(path). Is cardano-node running with --socket-path set to it?"
        }
    }
}

/// The network-library configuration for one connection to `address`.
///
/// scm only asks nodes things, so TCP connections advertise InitiatorOnly, and
/// the background keep-alive loop is off: ping mode sends its own probes.
func remoteNodeConfiguration(
    address: RemoteNodeAddress,
    networkMagic: UInt32,
    timeoutSeconds: Double
) -> CardanoNetworkConfiguration {
    var config = CardanoNetworkConfiguration()
    switch address {
        case .tcp(let host, let port):
            config.connection.host = host
            config.connection.port = port
        case .socket(let path):
            config.connection.socketPath = path
    }
    config.connection.networkMagic = networkMagic
    config.connection.connectTimeoutSeconds = timeoutSeconds
    config.protocol.initiatorOnly = true
    config.protocol.keepAliveIntervalSeconds = 0
    config.protocol.keepAliveTimeoutSeconds = timeoutSeconds
    // Errors reach the user through scm's own output; keep library logs quiet.
    config.logging.level = .critical
    return config
}

/// Run `operation`, failing with ``RemoteNodeError/timedOut(_:seconds:)`` if it
/// has not finished after `seconds`. The TCP connect has its own timeout, but a
/// peer that accepts the socket and never answers the handshake would hang.
func withRemoteTimeout<T: Sendable>(
    _ seconds: Double,
    address: RemoteNodeAddress,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    if case .socket(let path) = address, !FileManager.default.fileExists(atPath: path) {
        throw RemoteNodeError.noSocket(path)
    }
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw RemoteNodeError.timedOut(address, seconds: seconds)
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw RemoteNodeError.timedOut(address, seconds: seconds)
        }
        return result
    }
}

// MARK: - Ping

/// One keep-alive round trip.
struct RemotePingResult: Codable, Sendable {
    let sequence: Int
    let milliseconds: Double?
    let error: String?
}

/// A node-to-node connection that ping mode sends keep-alives over.
struct RemotePingConnection: Sendable {
    let connection: NodeToNodeConnection
    /// TCP connect plus handshake time.
    let handshakeMilliseconds: Double
    let nodeToNodeVersion: UInt16?
}

/// Connect to a relay and complete the NtN handshake, timing both.
func openPingConnection(
    _ address: RemoteNodeAddress,
    networkMagic: UInt32,
    timeoutSeconds: Double
) async throws -> RemotePingConnection {
    guard !address.isSocket else { throw RemoteNodeError.pingNeedsTCP(address) }
    let config = remoteNodeConfiguration(address: address, networkMagic: networkMagic, timeoutSeconds: timeoutSeconds)
    let clock = ContinuousClock()
    let start = clock.now
    let connection = try await withRemoteTimeout(timeoutSeconds, address: address) {
        try await CardanoNode.connectToNode(config: config)
    }
    return RemotePingConnection(
        connection: connection,
        handshakeMilliseconds: start.duration(to: clock.now).milliseconds,
        nodeToNodeVersion: connection.negotiatedVersion?.version
    )
}

/// Send one keep-alive on `connection` and time the round trip.
func sendPing(
    on connection: RemotePingConnection,
    address: RemoteNodeAddress,
    timeoutSeconds: Double,
    sequence: Int
) async -> RemotePingResult {
    do {
        // keepAlive() has its own timeout; the outer one also covers a socket
        // that stops delivering anything at all.
        let rtt = try await withRemoteTimeout(timeoutSeconds + 1, address: address) {
            try await connection.connection.keepAlive(timeoutSeconds: timeoutSeconds)
        }
        return RemotePingResult(sequence: sequence, milliseconds: rtt.milliseconds, error: nil)
    } catch {
        return RemotePingResult(sequence: sequence, milliseconds: nil, error: describeRemoteError(error))
    }
}

// MARK: - Tip

/// The chain tip as a node reports it over chain-sync.
struct RemoteTip: Codable, Sendable {
    let node: String
    let `protocol`: String
    let slot: UInt64?
    let hash: String?
    let block: UInt64
    let version: UInt16?
    let milliseconds: Double
}

/// Ask a node for its tip.
///
/// Chain-sync with no intersection points starts at origin, so the node's first
/// reply is a roll-back to origin that carries its current tip. That is all we
/// need; the connection is closed straight after.
func queryRemoteTip(
    _ address: RemoteNodeAddress,
    networkMagic: UInt32,
    timeoutSeconds: Double
) async throws -> RemoteTip {
    let config = remoteNodeConfiguration(address: address, networkMagic: networkMagic, timeoutSeconds: timeoutSeconds)
    let clock = ContinuousClock()
    let start = clock.now

    let (tip, version): (Tip, UInt16?) = try await withRemoteTimeout(timeoutSeconds, address: address) {
        if address.isSocket {
            return try await CardanoNode.withClient(config: config) { connection in
                let events: AsyncThrowingStream<ChainEvent, Error> = connection.chainSync.follow()
                return (try await firstTip(of: events, address: address), connection.negotiatedVersion)
            }
        } else {
            return try await CardanoNode.withNode(config: config) { connection in
                let events: AsyncThrowingStream<ChainEvent, Error> = connection.chainSync.follow()
                return (try await firstTip(of: events, address: address), connection.negotiatedVersion?.version)
            }
        }
    }

    return RemoteTip(
        node: address.description,
        protocol: address.protocolName,
        slot: tip.point.slot,
        hash: tip.point.hashHex,
        block: tip.blockNo,
        version: version.map(displayVersion),
        milliseconds: start.duration(to: clock.now).milliseconds
    )
}

private func firstTip(of events: AsyncThrowingStream<ChainEvent, Error>, address: RemoteNodeAddress) async throws -> Tip {
    for try await event in events {
        switch event {
            case .rollBackward(_, let tip), .rollForward(_, let tip):
                return tip
        }
    }
    throw RemoteNodeError.noTip(address)
}

// MARK: - Version query

/// One protocol version a node supports, with the version data it offers.
struct RemoteVersion: Codable, Sendable {
    let version: UInt16
    let networkMagic: UInt32
    /// NtN only: `InitiatorOnly` or `InitiatorAndResponder`.
    let diffusionMode: String?
    /// NtN v11+ only.
    let peerSharing: Bool?
    let query: Bool?
    /// NtN v16+ only.
    let perasSupport: Bool?
}

/// Every version a node supports, from the handshake query reply.
struct RemoteVersions: Codable, Sendable {
    let node: String
    let `protocol`: String
    let versions: [RemoteVersion]
    let milliseconds: Double
}

/// Ask a node which versions it supports, like `cardano-cli ping --mode query`.
func queryRemoteVersions(
    _ address: RemoteNodeAddress,
    networkMagic: UInt32,
    timeoutSeconds: Double
) async throws -> RemoteVersions {
    let config = remoteNodeConfiguration(address: address, networkMagic: networkMagic, timeoutSeconds: timeoutSeconds)
    let clock = ContinuousClock()
    let start = clock.now
    let table = try await withRemoteTimeout(timeoutSeconds, address: address) {
        address.isSocket
            ? try await CardanoNode.queryClientVersions(config: config)
            : try await CardanoNode.queryNodeVersions(config: config)
    }
    return RemoteVersions(
        node: address.description,
        protocol: address.protocolName,
        versions: table.map(RemoteVersion.init),
        milliseconds: start.duration(to: clock.now).milliseconds
    )
}

extension RemoteVersion {
    init(_ queried: QueriedVersion) {
        switch queried.versionData {
            case .nodeToNode(let magic, let initiatorOnly, let peerSharing, let query):
                self.init(
                    version: queried.version,
                    networkMagic: magic,
                    diffusionMode: initiatorOnly ? "InitiatorOnly" : "InitiatorAndResponder",
                    peerSharing: peerSharing.map { $0 == 1 },
                    query: query,
                    perasSupport: queried.perasSupport
                )
            case .nodeToClient(let magic, let query):
                self.init(
                    version: displayVersion(queried.version),
                    networkMagic: magic,
                    diffusionMode: nil,
                    peerSharing: nil,
                    query: query,
                    perasSupport: nil
                )
        }
    }
}

/// Node-to-client versions carry bit 15 on the wire (32791 is NtC v23).
/// Show the plain number, as cardano-cli does.
func displayVersion(_ wire: UInt16) -> UInt16 {
    wire & 0x7FFF
}

// MARK: - Helpers

/// A one-line reason for a failed remote call, without NIO's type noise where we can.
func describeRemoteError(_ error: any Error) -> String {
    if case HandshakeError.refused(let reason) = error {
        switch reason {
            case .versionMismatch(let versions):
                return "the node supports none of our versions (it offers \(versions.map { String(displayVersion($0)) }.joined(separator: ", ")))."
            case .handshakeDecodeError(let version, let message):
                return "the node could not decode our v\(displayVersion(version)) handshake: \(message)"
            case .refused(let version, let message):
                // cardano-node puts its own version data first; pull out its magic.
                if message.contains("version data mismatch"),
                   let range = message.range(of: #"NetworkMagic (\d+)"#, options: .regularExpression) {
                    let magic = message[range].split(separator: " ").last.map(String.init) ?? "?"
                    return "network magic mismatch: the node is on magic \(magic). Pass --network-magic \(magic)."
                }
                return "the node refused the v\(displayVersion(version)) handshake: \(message)"
        }
    }
    if case KeepAliveError.timeout = error {
        return "no keep-alive response in time."
    }
    if let error = error as? LocalizedError, let description = error.errorDescription {
        return description
    }
    return String(describing: error)
}

extension Duration {
    var milliseconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) * 1_000 + Double(attoseconds) / 1e15
    }
}
