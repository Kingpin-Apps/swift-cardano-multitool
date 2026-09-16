import Foundation
import SwiftCardanoCore


/// Pool Relay model for stake pool configuration
public struct PoolRelay: Codable, Sendable, Hashable, Equatable {
    public var type: SPORelayType?
    public var host: String?
    public var port: String?
    public var hostType: HostType?
    
    private enum CodingKeys: String, CodingKey {
        case type
        case host
        case port
        case hostType = "host_type"
    }
    
    public init(
        type: SPORelayType? = nil,
        host: String? = nil,
        port: String? = nil,
        hostType: HostType? = nil
    ) {
        self.type = type
        self.host = host
        self.port = port
        
        // Set default hostType based on relay type if not provided
        if let type = type, hostType == nil {
            self.hostType = (type == .ip) ? .ipv4 : .single
        } else {
            self.hostType = hostType
        }
    }
    
    /// Validates the host length (max 64 characters)
    public func validate() throws {
        if let host = host, host.count > 64 {
            throw SwiftCardanoMultitoolError.valueError(
                "The relay host is too long. Max. 64 chars allowed!"
            )
        }
    }
    
    /// Validates the relay entry including type, host content, and port requirements.
    /// Mirrors the bash relay validation logic for pool JSON files.
    public func validateRelayEntry(index: Int) throws {
        // Check relay entry content (host)
        guard let relayEntry = host, !relayEntry.isEmpty else {
            throw SwiftCardanoMultitoolError.valueError(
                "Parameter \"host\" in poolRelays-Array entry \(index) does not exist or is empty!"
            )
        }
        
        if relayEntry.count > 128 {
            throw SwiftCardanoMultitoolError.valueError(
                "The host parameter with content \"\(relayEntry)\" is too long. Max. 128 chars allowed!"
            )
        }
        
        // Check relay type
        guard let relayType = type else {
            throw SwiftCardanoMultitoolError.valueError(
                "Parameter \"type\" in poolRelays-Array entry \(index) does not exist or is empty!"
            )
        }
        
        // Check host type
        guard let entryHostType = hostType else {
            throw SwiftCardanoMultitoolError.valueError(
                "Parameter \"host_type\" in poolRelays-Array entry \(index) does not exist or is empty!"
            )
        }
        
        // Validate port and type combination
        switch relayType {
            case .ip:
                switch entryHostType {
                    case .ipv4, .ipv6:
                        // IPv4 and IPv6 require a port
                        guard let relayPort = port, !relayPort.isEmpty else {
                            throw SwiftCardanoMultitoolError.valueError(
                                "Parameter \"port\" in poolRelays-Array entry \(index) does not exist or is empty!"
                            )
                        }
                    default:
                        throw SwiftCardanoMultitoolError.valueError(
                            "The host_type \"\(entryHostType)\" is not valid for relay type \"ip\". Only \"ipv4\" or \"ipv6\" is supported!"
                        )
                }
            case .dns:
                switch entryHostType {
                    case .single:
                        // DNS single-relay requires a port
                        guard let relayPort = port, !relayPort.isEmpty else {
                            throw SwiftCardanoMultitoolError.valueError(
                                "Parameter \"port\" in poolRelays-Array entry \(index) does not exist or is empty!"
                            )
                        }
                    case .multi:
                        // DNS multi-relay (SRV) does not require a port
                        break
                    default:
                        throw SwiftCardanoMultitoolError.valueError(
                            "The host_type \"\(entryHostType)\" is not valid for relay type \"dns\". Only \"single\" or \"multi\" is supported!"
                        )
                }
        }
    }
}


// MARK: - Ledger Relay conversion

