import Foundation
import SystemPackage
import SwiftCardanoCore
import ArgumentParser
import OrderedCollections

#if canImport(CommonCrypto)
import CommonCrypto
#elseif canImport(_CryptoExtras)
import Crypto
import _CryptoExtras
#endif

/// Transaction message encryption utilities
public struct TransactionMessage {
    
    /// Encryption mode for transaction messages
    public enum EncryptionMode: String, ExpressibleByArgument {
        case basic = "basic"
        case none = "none"
    }
    
    /// Build a transaction message metadata JSON
    /// - Parameters:
    ///   - messages: Array of message strings (max 64 bytes each)
    ///   - encryption: Encryption mode to use
    ///   - passphrase: Passphrase for encryption (only used if encryption is .basic)
    /// - Returns: JSON string for the transaction metadata
    /// - Throws: Error if JSON encoding fails or encryption fails
    public static func buildMetadata(
        messages: [String],
        encryption: EncryptionMode = .none,
        passphrase: String = "cardano"
    ) throws -> String? {
        guard !messages.isEmpty else {
            return nil
        }
        
        var metadata: [String: Any] = [:]
        
        switch encryption {
            case .basic:
                // Encrypt the messages
                let msgArray = messages
                let encryptedMessages = try encryptMessagesBasic(messages: msgArray, passphrase: passphrase)
                
                metadata["674"] = [
                    "enc": "basic",
                    "msg": encryptedMessages
                ]
                
            case .none:
                // Plain text messages
                metadata["674"] = [
                    "msg": messages
                ]
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw TransactionMessageError.jsonEncodingFailed
        }
        
        return jsonString
    }
    
    public static func buildAuxiliaryData(
        messages: [String]? = nil,
        encryption: EncryptionMode = .none,
        passphrase: String = "cardano",
        metadataJson: [FilePath]? = nil,
        metadataCbor: [FilePath]? = nil
    ) throws -> AuxiliaryData? {
        guard messages != nil || metadataJson != nil || metadataCbor != nil else {
            return nil
        }
        
        if messages?.isEmpty == true, metadataJson?.isEmpty == true, metadataCbor?.isEmpty == true {
            return nil
        }
        
        var allMetadata = try Metadata([:])
        
        let transactionMessageMetadata: Metadata
        if let messages = messages, !messages.isEmpty {
            
            switch encryption {
                case .basic:
                    // Encrypt the messages
                    let encryptedMessages = try encryptMessagesBasic(messages: messages, passphrase: passphrase)
                    
                    transactionMessageMetadata = try Metadata(
                        [
                            674: .map(
                                OrderedDictionary(
                                    uniqueKeysWithValues: [
                                        .text("enc"): .text("basic"),
                                        .text("msg"): .list(encryptedMessages.map({ .text($0) })),
                                    ]
                                )
                            ),
                        ]
                    )
                case .none:
                    // Plain text messages
                    transactionMessageMetadata = try Metadata(
                        [
                            674: .map(
                                OrderedDictionary(
                                    uniqueKeysWithValues: [
                                        .text("msg"): .list(messages.map({ .text($0) })),
                                    ]
                                )
                            ),
                        ]
                    )
            }
            
            allMetadata.data.merge(transactionMessageMetadata.data) { (_, new) in
                return new
            }
        }
        
        if let metadataJson = metadataJson,!metadataJson.isEmpty {
            for file in metadataJson {
                let metadata = try Metadata.loadJSON(from: file.string)
                allMetadata.data.merge(metadata.data) { (_, new) in
                    return new
                }
            }
        }
        
        if let metadataCbor = metadataCbor, !metadataCbor.isEmpty {
            for file in metadataCbor {
                let metadataData = try Data(contentsOf: URL(fileURLWithPath: file.string))
                let metadata = try Metadata(from: metadataData)
                allMetadata.data.merge(metadata.data) { (_, new) in
                    return new
                }
            }
        }
        
        let auxiliaryData = AuxiliaryData(data:
                .alonzoMetadata(AlonzoMetadata(metadata: allMetadata))
        )
                                          
        return auxiliaryData
    }
        
    
    /// Encrypt messages using basic AES-256-CBC encryption
    /// - Parameters:
    ///   - messages: Array of messages to encrypt (combined as one string)
    ///   - passphrase: Passphrase for encryption
    /// - Returns: Array of base64-encoded encrypted message chunks
    /// - Throws: Error if encryption fails
    private static func encryptMessagesBasic(
        messages: [String],
        passphrase: String
    ) throws -> [String] {
        // Combine messages into a single JSON array string like bash script does
        let msgJSON = try JSONSerialization.data(withJSONObject: messages, options: [])
        guard let msgString = String(data: msgJSON, encoding: .utf8) else {
            throw TransactionMessageError.messageCombineFailed
        }
        
        // Use the same encryption method as bash: AES-256-CBC with PBKDF2
        let encryptedData = try encryptAES256CBC(
            plaintext: msgString,
            passphrase: passphrase,
            iterations: 10000
        )
        
        // Convert to base64 and split into chunks (matching bash output format)
        let base64String = encryptedData.base64EncodedString()
        
        // Split into chunks similar to bash awk command output
        // Each line in base64 encoding is typically 64-76 characters
        let chunkSize = 64
        var chunks: [String] = []
        var currentIndex = base64String.startIndex
        
        while currentIndex < base64String.endIndex {
            let endIndex = base64String.index(
                currentIndex,
                offsetBy: chunkSize,
                limitedBy: base64String.endIndex
            ) ?? base64String.endIndex
            
            let chunk = String(base64String[currentIndex..<endIndex])
            chunks.append(chunk)
            currentIndex = endIndex
        }
        
        return chunks
    }
    
