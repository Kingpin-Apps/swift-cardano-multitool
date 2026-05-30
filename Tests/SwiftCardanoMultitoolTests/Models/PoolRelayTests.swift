import Testing
@testable import SwiftCardanoMultitool

@Suite("PoolRelay default host type")
struct PoolRelayDefaultsTests {

    @Test("ip relay defaults hostType to ipv4")
    func ipDefaultsToIpv4() {
        let relay = PoolRelay(type: .ip, host: "1.2.3.4", port: "3001")
        #expect(relay.hostType == .ipv4)
    }

    @Test("dns relay defaults hostType to single")
    func dnsDefaultsToSingle() {
        let relay = PoolRelay(type: .dns, host: "relay.example.com", port: "3001")
        #expect(relay.hostType == .single)
    }

    @Test("explicit hostType is preserved")
    func explicitHostTypePreserved() {
        let relay = PoolRelay(type: .ip, host: "::1", port: "3001", hostType: .ipv6)
        #expect(relay.hostType == .ipv6)
    }

    @Test("nil type leaves hostType nil unless provided")
    func nilTypeNilHostType() {
        let relay = PoolRelay()
        #expect(relay.hostType == nil)
    }
}

@Suite("PoolRelay.validate")
struct PoolRelayValidateTests {

    @Test("accepts host within 64 characters")
    func acceptsShortHost() throws {
        let relay = PoolRelay(type: .dns, host: "relay.example.com")
        try relay.validate()
    }

    @Test("rejects host longer than 64 characters")
    func rejectsTooLongHost() {
        let host = String(repeating: "a", count: 65)
        let relay = PoolRelay(type: .dns, host: host)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validate()
        }
    }
}

@Suite("PoolRelay.validateRelayEntry")
struct PoolRelayValidateEntryTests {

    @Test("accepts a complete IPv4 relay")
    func acceptsIpv4() throws {
        let relay = PoolRelay(type: .ip, host: "1.2.3.4", port: "3001", hostType: .ipv4)
        try relay.validateRelayEntry(index: 0)
    }

    @Test("accepts a DNS multi relay without a port")
    func acceptsDnsMultiNoPort() throws {
        let relay = PoolRelay(type: .dns, host: "srv.example.com", port: nil, hostType: .multi)
        try relay.validateRelayEntry(index: 0)
    }

    @Test("rejects an entry with an empty host")
    func rejectsEmptyHost() {
        let relay = PoolRelay(type: .ip, host: "", port: "3001", hostType: .ipv4)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validateRelayEntry(index: 1)
        }
    }

    @Test("rejects a host longer than 128 characters")
    func rejectsHostTooLong() {
        let host = String(repeating: "x", count: 129)
        let relay = PoolRelay(type: .ip, host: host, port: "3001", hostType: .ipv4)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validateRelayEntry(index: 0)
        }
    }

    @Test("rejects an entry missing the relay type")
    func rejectsMissingType() {
        let relay = PoolRelay(type: nil, host: "1.2.3.4", port: "3001", hostType: .ipv4)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validateRelayEntry(index: 0)
        }
    }

    @Test("rejects an entry missing the host type")
    func rejectsMissingHostType() {
        // Force hostType to nil by passing it explicitly.
        var relay = PoolRelay(type: .ip, host: "1.2.3.4", port: "3001", hostType: .ipv4)
        relay.hostType = nil
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validateRelayEntry(index: 0)
        }
    }

    @Test("rejects an IP relay missing a port")
    func rejectsIpv4MissingPort() {
        let relay = PoolRelay(type: .ip, host: "1.2.3.4", port: nil, hostType: .ipv4)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validateRelayEntry(index: 0)
        }
    }

    @Test("rejects an IP relay with a DNS-style host type")
    func rejectsIpWithSingleHostType() {
        let relay = PoolRelay(type: .ip, host: "1.2.3.4", port: "3001", hostType: .single)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validateRelayEntry(index: 0)
        }
    }

    @Test("rejects a DNS single relay missing a port")
    func rejectsDnsSingleMissingPort() {
        let relay = PoolRelay(type: .dns, host: "a.example.com", port: nil, hostType: .single)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validateRelayEntry(index: 0)
        }
    }

    @Test("rejects a DNS relay with an IPv4 host type")
    func rejectsDnsWithIpv4HostType() {
        let relay = PoolRelay(type: .dns, host: "a.example.com", port: "3001", hostType: .ipv4)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try relay.validateRelayEntry(index: 0)
        }
    }
}
