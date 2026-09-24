import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils


extension GenerateMainCommand {
    struct KeyRotation: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Rotate KES Keys and Node Operational Certificate."
        )

        @Option(name: .shortAndLong, help: "The base name of the pool. Key files are looked up as <poolName>.kes-XXX.skey etc.")
        var poolName: String? = nil

        @Option(name: .shortAndLong, help: "Number of pools to rotate (multi-pool setup). Pools are named <poolName>1, <poolName>2, ...")
        var numberOfPools: Int? = nil

        @Option(name: .shortAndLong, help: "The method to use for KES key generation. Options are: cli or enc")
        var keyGenMethod: KeyGenMethod? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to generate the keys.")
        var tool: Tool? = nil

        mutating func validate() throws {
            switch keyGenMethod {
                case .hw, .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc, .hwMulti:
                    throw ValidationError("Unsupported key generation method. Please choose from: cli or enc.")
                default:
                    break
            }
        }

        mutating func wizard() async throws {
            poolName = noora.textPrompt(
                title: "Pool Name",
                prompt: "Enter the base name of the pool:",
                description: "Key files are looked up by this prefix; a bare name resolves in the current working directory.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            let isMultiPool = noora.yesOrNoChoicePrompt(
                title: "Multiple Pools",
                question: "Are you rotating keys for multiple pools?",
                defaultAnswer: false
            )

            if isMultiPool {
                numberOfPools = Int(noora.textPrompt(
                    title: "Number of Pools",
                    prompt: "Enter the number of pools to rotate:",
                    collapseOnAnswer: true,
                    validationRules: [
                        NonEmptyValidationRule(error: "Number cannot be empty."),
                        IntegerValidationRule(error: "Must be a positive integer.")
                    ]
                ))
            }

            keyGenMethod = noora.singleChoicePrompt(
                title: "Key Generation Method",
                question: "Select the key generation method for KES key generation.",
                options: KeyGenMethod.allCases.filter { [.cli, .enc].contains($0) },
                description: "Choose from:\n- cli: Use cardano-cli or SwiftCardano.\n- enc: Generate then encrypt the signing key with a password."
            )

            if tool == nil { tool = try await getToolToUse() }

            try self.validate()
        }

        mutating func run() async throws {
            if poolName == nil && keyGenMethod == nil {
                try await self.wizard()
            }

            if tool == nil {
                tool = try await getToolToUse()
            }

            if keyGenMethod == nil {
                keyGenMethod = noora.singleChoicePrompt(
                    title: "Key Generation Method",
                    question: "Select the key generation method for KES key generation.",
                    options: KeyGenMethod.allCases.filter { [.cli, .enc].contains($0) },
                    description: "Choose from:\n- cli: Use cardano-cli or SwiftCardano.\n- enc: Generate then encrypt the signing key with a password."
                )
            }

            let baseName = poolName!
            let uploadDir = Self.uploadDirectory(for: baseName)

            if !FileManager.default.fileExists(atPath: uploadDir.string) {
                try FileManager.default.createDirectory(
                    atPath: uploadDir.string,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            if let count = numberOfPools {
                for i in 1...count {
                    try await rotatePool(
                        poolName: "\(baseName)\(i)",
                        uploadDir: uploadDir
                    )
                }
            } else {
                try await rotatePool(poolName: baseName, uploadDir: uploadDir)
            }
        }

        /// `upload_<pool>` next to the pool's key files, where rotated files are collected.
        /// A pool name may carry a directory (e.g. /keys/mypool → /keys/upload_mypool).
        static func uploadDirectory(for baseName: String) -> FilePath {
            let base = FileUtils.absolutePath(baseName)
            let stem = base.lastComponent?.string ?? baseName
            return base.removingLastComponent().appending("upload_\(stem)")
        }

        mutating func rotatePool(poolName name: String, uploadDir: FilePath) async throws {
            spacedPrint("Generating \(name) KES keys...")

            // Build via `parse([])` rather than the bare `init()`: ArgumentParser only
            // applies the `= nil` property defaults during parsing, so a memberwise-init
            // instance leaves any field we don't explicitly set in an `.unset` state that
            // traps ("Can't read a value from a parsable argument definition") the moment
            // run() reads it — e.g. opcert's `useOpCertCounter`, which we never set.
            var kesKeys = try GenerateMainCommand.NodeKESKeys.parse([])
            kesKeys.poolName = name
            kesKeys.keyGenMethod = keyGenMethod
            kesKeys.tool = tool
            try await kesKeys.run()

            spacedPrint("Generating \(name) OPCERT...")

            var opcertCmd = try GenerateMainCommand.NodeOperationalCertificate.parse([])
            opcertCmd.poolName = name
            opcertCmd.tool = tool
            try await opcertCmd.run()

            // Read the latest KES number from kes.counter
            let kesCounterFile = FileUtils.absolutePath("\(name).kes.counter")
            let counterValue = try FileUtils.loadFile(FilePath(kesCounterFile.string))

            guard let counterInt = Int(counterValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                noora.error(.alert(
                    "Invalid counter value in \(kesCounterFile.string).",
                    takeaways: ["Check the file manually or regenerate the keys."]
                ))
                throw ExitCode.validationFailure
            }

            let latestKESNumber = String(format: "%03d", counterInt)

            let kesSKeySource = FileUtils.absolutePath("\(name).kes-\(latestKESNumber).skey")
            let opcertSource = FileUtils.absolutePath("\(name).node-\(latestKESNumber).opcert")

            let stem = FilePath(name).lastComponent?.string ?? name
            let kesSKeyDest = uploadDir.appending("\(stem).kes.skey")
            let opcertDest = uploadDir.appending("\(stem).node.opcert")

            // Unlock destination files if they already exist (locked from a prior rotation)
            if FileManager.default.fileExists(atPath: kesSKeyDest.string) {
                try await FileUtils.fileUnlock(kesSKeyDest)
                try FileManager.default.removeItem(atPath: kesSKeyDest.string)
            }
            if FileManager.default.fileExists(atPath: opcertDest.string) {
                try await FileUtils.fileUnlock(opcertDest)
                try FileManager.default.removeItem(atPath: opcertDest.string)
            }

            // Move generated files into the upload directory
            try FileManager.default.moveItem(atPath: kesSKeySource.string, toPath: kesSKeyDest.string)
            try FileManager.default.moveItem(atPath: opcertSource.string, toPath: opcertDest.string)

            spacedPrint(
                "New \(.primary(kesSKeyDest.string)) and \(.primary(opcertDest.string)) files ready for upload to the server."
            )
        }
    }
}
