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
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let skeyFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".skey") }
                .map { String($0.dropLast(".skey".count)) }
            
            if skeyFiles.isEmpty {
                noora.error(.alert(
                    "No signing key files found in current directory."
                ))
                throw ExitCode.failure
            }
            
            fileName = FilePath(noora.singleChoicePrompt(
                title: "Signing Key Files",
                question: "Select the .skey file to encrypt.",
                options: skeyFiles,
                description: "Available .skey files in current directory"
            ))
        }
        
        mutating func run() async throws {
            if fileName == nil {
                try await self.wizard()
            }
            
            guard let fileName = fileName else {
                noora.error(.alert("File name is required."))
                throw ExitCode.failure
            }
            
            print(noora.format(
                "SKEY-File that will be decrypted: \(.path(try .init(validating: fileName.string)))\n"
            ))
            
            var skey = try await TextEnvelope.load(from: fileName)
            
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
            
            let password = try await PasswordUtils.getSecurePassword(
                prompt: "\(.secondary("Please provide a strong password (min. 10 chars, uppercase, lowercase, specialchars) for the decryption ... (empty to abort)"))"
            )
            
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
            
            spacedPrint("Writing the file \(.path(try .init(validating: fileName.string))) to disc ... ")
            
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
            
            noora.success(.alert("Decrypted SKEY-File saved successfully to disc at \(.path(try .init(validating: fileName.string)))."))
            try noora.json(savedSKey)
        }
    }
}
