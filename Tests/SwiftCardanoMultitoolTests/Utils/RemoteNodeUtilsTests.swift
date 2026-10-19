import ArgumentParser
import Foundation
import Testing
import SwiftCardanoNetwork
@testable import SwiftCardanoMultitool

@Suite("RemoteNodeAddress")
struct RemoteNodeAddressTests {

    @Test("parses host:port")
    func hostAndPort() {
        let address = RemoteNodeAddress(argument: "relay.example.com:6000")
        #expect(address == RemoteNodeAddress(host: "relay.example.com", port: 6000))
        #expect(address?.description == "relay.example.com:6000")
    }

    @Test("a bare host gets port 3001")
    func bareHost() {
        #expect(RemoteNodeAddress(argument: " 1.2.3.4 ") == RemoteNodeAddress(host: "1.2.3.4", port: 3001))
    }

    @Test("parses bracketed and bare IPv6")
    func ipv6() {
        let bracketed = RemoteNodeAddress(argument: "[2001:db8::1]:3002")
        #expect(bracketed == RemoteNodeAddress(host: "2001:db8::1", port: 3002))
        #expect(bracketed?.description == "[2001:db8::1]:3002")
        #expect(RemoteNodeAddress(argument: "[::1]") == RemoteNodeAddress(host: "::1", port: 3001))
        #expect(RemoteNodeAddress(argument: "2001:db8::1") == RemoteNodeAddress(host: "2001:db8::1", port: 3001))
    }

    @Test("a path is a socket, with ~ expanded")
    func socketPaths() {
        #expect(RemoteNodeAddress(argument: "./node.socket") == .socket(path: "./node.socket"))
        #expect(RemoteNodeAddress(argument: "/ipc/node.socket") == .socket(path: "/ipc/node.socket"))
        let home = RemoteNodeAddress(argument: "~/db/node.socket")
        #expect(home == .socket(path: NSHomeDirectory() + "/db/node.socket"))
        #expect(home?.isSocket == true)
        #expect(home?.protocolName == "node-to-client")
        #expect(RemoteNodeAddress(host: "a").protocolName == "node-to-node")
        #expect(RemoteNodeAddress.socket(path: "/ipc/node.socket").description == "/ipc/node.socket")
    }

    @Test("rejects bad input", arguments: ["", "host:", ":3001", "host:0", "host:65536", "host:abc", "[::1", "[]:3001", "[::1]3001"])
    func rejects(_ input: String) {
        #expect(RemoteNodeAddress(argument: input) == nil)
    }
}

@Suite("Remote node network magic")
struct RemoteNodeMagicTests {

    @Test("maps networks to handshake magic")
    func magicForNetwork() {
        #expect(networkMagic(for: .mainnet) == 764_824_073)
        #expect(networkMagic(for: .preprod) == 1)
        #expect(networkMagic(for: .preview) == 2)
        #expect(networkMagic(for: .custom(42)) == 42)
    }

    @Test("an explicit magic wins over the config")
    func explicitWins() async throws {
        try await Configs.$override.withValue(TestConfigs.make(network: .preview)) {
            let magic = try await resolveNetworkMagic(7)
            #expect(magic == 7)
        }
    }

    @Test("falls back to the config's network")
    func configNetwork() async throws {
        try await Configs.$override.withValue(TestConfigs.make(network: .preview)) {
            let magic = try await resolveNetworkMagic(nil)
            #expect(magic == 2)
        }
    }

    @Test("connections advertise InitiatorOnly and send their own keep-alives")
    func configuration() {
        let tcp = remoteNodeConfiguration(address: RemoteNodeAddress(host: "relay", port: 6000), networkMagic: 2, timeoutSeconds: 3)
        #expect(tcp.connection.host == "relay")
        #expect(tcp.connection.port == 6000)
        #expect(tcp.connection.networkMagic == 2)
        #expect(tcp.protocol.initiatorOnly)
        #expect(tcp.protocol.keepAliveIntervalSeconds == 0)
        #expect(tcp.protocol.keepAliveTimeoutSeconds == 3)

        let socket = remoteNodeConfiguration(address: .socket(path: "/ipc/node.socket"), networkMagic: 1, timeoutSeconds: 3)
        #expect(socket.connection.socketPath == "/ipc/node.socket")
    }

    @Test("NtC versions are shown without bit 15")
    func ntcDisplayVersion() {
        #expect(displayVersion(32791) == 23)
        #expect(displayVersion(15) == 15)
        let ntc = RemoteVersion(QueriedVersion(version: 32791, versionData: .nodeToClient(networkMagic: 2, query: false)))
        #expect(ntc.version == 23)
        #expect(ntc.diffusionMode == nil)
        #expect(ntc.peerSharing == nil)
    }

