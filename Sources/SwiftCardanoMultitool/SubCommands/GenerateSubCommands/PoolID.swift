import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GenerateMainCommand {
    struct PoolID: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "pool-id",
            abstract: "Generate the <name>.pool.id and <name>.pool.id-bech files for a pool.",
            usage: """
            scm generate pool-id --pool-name mypool --pool-operator pool1...
            scm generate pool-id --pool-name mypool --pool-operator mypool.node.vkey
            """,
            discussion: """
            Writes the pool ID in hex to <name>.pool.id and in bech32 to
            <name>.pool.id-bech. The pool operator accepts a pool ID (pool1… or
            hex), a cold verification key (pool_vk1… or hex), or a pool ID,
            pool.json or cold key file.
            """,
            aliases: ["poolid"]
        )

        @Option(name: .shortAndLong, help: "The name of the pool. The files will be saved as <name>.pool.id and <name>.pool.id-bech.", completion: .fileStems)
        var poolName: String? = nil

        @Option(name: .long, help: "The pool operator. Supports: pool ID (pool1... or hex), cold verification key (pool_vk1... or hex), .pool.id file, pool.json, or cold key file.")
        var poolOperator: PoolOperator? = nil

        @Flag(name: .long, help: "Overwrite existing pool ID files.")
        var overwrite: Bool = false

        // MARK: - Wizard

        mutating func wizard() async throws {
            if poolName == nil {
                poolName = noora.textPrompt(
                    title: "Pool Name",
                    prompt: "Enter the name of the pool:",
                    description: "The files will be saved as <name>.pool.id and <name>.pool.id-bech.",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if poolOperator == nil {
                let input = noora.textPrompt(
                    title: "Pool Operator",
                    prompt: "Enter the pool ID, cold verification key or file:",
                    description: "Accepts pool1…, 56-character hex, pool_vk1…, 64-character hex, or a .pool.id, .pool.json, .cold.vkey or .node.vkey file.",
                    collapseOnAnswer: true,
                    validationRules: [
                        NonEmptyValidationRule(error: "Pool operator cannot be empty."),
                        PoolOperatorValidationRule(error: "Not a valid pool ID, cold verification key or pool file.")
                    ]
                )
                poolOperator = PoolOperator(argument: input)
            }
        }

        // MARK: - Run

        mutating func run() async throws {
            if poolName == nil || poolOperator == nil, isInteractiveSession() {
                try await wizard()
            }

            guard let poolName, !poolName.isEmpty else {
                noora.error(.alert("Pool name is required.", takeaways: ["Provide --pool-name <name>."]))
                throw ExitCode.validationFailure
            }
            guard let poolOperator else {
                noora.error(.alert("Pool operator is required.", takeaways: ["Provide --pool-operator <pool ID, cold key or file>."]))
                throw ExitCode.validationFailure
            }

            let idHexFile = FileUtils.absolutePath("\(poolName).pool.id")
            let idBechFile = FileUtils.absolutePath("\(poolName).pool.id-bech")

            if !overwrite {
                try await FileUtils.checkFile(idHexFile)
                try await FileUtils.checkFile(idBechFile)
            }

            try await FileUtils.unlockIfExists(idHexFile)
            try await FileUtils.unlockIfExists(idBechFile)
            try poolOperator.save(to: idHexFile.string, format: .hex, overwrite: true)
            try poolOperator.save(to: idBechFile.string, format: .bech32, overwrite: true)
            try await FileUtils.fileLock(idHexFile)
            try await FileUtils.fileLock(idBechFile)

            noora.success(.alert(
                "Pool ID files created.",
                takeaways: [
                    "Hex: \(pathComponent(idHexFile.string)) → \(try poolOperator.id(.hex))",
                    "Bech32: \(pathComponent(idBechFile.string)) → \(try poolOperator.id(.bech32))"
                ]
            ))
        }
    }
}
