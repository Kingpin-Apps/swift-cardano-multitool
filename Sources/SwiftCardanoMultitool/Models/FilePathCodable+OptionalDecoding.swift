import Foundation
import SwiftCardanoUtils

// MARK: - Optional decoding for @FilePathCodable

/// Makes `@FilePathCodable` fields genuinely optional when decoding.
///
/// The wrapper's wrapped value is `FilePath?`, but the wrapper *type* itself is a
/// non-optional struct, so the compiler-synthesised `Decodable` conformance emits
/// `try container.decode(FilePathCodable.self, forKey: key)` (not
/// `decodeIfPresent`). That meant every `@FilePathCodable` key had to be physically
/// present in the JSON or decoding failed with `keyNotFound` — e.g. a hand-written
/// or partial `pool.json` had to spell out `id_hex_file`, `kes_vkey`, `payment_skey`,
/// … even when they were unused.
///
/// Providing this concrete-type overload of `decode(_:forKey:)` lets the synthesised
/// initialiser treat an absent key as `nil` (and a present `null` as `nil` too),
/// matching the declared `FilePath?` optionality. It applies to every type in this
/// module that uses `@FilePathCodable` (`Pool`, `PoolOwner`, `PoolRegistration`,
/// `PoolDeregistration`, …).
extension KeyedDecodingContainer {
    func decode(_ type: FilePathCodable.Type, forKey key: Key) throws -> FilePathCodable {
        try decodeIfPresent(FilePathCodable.self, forKey: key) ?? FilePathCodable(wrappedValue: nil)
    }
}
