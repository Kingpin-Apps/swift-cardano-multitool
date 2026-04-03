import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoTxValidator

extension TransactionMainCommand {
    struct Validate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "validate",
            abstract: "Validate a transaction against ledger rules.",
            usage: """
            scm transaction validate --tx-file test.tx
            scm transaction validate --cbor-hex 84a500...
            """,
            discussion: """
            Parse a Cardano transaction and run Phase-1 ledger rule checks (fee, balance,
            collateral, script integrity, validity interval, witnesses, and more).
            Phase-2 Plutus script execution is also run when a chain context is available.
            Protocol parameters and the current slot are fetched from the configured chain context.
            Use --json to output the full validation report as formatted JSON.
            """
        )

        // MARK: - Arguments

        @Option(name: [.short, .long], help: "Path to the transaction file (Cardano text envelope or raw CBOR hex).")
        var txFile: FilePath?

        @Option(name: .long, help: "Raw CBOR hex string of the transaction.")
        var cborHex: String?

        @Flag(name: .long, help: "Output as JSON instead of formatted text.")
        var json: Bool = false

        // MARK: - Validation

        mutating func validate() throws {
            if txFile != nil && cborHex != nil {
                throw ValidationError("Provide either --tx-file or --cbor-hex, not both.")
            }
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            let enterTransactionBy = try await getTransactionBy()
            
            switch enterTransactionBy {
                case .cborHex:
                    cborHex = noora.textPrompt(
                        title: "Transaction CBOR Hex",
                        prompt: "Enter the raw CBOR hex string of the transaction:",
                        validationRules: [NonEmptyValidationRule(error: "CBOR hex cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                case .path:
                    txFile = try await getTransactionFilePath(title: "Select a transaction file to validate.")
            }
        }

        // MARK: - Run

        mutating func run() async throws {
            if txFile == nil && cborHex == nil {
                try await wizard()
            }

            let hex = try resolveCborHex()

            // Load chain context and config
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            // Fetch protocol parameters from the chain
            let protocolParams = try await getProtocolParameters(context: context)

            // Build a ValidationContext with current slot and network
            let cardanoConfig = try getCardanoConfig(config: config)
            let currentSlot = try await noora.progressStep(
                message: "Querying current slot...",
                successMessage: "Current slot retrieved.",
                errorMessage: "Failed to retrieve current slot.",
                showSpinner: true
            ) { _ in
                try await context.lastBlockSlot()
            }

            let validationCtx = ValidationContext(
                currentSlot: UInt64(currentSlot),
                network: cardanoConfig.network.networkId
            )

            noora.warning(.alert(
                "Partial validation only.",
                takeaway: "UTxO inputs are not resolved from the chain, so the balance conservation check (inputs = outputs + fee) is skipped."
            ))

            // Run validation
            print(noora.format("\n\(.primary("━━━ Running Validation ━━━"))\n"))

            let report = try await noora.progressStep(
                message: "Validating transaction...",
                successMessage: "Validation complete.",
                errorMessage: "Validation failed unexpectedly.",
                showSpinner: true
            ) { _ in
                try await TxValidator().validate(
                    cborHex: hex,
                    protocolParams: protocolParams,
                    context: validationCtx,
                    chainContext: context
                )
            }

            if json {
                print(try report.toJSON())
                return
            }

            displayReport(report)
        }

        // MARK: - Private Helpers

        private func resolveCborHex() throws -> String {
            if let hex = cborHex {
                return hex
            }
            if let file = txFile {
                let tx = try Transaction.load(from: file.string)
                return try tx.toCBORHex()
            }
            noora.error("Transaction input is required.")
            throw ExitCode.validationFailure
        }

        private func displayReport(_ report: TxValidatorReport) {
            let view = report.transactionView

            print(noora.format("\n\(.primary("━━━ Transaction Validation Report ━━━"))\n"))

            // TX overview
            let hasScriptsText: TerminalText = view.hasPlutusScripts ? "\(.success("Yes"))" : "\(.danger("No"))"
            
            noora.info(.alert(
                "TX ID: \(.primary(view.txId))",
                takeaways: [
                    "Fee: \(.primary("\(view.fee) lovelace"))",
                    "Inputs: \(.primary("\(view.inputs.count)"))",
                    "Outputs: \(.primary("\(view.outputs.count)"))",
                    "Has Plutus Scripts: \(hasScriptsText)",
                ]
            ))

            // Overall verdict
            print(noora.format("\n\(.primary("─── Verdict ───"))\n"))
            if report.isValid {
                noora.success("✓ Transaction is VALID")
            } else {
                noora.error(.alert("✗ Transaction is INVALID"))
            }

            // Phase-1 results
            print(noora.format("\n\(.primary("─── Phase-1: Ledger Rules ───"))\n"))
            displayPhaseResult(report.phase1Result, phaseName: "Phase-1")

            // Phase-2 results
            if let phase2Result = report.phase2Result {
                print(noora.format("\n\(.primary("─── Phase-2: Plutus Scripts ───"))\n"))
                displayPhaseResult(phase2Result, phaseName: "Phase-2")

                if let evalResults = report.redeemerEvalResults, !evalResults.isEmpty {
                    print(noora.format("\n\(.primary("─── Redeemer Evaluation ───"))\n"))
                    let headers: [TableCellStyle] = [
                        .primary("Index"), .primary("CPU Steps"), .primary("Mem Units"), .primary("Status")
                    ]
                    let rows: [StyledTableRow] = evalResults.map { r in
                        let status: TableCellStyle = r.passed ? .success("✓ Pass") : .danger("✗ Fail")
                        return [
                            .plain("\(r.index)"),
                            .muted("\(r.remainingBudget.steps)"),
                            .muted("\(r.remainingBudget.memory)"),
                            status
                        ]
                    }
                    noora.table(headers: headers, rows: rows)
                }
            } else if view.hasPlutusScripts {
                noora.warning(.alert(
                    "Phase-2 was not run.",
                    takeaway: "Plutus scripts detected but no chain context was available for script execution."
                ))
            }

            print()
        }

        private func displayPhaseResult(_ result: ValidationResult, phaseName: String) {
            let errors = result.errors
            let warnings = result.warnings

            if result.isValid {
                noora.success("✓ \(phaseName) passed")
            } else {
                noora.error(.alert("✗ \(phaseName) failed with \(errors.count) error(s)"))
            }

            if !errors.isEmpty {
                for error in errors {
                    var takeaways: [TerminalText] = ["Field: \(.muted(error.fieldPath))"]
                    if let hint = error.hint {
                        takeaways.append("Hint: \(.info(hint))")
                    }
                    noora.error(.alert(
                        "\(.danger("[\(error.kind)]")) \(error.message)",
                        takeaways: takeaways
                    ))
                }
            }

            if !warnings.isEmpty {
                for warning in warnings {
                    var takeaway: TerminalText = "Field: \(.muted(warning.fieldPath))"
                    
                    if let hint = warning.hint {
                        takeaway = "\(takeaway) \n • Hint: \(.info(hint))"
                    }
                    
                    noora.warning(.alert(
                        "\(.accent("[\(warning.kind)]")) \(warning.message)",
                        takeaway: takeaway
                    ))
                }
            }

            if errors.isEmpty && warnings.isEmpty {
                spacedPrint("\(.muted("No issues found."))")
            }
        }
    }
}
