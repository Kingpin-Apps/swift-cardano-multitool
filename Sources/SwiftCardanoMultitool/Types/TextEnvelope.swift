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
    /// On success, sets the encrHex field and updates the description to indicate encryption.
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
        
        self.encrHex = encHexData.hexEncodedString()
        self.description = (self.description != nil) ? "Encrypted \(self.description!)" : "Encrypted"
    }
    
    /// Decrypt the encrHex field using GPG symmetric decryption with the provided password.
    /// On success, sets the cborHex field and updates the description to remove encryption indication.
    /// - Parameter password: The password to use for decryption.
    /// - Throws: An error if decryption fails or if required fields are missing.
    public mutating func decrypt(with password: String) async throws -> Void {
        var gpg: GnuPG
        
        do {
            gpg = try GnuPG()
            gpg.encoding = .utf8
        } catch {
            throw SwiftCardanoMultitoolError.gpgNotFound
        }
        
        guard let encrHex = encrHex else {
            throw SwiftCardanoMultitoolError.missingField("encrHex")
        }
        
        guard let encData = Data(hexString: encrHex) else {
            throw SwiftCardanoMultitoolError.invalidHex("encrHex")
        }
        
        let args = [
            "--symmetric",
            "--batch",
            "--quiet",
            "--log-file", "/dev/null"
        ]
        
        let outData = await gpg.decrypt(
            data: encData,
            passphrase: password,
            extraArgs: args
        )
        
        guard outData.isSuccessful, let cborData = outData.data else {
            throw SwiftCardanoMultitoolError
                .decryptionError(
                    "Could not decrypt the data via gpg: \(outData.stderr)"
                )
        }
        
        guard let cborString = String(data: cborData, encoding: .utf8), !cborString.isEmpty else {
            throw SwiftCardanoMultitoolError
                .decryptionError("Couldn't decrypt the data via gpg! Wrong password?")
        }
        
        self.cborHex = cborString
        if let desc = description {
            self.description = desc.replacingOccurrences(of: "Encrypted", with: "")
        }
        
    }
    
    /// Load a TextEnvelope from a file, handling decryption if necessary.
    /// If the file is encrypted, prompts for a password (or uses ENV variable) to decrypt it.
    /// - Parameter path: The file path to load from.
    /// - Returns: The loaded (and possibly decrypted) TextEnvelope.
    /// - Throws: An error if loading or decryption fails.
    public static func load(from path: FilePath) async throws -> Self {
        let noora = try await Terminal.shared.noora()
        
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
        
        var textEnvelope = try TextEnvelope.load(from: path.string)
        
        if !textEnvelope.isEncrypted {
            print(
                noora.format(
                    "Reading unencrypted file: \(.path(try .init(validating: path.string)))"
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
                    prompt: "Enter the Password to decrypt: \(.path(try .init(validating: path.string)))",
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
                    "Decrypting the file: \(.path(try .init(validating: path.string))) \(viaEnv)..."
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
