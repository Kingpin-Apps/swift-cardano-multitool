import SwiftCardanoCore
import ArgumentParser
import Foundation
import SystemPackage
import Noora
import GnuPG

public struct TextEnvelope: JSONLoadable, Sendable {
    public var type: String?
    public var description: String?
    public var cborHex: String?
    public var encrHex: String?
    public var path: String?
    public var cborXPubKeyHex: String?
    
    public var isHardwareKey: Bool {
        if let desc = description?.lowercased() {
            return desc.contains("hardware") || desc.contains("ledger") || desc.contains("trezor")
        }
        return false
    }
    
    /// Computed property to determine key generation method based on available fields
    public var keyGenType: KeyGenMethod? {
        if isHardwareKey {
            return .hw
        } else if encrHex != nil {
            return .enc
        } else {
            return .cli
        }
    }
    
    /// Check if the key is encrypted
    public var isEncrypted: Bool {
        return encrHex != nil && (description?.contains("Encrypted") ?? false)
    }
    
    /// Encrypt the cborHex field using GPG symmetric encryption with the provided password.
    /// On success, sets the encrHex field, clears the plaintext cborHex and updates the
    /// description to indicate encryption. The ciphertext is verified to decrypt back to the
    /// original cborHex before the plaintext is dropped.
    /// - Parameter password: The password to use for encryption.
    /// - Throws: An error if encryption fails or if the key is already encrypted.
    public mutating func encrypt(with password: String) async throws -> Void {
        var gpg: GnuPG
        
        do {
            gpg = try GnuPG()
            gpg.encoding = .utf8
        } catch {
            throw SwiftCardanoMultitoolError.gpgNotFound
        }
        
        if let _description = description, _description.contains("Encrypted") || encrHex != nil {
            throw SwiftCardanoMultitoolError.encryptionError("It is already encrypted!")
        }
        
        if let _type = type, !_type.contains("SigningKey") {
            throw SwiftCardanoMultitoolError.encryptionError("Type field does not contain 'SigningKey' information!")
        }
        
        guard let cbor = cborHex, let inputData = cbor.data(using: .utf8) else {
            throw SwiftCardanoMultitoolError.missingField("cborHex")
        }
        
        // gpg args: symmetric encrypt with AES256, passphrase via CLI, quiet and batch mode
        let args = [
            "--batch",
            "--quiet",
            "--log-file", "/dev/null"
        ]
        
        let encData = await gpg.encryptSymmetric(
            data: inputData,
            passphrase: password,
            cipher: "AES256",
            extraArgs: args
        )
        
        guard encData.isSuccessful, let encHexData = encData.data else {
            throw SwiftCardanoMultitoolError
                .encryptionError(
                    "Could not encrypt the data via gpg: \(encData.stderr)"
                )
        }
        
        let encrypted = encHexData.hexEncodedString()

        // Verify the ciphertext decrypts back to the exact same cborHex before dropping
        // the plaintext, otherwise the signing key would be unrecoverable.
        let roundTrip = try await Self.decryptHex(encrypted, with: password)
        guard roundTrip == cbor else {
            throw SwiftCardanoMultitoolError.encryptionError(
                "Verification failed: the encrypted key does not decrypt back to the original cborHex."
            )
        }

        self.encrHex = encrypted
        self.cborHex = nil
        self.description = (self.description != nil) ? "Encrypted \(self.description!)" : "Encrypted"
    }

    /// GPG-symmetric-decrypt a hex-encoded blob back to its plaintext string.
    /// - Parameters:
    ///   - hex: The hex-encoded ciphertext.
    ///   - password: The password to decrypt with.
    /// - Returns: The decrypted plaintext.
    /// - Throws: An error if gpg is unavailable, the hex is invalid, or decryption fails.
    private static func decryptHex(_ hex: String, with password: String) async throws -> String {
        var gpg: GnuPG

        do {
            gpg = try GnuPG()
            gpg.encoding = .utf8
        } catch {
            throw SwiftCardanoMultitoolError.gpgNotFound
        }

        guard let encData = Data(hexString: hex) else {
            throw SwiftCardanoMultitoolError.invalidHex("encrHex")
        }

        // No "--symmetric" here: gpg.decrypt already passes "--decrypt", and gpg rejects
        // the two together with "conflicting commands".
        let args = [
            "--batch",
            "--quiet",
            "--log-file", "/dev/null"
        ]

        let outData = await gpg.decrypt(
            data: encData,
            passphrase: password,
            extraArgs: args
        )

        // Require both gpg's own verdict and usable plaintext. `isSuccessful` needs
        // swift-gnupg >= 0.1.6, which is the first release to recognise gpg's DECRYPTION_OKAY
        // status; before that it read every successful symmetric decryption as a failure.
        guard outData.isSuccessful,
              let cborData = outData.data, !cborData.isEmpty,
              let cborString = String(data: cborData, encoding: .utf8),
              !cborString.isEmpty
        else {
            throw SwiftCardanoMultitoolError
                .decryptionError("Couldn't decrypt the data via gpg! Wrong password?")
        }

        return cborString
    }

    /// Strip the "Encrypted" marker that ``encrypt(with:)`` prefixes onto the description.
    /// - Parameter description: The description to strip.
    /// - Returns: The description without the marker or its trailing separator.
    static func strippingEncryptedMarker(_ description: String) -> String {
        guard description.hasPrefix("Encrypted") else { return description }
        return String(description.dropFirst("Encrypted".count))
            .trimmingCharacters(in: .whitespaces)
    }
    
