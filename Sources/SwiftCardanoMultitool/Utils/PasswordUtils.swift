import Foundation
import ArgumentParser
import Noora
import SystemPackage
import Darwin
#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif


public class PasswordUtils {
    public let password: String
    private static let specialChars = CharacterSet(charactersIn: "!@#$%^&*()?")
    
    public init(_ password: String) {
        self.password = password
    }
    
    public var isValid: Bool {
        let isVulnerable = (try? isVulnerable()) ?? false
        return isStrong() && !isVulnerable
    }
    
    public func isVulnerable() throws -> Bool {
        // Locate `passwords.txt` next to the running executable
        guard let pwFile = Bundle.module.path(forResource: "passwords", ofType: "txt", inDirectory: "Resources") else {
            throw SwiftCardanoMultitoolError.fileNotFound(FilePath("passwords.txt"))
        }
        guard let content = try? String(contentsOfFile: pwFile, encoding: .utf8) else {
            return false
        }
        for line in content.split(separator: "\n") {
            let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            if PasswordUtils.compareDigest(trimmed, password) {
                return true
            }
        }
        return false
    }
    
    public func isStrong() -> Bool {
        // No spaces, minimum length, at least one lower, one upper, one digit and one special char
        if password.contains(" ") { return false }
        if password.count < 10 { return false }
        
        var hasLower = false
        var hasUpper = false
        var hasDigit = false
        var hasSpecial = false
        
        for scalar in password.unicodeScalars {
            if CharacterSet.lowercaseLetters.contains(scalar) { hasLower = true }
            else if CharacterSet.uppercaseLetters.contains(scalar) { hasUpper = true }
            else if CharacterSet.decimalDigits.contains(scalar) { hasDigit = true }
            else if PasswordUtils.specialChars.contains(scalar) { hasSpecial = true }
        }
        
        return hasLower && hasUpper && hasDigit && hasSpecial
    }
    
    // MARK: - Interactive helpers
    
    public static func getSecurePassword(
        prompt: TerminalText,
        cleanup: [FilePath]? = nil,
        allowEmpty: Bool = false,
        validateStrength: Bool = true
    ) async throws -> String {
        let noora = try await Terminal.shared.noora()
        
        func abort() throws {
            if let files = cleanup {
                for file in files {
                    try? FileUtils.cleanupFile(file)
                }
            }
            noora.error(
                .alert(
                    "Aborted - no password provided.",
                    takeaways: [
                        "Try again and provide a password.",
                        "Make sure your terminal supports secure input."
                    ]
                )
            )
            throw ExitCode.validationFailure
        }
        
        while true {
            if let pw = try await readSecureLine(prompt: prompt) {
                if pw.isEmpty && !allowEmpty {
                    try abort()
                }
                if validateStrength && !PasswordUtils(pw).isValid {
                    noora.warning(
                        .alert(
                            "This is not a strong password, lets try it again...",
                            takeaway: "Please make sure your password is at least 10 characters long and includes a mix of uppercase letters, lowercase letters, numbers, and special characters."
                        ),
                    )
                    continue
                }
                return pw
            } else {
                try abort()
            }
        }
    }
    
    public static func getConfirmedPassword(prompt: TerminalText, cleanup: [FilePath]? = nil) async throws-> String {
        let noora = try await Terminal.shared.noora()
        print(
            noora.format("Please provide a strong password \(.primary("(min. 10 chars, uppercase, lowercase, special chars)")) for the encryption ...\n"),
            terminator: "\n\n"
        )
        
        var pass1 = ""
        var pass2 = ""
        
        repeat {
            repeat {
                pass1 = try await getSecurePassword(
                    prompt: prompt,
                    cleanup: cleanup
                )
                let confirmPrompt: TerminalText = "[Confirm the strong Password (empty to abort)] "
                pass2 = try await getSecurePassword(
                    prompt: confirmPrompt,
                    cleanup: cleanup
                )
                if pass1 != pass2 {
                    noora.warning(
                        .alert(
                            "The second password does not match the first one, lets start over again...",
                            takeaway: "Please be careful when entering the password."
                        ),
                    )
                }
            } while pass1 != pass2
            
            let utils = PasswordUtils(pass1)
            if !utils.isValid {
                noora.warning(
                    .alert(
                        "This is not a strong password, lets try it again...",
                        takeaway: "Please make sure your password is strong enough."
                    ),
                )
                pass1 = ""
                pass2 = ""
            } else {
                break
            }
        } while true
        
        noora.success(
            .alert("Passwords match.")
        )
        
        let response = noora.yesOrNoChoicePrompt(
            title: "Confirm Password",
            question: "Do you want to show the password for 5 seconds on screen to check it?",
            defaultAnswer: false,
            description: "Choose 'Yes' to display the password briefly, or 'No' to keep it hidden."
        )
        if response {
            _ = try await Noora().progressStep(
                message: "Chosen password is '\(pass1)' ",
                successMessage: "Visual confirmation done.",
                errorMessage: "Failed to show the password.",
                showSpinner: true
            ) { updateMessage in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return
            }
        }
        
        return pass1
    }
    
    // MARK: - Utilities
    
    private static func readSecureLine(prompt: TerminalText) async throws -> String? {
        let noora = try await Terminal.shared.noora()
        let response = noora.secureTextPrompt(
            title: "Secure Input",
            prompt: prompt,
            description: "Input is hidden for security.",
        )
        return response
    }
    
    private static func compareDigest(_ a: String, _ b: String) -> Bool {
        return constantTimeEquals(a, b)
    }
    
    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let da = Array(a.utf8)
        let db = Array(b.utf8)
        if da.count != db.count { return false }
        var result: UInt8 = 0
        for i in 0..<da.count {
            result |= da[i] ^ db[i]
        }
        return result == 0
    }
}

