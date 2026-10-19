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

    @Test("rejects a zero count")
    func zeroCount() {
        #expect(throws: (any Error).self) { try PingMainCommand.parse(["a.example", "-c", "0"]) }
    }

    @Test("summary statistics skip lost pings")
    func summary() {
        let summary = PingSummary(node: "a:3001", networkMagic: 2, pings: [
            RemotePingResult(sequence: 1, milliseconds: 10, nodeToNodeVersion: 14, error: nil),
            RemotePingResult(sequence: 2, milliseconds: nil, nodeToNodeVersion: nil, error: "timeout"),
            RemotePingResult(sequence: 3, milliseconds: 30, nodeToNodeVersion: 14, error: nil),
            RemotePingResult(sequence: 4, milliseconds: 20, nodeToNodeVersion: 14, error: nil),
        ])
        #expect(summary.sent == 4)
        #expect(summary.received == 3)
        #expect(summary.lossPercent == 25)
        #expect(summary.minMilliseconds == 10)
        #expect(summary.avgMilliseconds == 20)
        #expect(summary.maxMilliseconds == 30)
        #expect(summary.nodeToNodeVersion == 14)
    }
}
