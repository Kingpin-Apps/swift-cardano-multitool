import Foundation
import ArgumentParser
import SwiftCardanoCore
import SystemPackage


extension PoolOperator: @retroactive _SendableMetatype {}
extension PoolOperator: @retroactive ExpressibleByArgument {
    /// Byte length of a pool key hash (blake2b-224).
    static let poolKeyHashSize = 28

    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let resolved = Self.resolve(trimmed),
              resolved.poolKeyHash.payload.count == Self.poolKeyHashSize else {
            return nil
        }
        self = resolved
    }

    private static func resolve(_ trimmed: String) -> PoolOperator? {
        // Try Bech32 first
        if trimmed.hasPrefix("pool1") {
            return try? PoolOperator(from: trimmed)
        }

        // Bech32 cold verification key (pool_vk1...), as printed by cardano-cli
        if trimmed.hasPrefix("pool_vk1") {
            let bech32 = Bech32()
            guard let (hrp, _, _) = try? bech32.bech32Decode(trimmed), hrp == "pool_vk",
                  let data = bech32.decode(addr: trimmed) else {
                return nil
            }
            return fromColdVerificationKey(data)
        }

        // Try hex string format (supports optional 0x prefix)
        let hexCandidate: String
        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            hexCandidate = String(trimmed.dropFirst(2))
        } else {
            hexCandidate = trimmed
        }

        let hexSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        let isValidHex = !hexCandidate.isEmpty
            && hexCandidate.count % 2 == 0
            && hexCandidate.unicodeScalars.allSatisfy { hexSet.contains($0) }

        if isValidHex {
            let data = hexCandidate.hexStringToData
            // 32 bytes is a cold verification key rather than a pool ID
            if data.count == 32 {
                return fromColdVerificationKey(data)
            }
            if !data.isEmpty {
                return try? PoolOperator(from: data)
            }
        }

        // Otherwise treat as a file path or a base name in the current directory
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        func path(_ name: String) -> String {
            name.hasPrefix("/") ? name : (currentDir as NSString).appendingPathComponent(name)
        }

        if fileManager.fileExists(atPath: path(trimmed)) {
            return fromFile(path(trimmed))
        }

        let variations = [
            "\(trimmed).node.vkey",
            "\(trimmed).pool.id",
            "\(trimmed).pool.id-bech",
        ]
        for fileName in variations where fileManager.fileExists(atPath: path(fileName)) {
            if let loaded = fromFile(path(fileName)) {
                return loaded
            }
        }

        return nil
    }

    private static func fromColdVerificationKey(_ payload: Data) -> PoolOperator? {
        guard payload.count == 32,
              let vkey = try? StakePoolVerificationKey(payload: payload),
              let poolKeyHash = try? vkey.poolKeyHash() else { return nil }
        return PoolOperator(poolKeyHash: poolKeyHash)
    }

    /// Load a pool operator from a cold verification/signing key file or a pool ID file.
    ///
    /// Key files must be dispatched on their envelope type: key loading doesn't check
    /// the type, so reading a key file as a pool ID (or a signing key as a verification
    /// key) silently yields the wrong pool hash.
    private static func fromFile(_ filePath: String) -> PoolOperator? {
        if let vkey = try? StakePoolVerificationKey.load(from: filePath) {
            if vkey._type.contains("SigningKey") {
                guard let skey = try? StakePoolSigningKey.load(from: filePath),
                      let derived: StakePoolVerificationKey = try? skey.toVerificationKey(),
                      let poolKeyHash = try? derived.poolKeyHash() else {
                    return nil
                }
                return PoolOperator(poolKeyHash: poolKeyHash)
            }
            if vkey._type.contains("VerificationKey") {
                guard let poolKeyHash = try? vkey.poolKeyHash() else { return nil }
                return PoolOperator(poolKeyHash: poolKeyHash)
            }
        }

        return try? PoolOperator.load(from: filePath)
    }
}