    /// Encrypt data using AES-256-CBC with PBKDF2 key derivation
    /// Matches OpenSSL's `enc -e -aes-256-cbc -pbkdf2 -iter 10000` behavior
    /// - Parameters:
    ///   - plaintext: The plaintext string to encrypt
    ///   - passphrase: The passphrase to derive the key from
    ///   - iterations: Number of PBKDF2 iterations (default 10000)
    /// - Returns: Encrypted data in OpenSSL format (with Salted__ prefix)
    /// - Throws: Error if encryption fails
    private static func encryptAES256CBC(
        plaintext: String,
        passphrase: String,
        iterations: Int = 10000
    ) throws -> Data {
        guard let plaintextData = plaintext.data(using: .utf8) else {
            throw TransactionMessageError.invalidPlaintext
        }
        
        // Generate a random 8-byte salt (matching OpenSSL behavior). Uses the
        // platform's cryptographically secure RNG via SystemRandomNumberGenerator.
        var rng = SystemRandomNumberGenerator()
        let salt = Data((0..<8).map { _ in rng.next() as UInt8 })
        
        // Derive key and IV using PBKDF2 (matching OpenSSL's EVP_BytesToKey with PBKDF2)
        guard let passphraseData = passphrase.data(using: .utf8) else {
            throw TransactionMessageError.invalidPassphrase
        }
        
        // OpenSSL derives 32 bytes for key + 16 bytes for IV = 48 bytes total
        let derivedData = try deriveKeyAndIV(
            password: passphraseData,
            salt: salt,
            keyLength: 32,  // AES-256
            ivLength: 16,   // AES block size
            iterations: iterations
        )
        
        let key = derivedData.prefix(32)
        let iv = derivedData.suffix(16)
        
        // Encrypt using AES-256-CBC
        let encryptedData = try encryptAES(
            data: plaintextData,
            key: key,
            iv: iv
        )
        
        // Prepend "Salted__" magic bytes and salt (matching OpenSSL format)
        var saltedResult = Data("Salted__".utf8)
        saltedResult.append(salt)
        saltedResult.append(encryptedData)
        
        return saltedResult
    }
    
