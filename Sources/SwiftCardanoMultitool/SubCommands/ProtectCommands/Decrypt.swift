import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

extension ProtectMainCommand {
    
    struct Decrypt: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Decrypt your SKEY-Files with a password."
        )
        
        @Option(name: .shortAndLong, help: "The name of the file to decrypt.")
        var fileName: FilePath? = nil
        
        mutating func validate() throws {}
        
        mutating func wizard() async throws {
            fileName = try filePathPrompt(
                title: "Signing Key Files",
                question: "Select the .skey file to decrypt.",
                fileMatches: { $0.hasSuffix(".skey") || $0.hasSuffix(".json") }
            )
        }
        
        mutating func run() async throws {
            // Decryption needs an interactive password prompt (no flag for it),
            // so fail clearly instead of aborting inside a prompt when there is
            // no interactive terminal.
            guard isInteractiveSession() else {
                noora.error(.alert(
                    "'protect decrypt' requires an interactive terminal.",
                    takeaways: [
                        "It asks you to confirm the file and whether to write the result, which have no command-line flags.",
                        "Set \(Environment.decryptPassword.rawValue) to supply the password without a prompt; the confirmations still need a terminal.",
                        "Run it in an interactive shell (not piped/CI), and make sure CARDANO_MULTITOOL_SKIP_PROMPT is not set."
                    ]
                ))
                throw ExitCode.validationFailure
            }

            if fileName == nil {
                try await self.wizard()
            }

            guard let fileName = fileName else {
                noora.error(.alert("File name is required."))
                throw ExitCode.failure
            }
            
            print(noora.format(
                "SKEY-File that will be decrypted: \(.primary(fileName.string))\n"
            ))
            
            // Read the file as stored: TextEnvelope.load(from:) would transparently
            // decrypt it, and the guard below needs the on-disc state.
            var skey = try TextEnvelope.loadRaw(from: fileName)
            
            if !skey.isEncrypted {
                noora.error(.alert("The provided SKEY-File is already decrypted."))
                throw ExitCode.validationFailure
            }
            
            let confirm = noora.yesOrNoChoicePrompt(
                title: "Confirmation",
                question: "Is this correct, continue?",
                defaultAnswer: false,
                description: "Please confirm to proceed with decryption."
            )
            
            if !confirm {
                noora.info("Aborting as per user request.")
                throw ExitCode.success
            }
            
            let (password, fromEnvironment) = try await PasswordUtils.getDecryptionPassword(
                prompt: "\(.secondary("Please provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the decryption ... (empty to abort)"))"
            )
            if fromEnvironment {
                noora.info("Using the password from \(Environment.decryptPassword.rawValue).")
            }
            
            _ = try await noora.progressStep(
                message: "Decrypting the cborHex...",
                successMessage: "Key decrypted successfully.",
                errorMessage: "Failed to decrypt key.",
                showSpinner: true
            ) { updateMessage in
                try await skey.decrypt(with: password)
                return
            }
            
            print(noora.format(
                "Decrypted SKEY-File will look like:\n"
            ))
            try noora.json(skey)
            
            let saveFile = noora.yesOrNoChoicePrompt(
                title: "Save File",
                question: "Write decrypted SKEY-File to disc?",
                defaultAnswer: false,
                description: "Please confirm to save the decrypted file."
            )
            
            if saveFile == false {
                noora.info("Aborting, not saving the decrypted file.")
                throw ExitCode.success
            }
            
            spacedPrint("Writing the file \(.primary(fileName.string)) to disc ... ")
            
            let data = try JSONEncoder().encode(skey)
            
            let savedSKey: String
            do {
                try await FileUtils.dumpLockedFile(fileName, data: data.toString)
                savedSKey = try await FileUtils.loadLockedFile(fileName)
            } catch {
                noora.error(.alert(
                    "Failed to save the decrypted SKEY-File to disc: \(error.localizedDescription)",
                    takeaways: [
                        "Please ensure that you have the necessary permissions to write to the specified location.",
                        "Target file maybe corrupted or overwritten by another process.",
                        "Verify that the file path is correct and accessible.",
                        "Please use your original SKEY content to recover it: \n\(data.toString)"
                    ]
                ))
                throw ExitCode.failure
            }
            
            noora.success(.alert("Decrypted SKEY-File saved successfully to disc at \(.primary(fileName.string))."))
            try noora.json(savedSKey)
        }
    }
}
