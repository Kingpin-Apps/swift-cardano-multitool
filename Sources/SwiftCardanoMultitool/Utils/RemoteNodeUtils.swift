import Foundation
import ArgumentParser
import Logging
import SwiftCardanoCore
import SwiftCardanoNetwork

// MARK: - Remote node address

/// A remote cardano-node relay reached over the node-to-node (NtN) protocol.
///
/// Parses `host:port`, `[ipv6]:port`, a bare host, or a bare IPv6 address.
/// The port defaults to 3001, the usual relay port.
struct RemoteNodeAddress: Equatable, Sendable, CustomStringConvertible, ExpressibleByArgument {
    static let defaultPort = 3001

    let host: String
    let port: Int

    init(host: String, port: Int = RemoteNodeAddress.defaultPort) {
        self.host = host
        self.port = port
    }

    init?(argument: String) {
        let value = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("[") {
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

    var description: String {
        host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
    }
}

// MARK: - Network magic

/// The network magic for `network`, as the NtN handshake expects it.
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
    case noHandshake(RemoteNodeAddress)

    var errorDescription: String? {
        switch self {
            case .timedOut(let address, let seconds):
                return "No answer from \(address) within \(seconds.formatted())s."
            case .noTip(let address):
                return "\(address) closed the chain-sync stream without reporting a tip."
            case .noHandshake(let address):
                return "\(address) accepted the connection but no handshake result came back."
        }
    }
}

/// The network-library configuration for a single NtN connection to `address`.
func remoteNodeConfiguration(
    address: RemoteNodeAddress,
    networkMagic: UInt32,
    timeoutSeconds: Double
) -> CardanoNetworkConfiguration {
    var config = CardanoNetworkConfiguration()
    config.connection.host = address.host
    config.connection.port = address.port
    config.connection.networkMagic = networkMagic
    config.connection.connectTimeoutSeconds = timeoutSeconds
    config.connection.maxReconnectAttempts = 0
    config.logging.level = .critical
    config.logging.destination = "stderr"
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
    try await withThrowingTaskGroup(of: T.self) { group in
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

/// One ping: a TCP connect plus NtN handshake against a remote node.
struct RemotePingResult: Codable, Sendable {
    let sequence: Int
    let milliseconds: Double?
    let nodeToNodeVersion: UInt16?
    let error: String?
}

/// Open an NtN connection to `address`, complete the handshake, and close it,
/// timing the round trip.
func pingRemoteNode(
    _ address: RemoteNodeAddress,
    networkMagic: UInt32,
    timeoutSeconds: Double,
    sequence: Int
) async -> RemotePingResult {
    let config = remoteNodeConfiguration(address: address, networkMagic: networkMagic, timeoutSeconds: timeoutSeconds)
    let clock = ContinuousClock()
    let start = clock.now
    do {
        let version = try await withRemoteTimeout(timeoutSeconds, address: address) {
            let connection = try await CardanoNode.connectToNode(config: config)
            let version = connection.negotiatedVersion?.version
            await connection.close()
            return version
        }
        let elapsed = start.duration(to: clock.now)
        return RemotePingResult(
            sequence: sequence,
            milliseconds: elapsed.milliseconds,
            nodeToNodeVersion: version,
            error: nil
        )
    } catch {
        return RemotePingResult(
            sequence: sequence,
            milliseconds: nil,
            nodeToNodeVersion: nil,
            error: describeRemoteError(error)
        )
    }
}

// MARK: - Tip

/// The chain tip as a remote node reports it over NtN chain-sync.
struct RemoteTip: Codable, Sendable {
    let node: String
    let slot: UInt64?
    let hash: String?
    let block: UInt64
    let nodeToNodeVersion: UInt16?
    let milliseconds: Double
}

/// Ask a remote node for its tip.
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
    return try await withRemoteTimeout(timeoutSeconds, address: address) {
        try await CardanoNode.withNode(config: config) { connection in
            let events: AsyncThrowingStream<ChainEvent, Error> = connection.chainSync.follow()
            var tip: Tip?
            for try await event in events {
                switch event {
                    case .rollBackward(_, let t), .rollForward(_, let t):
                        tip = t
                }
                break
            }
            guard let tip else { throw RemoteNodeError.noTip(address) }

            let slot: UInt64?
            let hash: String?
            switch tip.point {
                case .origin:
                    slot = nil
                    hash = nil
                case .blockPoint(let s, let h):
                    slot = s
                    hash = h.map { String(format: "%02x", $0) }.joined()
            }
            return RemoteTip(
                node: address.description,
                slot: slot,
                hash: hash,
                block: tip.blockNo,
                nodeToNodeVersion: connection.negotiatedVersion?.version,
                milliseconds: start.duration(to: clock.now).milliseconds
            )
        }
    }
}

// MARK: - Handshake query

/// What a remote node agreed to in the NtN handshake.
struct RemoteHandshake: Codable, Sendable {
    let node: String
    let nodeToNodeVersion: UInt16
    let networkMagic: UInt32
    let diffusionMode: String
    let peerSharing: Bool?
    let query: Bool?
    let milliseconds: Double
}

/// Complete the NtN handshake with `address` and report the version and
/// version data the node accepted.
func queryRemoteHandshake(
    _ address: RemoteNodeAddress,
    networkMagic: UInt32,
    timeoutSeconds: Double
) async throws -> RemoteHandshake {
    let config = remoteNodeConfiguration(address: address, networkMagic: networkMagic, timeoutSeconds: timeoutSeconds)
    let clock = ContinuousClock()
    let start = clock.now
    let negotiated = try await withRemoteTimeout(timeoutSeconds, address: address) {
        let connection = try await CardanoNode.connectToNode(config: config)
        let negotiated = connection.negotiatedVersion
        await connection.close()
        return negotiated
    }
    let elapsed = start.duration(to: clock.now).milliseconds
    guard let negotiated else { throw RemoteNodeError.noHandshake(address) }

    switch negotiated.versionData {
        case .nodeToNode(let magic, let initiatorOnly, let peerSharing, let query):
            return RemoteHandshake(
                node: address.description,
                nodeToNodeVersion: negotiated.version,
                networkMagic: magic,
                diffusionMode: initiatorOnly ? "InitiatorOnly" : "InitiatorAndResponder",
                peerSharing: peerSharing.map { $0 == 1 },
                query: query,
                milliseconds: elapsed
            )
        case .nodeToClient(let magic, let query):
            return RemoteHandshake(
                node: address.description,
                nodeToNodeVersion: negotiated.version,
                networkMagic: magic,
                diffusionMode: "NodeToClient",
                peerSharing: nil,
                query: query,
                milliseconds: elapsed
            )
    }
}

// MARK: - Helpers

/// A one-line reason for a failed remote call, without NIO's type noise where we can.
func describeRemoteError(_ error: any Error) -> String {
    if case HandshakeError.refused(let reason) = error {
        switch reason {
            case .versionMismatch(let versions):
                return "the node supports none of our node-to-node versions (it offers \(versions.map(String.init).joined(separator: ", ")))."
            case .handshakeDecodeError(let version, let message):
                return "the node could not decode our v\(version) handshake: \(message)"
            case .refused(let version, let message):
                // cardano-node puts its own version data first; pull out its magic.
                if message.contains("version data mismatch"),
                   let range = message.range(of: #"NetworkMagic (\d+)"#, options: .regularExpression) {
                    let magic = message[range].split(separator: " ").last.map(String.init) ?? "?"
                    return "network magic mismatch: the node is on magic \(magic). Pass --network-magic \(magic)."
                }
                return "the node refused the v\(version) handshake: \(message)"
        }
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
