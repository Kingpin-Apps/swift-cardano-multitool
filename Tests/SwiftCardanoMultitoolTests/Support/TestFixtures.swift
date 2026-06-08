import Foundation
import SwiftCardanoCore

/// Centralised loader for on-disk JSON fixtures shipped with the test bundle.
///
/// Fixtures live under `Tests/SwiftCardanoMultitoolTests/Support/Fixtures/` and
/// are wired into the bundle via `.copy("Support/Fixtures")` in `Package.swift`.
public enum TestFixtures {

    /// Decode a fixture as `T` from the test bundle.
    public static func load<T: Decodable>(
        _ type: T.Type = T.self,
        fixture name: String,
        ext: String = "json"
    ) throws -> T {
        guard let url = Bundle.module.url(
            forResource: "Fixtures/\(name)", withExtension: ext
        ) else {
            throw FixtureLookupError.notFound("\(name).\(ext)")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// A small but full `ProtocolParameters` instance loaded from a mainnet snapshot.
    public static func sampleProtocolParameters() throws -> ProtocolParameters {
        try load(ProtocolParameters.self, fixture: "protocol-parameters")
    }
}

public enum FixtureLookupError: Error, CustomStringConvertible {
    case notFound(String)
    public var description: String {
        switch self {
            case .notFound(let n): return "Test fixture not found: \(n)"
        }
    }
}