    /// Decrypt the encrHex field using GPG symmetric decryption with the provided password.
    /// On success, sets the cborHex field, clears the encrHex field and updates the description
    /// to remove the encryption indication.
    /// - Parameter password: The password to use for decryption.
    /// - Throws: An error if decryption fails or if required fields are missing.
    public mutating func decrypt(with password: String) async throws -> Void {
        guard let encrHex = encrHex else {
            throw SwiftCardanoMultitoolError.missingField("encrHex")
        }

        let cbor = try await Self.decryptHex(encrHex, with: password)

        // The payload must be the hex-encoded CBOR we encrypted; anything else means we
        // decoded garbage rather than the key.
        guard Data(hexString: cbor) != nil else {
            throw SwiftCardanoMultitoolError
                .decryptionError("Decrypted payload is not valid hex! Wrong password?")
        }

        self.cborHex = cbor
        self.encrHex = nil
        if let desc = description {
            self.description = Self.strippingEncryptedMarker(desc)
        }
    }
    
    /// Load a TextEnvelope exactly as it is stored on disc, without decrypting it.
    ///
    /// Use this instead of ``load(from:)-(FilePath)`` when the caller needs to see whether the
    /// file is encrypted, because that overload transparently decrypts and so always reports
    /// an encrypted file as decrypted.
    /// - Parameter path: The file path to load from.
    /// - Returns: The envelope as stored, still encrypted when the file is encrypted.
    /// - Throws: An error if the file is missing or cannot be decoded.
    public static func loadRaw(from path: FilePath) throws -> Self {
        do {
            try FileUtils.checkFileExists(path)
        } catch {
            noora.error(
                .alert(
                    "File does not exist: \(path.string)",
                    takeaways: [
                        "Check the path and try again.",
                        "Ensure you have access to the file.",
                    ]
                )
            )
            throw ExitCode.failure
        }

        return try TextEnvelope.load(from: path.string)
    }

    /// Load a TextEnvelope from a file, handling decryption if necessary.
    /// If the file is encrypted, prompts for a password (or uses ENV variable) to decrypt it.
    /// - Parameter path: The file path to load from.
    /// - Returns: The loaded (and possibly decrypted) TextEnvelope.
    /// - Throws: An error if loading or decryption fails.
    public static func load(from path: FilePath) async throws -> Self {
        var textEnvelope = try TextEnvelope.loadRaw(from: path)
        
        if !textEnvelope.isEncrypted {
            print(
                noora.format(
                    "Reading unencrypted file: \(pathComponent(path.string))"
                ),
                terminator: "\n\n"
            )
            return textEnvelope
        }
        
        var decrypted: TextEnvelope? = nil
        while decrypted == nil {
            let envPassword = Environment.get(.decryptPassword)
            
            let password: String
            var viaEnv = ""
            
            if let _envPassword = envPassword {
                // validate strength
                if !PasswordUtils(_envPassword).isValid {
                    noora.error(
                        .alert(
                            "This is not a strong password via \(Environment.decryptPassword.rawValue)... abort!",
                            takeaways: [
                                "Please provide a strong password that meets the criteria.",
                                "Ensure the password is at least 10 characters long and includes a mix of uppercase letters, lowercase letters, numbers, and special characters.",
                            ]
                        )
                    )
                    throw ExitCode.validationFailure
                }
                password = _envPassword
                viaEnv = "via ENV_DECRYPT_PASSWORD "
            } else {
                password = try await PasswordUtils.getSecurePassword(
                    prompt: "Enter the Password to decrypt: \(pathComponent(path.string))",
                    allowEmpty: false,
                    validateStrength: true
                )
            }
            
            // validate required fields before decrypt
            guard textEnvelope.type != nil else {
                noora.error(
                    .alert("Can't read the \(.primary("type")) field of the file: \(path.string)")
                )
                throw ExitCode.failure
            }
            guard textEnvelope.description != nil else {
                noora.error(
                    .alert("Can't read the \(.primary("description")) field of the file: \(path.string)")
                )
                throw ExitCode.failure
            }
            guard textEnvelope.encrHex != nil else {
                noora.error(
                    .alert("Can't read the encrHex \(.primary("encrHex")) of the file: \(path.string)")
                )
                throw ExitCode.failure
            }
            
            print(
                noora.format(
                    "Decrypting the file: \(pathComponent(path.string)) \(viaEnv)..."
                ),
                terminator: "\n\n"
            )
            
            do {
                try await textEnvelope.decrypt(with: password)
                decrypted = textEnvelope
            } catch {
                // in Python they loop until success, so give user chance to retry
                print("Couldn't decrypt: \(String(describing: error)). Try again.")
                // if ENV provided, abort, because it shouldn't loop silently in env case
                if envPassword != nil {
                    noora.error(
                        .alert(
                            "Couldn't decrypt the file \(path.string) with the provided password.",
                            takeaways: [
                                "Ensure that the password provided via \(Environment.decryptPassword.rawValue) is correct.",
                                "Make sure the file is a valid encrypted file.",
                            ]
                        )
                    )
                    throw ExitCode.failure
                } else {
                    textEnvelope = try TextEnvelope.load(from: path.string)
                    noora.warning("Couldn't decrypt the file \(path.string) with the provided password. Let's try it again...\n")
                }
            }
        }
        
        return decrypted!
    }
}
