import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GovernanceMainCommand {
    struct SubmitAction: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "submit-action",
            abstract: "Submit one or more previously generated .action files as a transaction.",
            usage: """
            scm governance submit-action \\
                --action-file mywallet_info_20260604.action \\
                --fee-payment-address mywallet.payment --submit

            scm governance submit-action \\
                --action-file proposal-a.action --action-file proposal-b.action \\
                --fee-payment-address owner.payment --submit
            """,
            discussion: """
            Mirrors `25b_regAction.sh`: takes a .action file (or several) and
            builds + signs + submits a single transaction that registers the
            proposals on-chain. Deposit + return address are read directly from
            each action file — no additional flags needed.
            """
        )

        @Option(name: .long, parsing: .upToNextOption, help: "Path to a .action file. Repeatable.")
        var actionFile: [FilePath] = []

        @Option(name: .long, help: "Extra slots added to chain tip when computing TTL (default: 500).")
        var ttlExtra: UInt64 = 500

        @Option(name: .long, help: "Override TTL with an absolute slot.")
        var ttlOverride: UInt64?

        @OptionGroup var transactionOptions: SharedTransactionOptions

        @Option(name: [.short, .long], help: "Output file for the signed transaction.")
        var outFile: FilePath?

        mutating func validate() throws {
            try self.validateForTransaction()
        }

        mutating func wizard() async throws {
            if actionFile.isEmpty {
                actionFile = [try filePathPrompt(
                    title: "Action File",
                    question: "Select the .action file to submit:",
                    fileMatches: { $0.lowercased().hasSuffix(".action") || $0.lowercased().hasSuffix(".json") }
                )]
            }

            if transactionOptions.feePaymentAddress == nil {
                transactionOptions.feePaymentAddress = try await getFeePaymentAddress(
                    title: "Fee Payment Address"
                )
            }

            try await self.wizardForTransaction()
            try self.validate()
        }

        mutating func run() async throws {
            if actionFile.isEmpty || transactionOptions.feePaymentAddress == nil, isInteractiveSession() {
                try await wizard()
            }

            var localOutFile = outFile
            try await runSubmitActionFiles(
                actionFiles: actionFile,
                ttlExtra: ttlExtra,
                ttlOverride: ttlOverride,
                outFile: &localOutFile
            )
            outFile = localOutFile
        }
    }
}