    @Test("NtN version rows carry diffusion mode, peer sharing and Peras")
    func ntnVersionRow() {
        let row = RemoteVersion(QueriedVersion(
            version: 16,
            versionData: .nodeToNode(networkMagic: 1, initiatorOnly: false, peerSharing: 1, query: false),
            perasSupport: true
        ))
        #expect(row.version == 16)
        #expect(row.diffusionMode == "InitiatorAndResponder")
        #expect(row.peerSharing == true)
        #expect(row.perasSupport == true)
    }

    @Test("a missing socket gets a clear error")
    func missingSocket() async {
        let address = RemoteNodeAddress.socket(path: "/nonexistent/scm-test.socket")
        do {
            _ = try await queryRemoteTip(address, networkMagic: 2, timeoutSeconds: 1)
            Issue.record("expected an error")
        } catch {
            #expect(describeRemoteError(error) == "no socket at /nonexistent/scm-test.socket. Is cardano-node running with --socket-path set to it?")
        }
    }

    @Test("a magic mismatch names the node's magic")
    func mismatchMessage() {
        let error = HandshakeError.refused(.refused(14, "version data mismatch: NodeToNodeVersionData {networkMagic = NetworkMagic 764824073, diffusionMode = InitiatorAndResponderDiffusionMode} /= NodeToNodeVersionData {networkMagic = NetworkMagic 2}"))
        #expect(describeRemoteError(error) == "network magic mismatch: the node is on magic 764824073. Pass --network-magic 764824073.")
    }
}

@Suite("PingMainCommand")
struct PingMainCommandTests {

    @Test("parses nodes and options")
    func parses() throws {
        let cmd = try PingMainCommand.parse(["a.example:3001", "[::1]:3002", "-c", "2", "-i", "0", "-m", "2", "-t", "5", "--json"])
        #expect(cmd.mode == .ping)
        #expect(cmd.nodes == [RemoteNodeAddress(host: "a.example", port: 3001), RemoteNodeAddress(host: "::1", port: 3002)])
        #expect(cmd.count == 2)
        #expect(cmd.interval == 0)
        #expect(cmd.networkMagic == 2)
        #expect(cmd.timeout == 5)
        #expect(cmd.json)
    }

    @Test("parses each mode", arguments: PingMode.allCases)
    func parsesMode(_ mode: PingMode) throws {
        let cmd = try PingMainCommand.parse(["a.example", "--mode", mode.rawValue])
        #expect(cmd.mode == mode)
    }

    @Test("rejects an unknown mode")
    func unknownMode() {
        #expect(throws: (any Error).self) { try PingMainCommand.parse(["a.example", "--mode", "nope"]) }
    }

    @Test("a failed answer encodes as node + error")
    func failedAnswerJSON() throws {
        let answer = RemoteNodeAnswer<RemoteTip>(node: RemoteNodeAddress(host: "a"), error: RemoteNodeError.noTip(RemoteNodeAddress(host: "a")))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = String(decoding: try encoder.encode(answer), as: UTF8.self)
        #expect(json == #"{"error":"a:3001 closed the chain-sync stream without reporting a tip.","node":"a:3001"}"#)
    }

    @Test("ping mode rejects a socket; tip and query accept one")
    func socketModes() throws {
        #expect(throws: (any Error).self) { try PingMainCommand.parse(["./node.socket"]) }
        let tip = try PingMainCommand.parse(["./node.socket", "--mode", "tip"])
        #expect(tip.nodes == [.socket(path: "./node.socket")])
        _ = try PingMainCommand.parse(["./node.socket", "--mode", "query"])
    }

    @Test("rejects a zero count")
    func zeroCount() {
        #expect(throws: (any Error).self) { try PingMainCommand.parse(["a.example", "-c", "0"]) }
    }

    @Test("summary statistics skip lost pings")
    func summary() {
        let summary = PingSummary(node: "a:3001", networkMagic: 2, nodeToNodeVersion: 15, handshakeMilliseconds: [300, 280], pings: [
            RemotePingResult(sequence: 1, milliseconds: 10, error: nil),
            RemotePingResult(sequence: 2, milliseconds: nil, error: "timeout"),
            RemotePingResult(sequence: 3, milliseconds: 30, error: nil),
            RemotePingResult(sequence: 4, milliseconds: 20, error: nil),
        ])
        #expect(summary.sent == 4)
        #expect(summary.received == 3)
        #expect(summary.lossPercent == 25)
        #expect(summary.minMilliseconds == 10)
        #expect(summary.avgMilliseconds == 20)
        #expect(summary.maxMilliseconds == 30)
        #expect(summary.nodeToNodeVersion == 15)
        #expect(summary.handshakeMilliseconds == [300, 280])
    }
}
