
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