extension PoolRelay {
    /// Create a pool JSON relay entry from an on-chain relay.
    public init(relay: Relay) {
        switch relay {
            case .singleHostAddr(let addr):
                if let ipv6 = addr.ipv6, addr.ipv4 == nil {
                    self.init(type: .ip, host: ipv6.address, port: addr.port.map(String.init), hostType: .ipv6)
                } else {
                    self.init(type: .ip, host: addr.ipv4?.address, port: addr.port.map(String.init), hostType: .ipv4)
                }
            case .singleHostName(let name):
                self.init(type: .dns, host: name.dnsName, port: name.port.map(String.init), hostType: .single)
            case .multiHostName(let name):
                self.init(type: .dns, host: name.dnsName, port: nil, hostType: .multi)
        }
    }

    /// Convert this relay entry to a ledger relay.
    public func toRelay() throws -> Relay {
        guard let type else {
            throw SwiftCardanoMultitoolError.valueError("Relay type is required for each relay.")
        }
        let port = self.port.flatMap { Int($0) }

        switch type {
            case .ip:
                if hostType == .ipv6 {
                    guard let ipv6 = host.flatMap({ IPv6Address($0) }) else {
                        throw SwiftCardanoMultitoolError.valueError("Invalid IPv6 relay address: \(host ?? "")")
                    }
                    return .singleHostAddr(SingleHostAddr(port: port, ipv4: nil, ipv6: ipv6))
                }
                guard let ipv4 = host.flatMap({ IPv4Address($0) }) else {
                    throw SwiftCardanoMultitoolError.valueError("Invalid IPv4 relay address: \(host ?? "")")
                }
                return .singleHostAddr(SingleHostAddr(port: port, ipv4: ipv4, ipv6: nil))
            case .dns:
                if hostType == .multi {
                    return .multiHostName(MultiHostName(dnsName: host))
                }
                return .singleHostName(SingleHostName(port: port, dnsName: host))
        }
    }

    /// A short human-readable form, e.g. `relay.example.com:3001` or `SRV _cardano._tcp.example.com`.
    public var displayString: String {
        let hostString = hostType == .ipv6 ? "[\(host ?? "")]" : (host ?? "")
        if hostType == .multi { return "SRV \(hostString)" }
        return port.map { "\(hostString):\($0)" } ?? hostString
    }

    /// Parse a relay from a command-line string.
    ///
    /// Formats: `ipv4:1.2.3.4:3001`, `ipv6:[2001:db8::1]:3001`, `dns:relay.example.com:3001`,
    /// `srv:_cardano._tcp.example.com`.
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.firstIndex(of: ":") else { return nil }
        let kind = trimmed[..<colon].lowercased()
        let rest = String(trimmed[trimmed.index(after: colon)...])

        func splitHostPort(_ value: String) -> (String, String)? {
            if value.hasPrefix("["), let close = value.firstIndex(of: "]") {
                let host = String(value[value.index(after: value.startIndex)..<close])
                let after = value[value.index(after: close)...]
                guard after.hasPrefix(":") else { return nil }
                return (host, String(after.dropFirst()))
            }
            guard let last = value.lastIndex(of: ":") else { return nil }
            return (String(value[..<last]), String(value[value.index(after: last)...]))
        }
        func validPort(_ port: String) -> Bool {
            guard let value = Int(port) else { return false }
            return (1...65535).contains(value)
        }

        switch kind {
            case "ipv4", "ip":
                guard let (host, port) = splitHostPort(rest), IPv4Address(host) != nil, validPort(port) else { return nil }
                self.init(type: .ip, host: host, port: port, hostType: .ipv4)
            case "ipv6":
                guard let (host, port) = splitHostPort(rest), IPv6Address(host) != nil, validPort(port) else { return nil }
                self.init(type: .ip, host: host, port: port, hostType: .ipv6)
            case "dns":
                guard let (host, port) = splitHostPort(rest), !host.isEmpty, host.count <= 64, validPort(port) else { return nil }
                self.init(type: .dns, host: host, port: port, hostType: .single)
            case "srv":
                guard !rest.isEmpty, rest.count <= 64 else { return nil }
                self.init(type: .dns, host: rest, port: nil, hostType: .multi)
            default:
                return nil
        }
    }
}