    /// Derive key and IV using PBKDF2 (matching OpenSSL behavior)
    private static func deriveKeyAndIV(
        password: Data,
        salt: Data,
        keyLength: Int,
        ivLength: Int,
        iterations: Int
    ) throws -> Data {
        let totalLength = keyLength + ivLength
        
        #if canImport(CommonCrypto)
        // Use CommonCrypto's CCKeyDerivationPBKDF to match OpenSSL behavior exactly
        var derivedKeyData = Data(count: totalLength)
        let derivationStatus = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        totalLength
                    )
                }
            }
        }
        
        guard derivationStatus == kCCSuccess else {
            throw TransactionMessageError.keyDerivationFailed(Int(derivationStatus))
        }

        return derivedKeyData
        #elseif canImport(_CryptoExtras)
        // swift-crypto's PBKDF2 (HMAC-SHA256), matching the CommonCrypto path.
        // `unsafeUncheckedRounds` is required because OpenSSL-compatible output
        // uses 10,000 iterations, below the safe-API minimum of 210,000.
        let derivedKey = try KDF.Insecure.PBKDF2.deriveKey(
            from: password,
            salt: salt,
            using: .sha256,
            outputByteCount: totalLength,
            unsafeUncheckedRounds: iterations
        )
        return derivedKey.withUnsafeBytes { Data($0) }
        #else
        throw TransactionMessageError.encryptionNotSupported
        #endif
    }
    
    /// Encrypt data using AES-256-CBC
    private static func encryptAES(data: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == 32, iv.count == 16 else {
            throw TransactionMessageError.invalidKeyOrIV
        }
        
        // CryptoKit doesn't expose CBC, so use CommonCrypto on Apple platforms.
        #if canImport(CommonCrypto)
        return try encryptUsingCommonCrypto(data: data, key: key, iv: iv)
        #elseif canImport(_CryptoExtras)
        // swift-crypto's AES-CBC with PKCS7 padding (the default), matching
        // CommonCrypto's kCCOptionPKCS7Padding behavior.
        let symmetricKey = SymmetricKey(data: key)
        let cbcIV = try AES._CBC.IV(ivBytes: Array(iv))
        return try AES._CBC.encrypt(data, using: symmetricKey, iv: cbcIV)
        #else
        throw TransactionMessageError.encryptionNotSupported
        #endif
    }
    
    #if canImport(CommonCrypto)
    /// Encrypt using CommonCrypto (for CBC mode)
    private static func encryptUsingCommonCrypto(data: Data, key: Data, iv: Data) throws -> Data {
        let keyBytes = [UInt8](key)
        let ivBytes = [UInt8](iv)
        let dataBytes = [UInt8](data)
        
        var encryptedBytes = [UInt8](repeating: 0, count: dataBytes.count + kCCBlockSizeAES128)
        var numBytesEncrypted = 0
        
        let cryptStatus = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            keyBytes,
            key.count,
            ivBytes,
            dataBytes,
            dataBytes.count,
            &encryptedBytes,
            encryptedBytes.count,
            &numBytesEncrypted
        )
        
        guard cryptStatus == kCCSuccess else {
            throw TransactionMessageError.encryptionFailed(Int(cryptStatus))
        }
        
        return Data(bytes: encryptedBytes, count: numBytesEncrypted)
    }
    #endif
}

/// Transaction message errors
public enum TransactionMessageError: Error, LocalizedError {
    case jsonEncodingFailed
    case messageCombineFailed
    case invalidPlaintext
    case saltGenerationFailed
    case invalidPassphrase
    case invalidKeyOrIV
    case keyDerivationFailed(Int)
    case encryptionFailed(Int)
    case encryptionNotSupported
    
    public var errorDescription: String? {
        switch self {
        case .jsonEncodingFailed:
            return "Failed to encode metadata as JSON"
        case .messageCombineFailed:
            return "Failed to combine messages"
        case .invalidPlaintext:
            return "Invalid plaintext data"
        case .saltGenerationFailed:
            return "Failed to generate random salt"
        case .invalidPassphrase:
            return "Invalid passphrase"
        case .invalidKeyOrIV:
            return "Invalid key or IV length"
        case .keyDerivationFailed(let status):
            return "Key derivation failed with status: \(status)"
        case .encryptionFailed(let status):
            return "Encryption failed with status: \(status)"
        case .encryptionNotSupported:
            return "AES-CBC encryption is not supported on this platform"
        }
    }
}
