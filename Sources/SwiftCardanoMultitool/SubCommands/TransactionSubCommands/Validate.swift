import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoTxValidator

extension TransactionMainCommand {
    struct Validate: TransactionAsyncParsableCommand {
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
            
            let tx = try resolveTransaction()

            // Load chain context and config
            let config = try await MultitoolConfig.load(quiet: json)
            let context = try await getContext(config: config)
            
            if !json {
                try await printContextInfo(config: config, context: context)
            }
            
            let txValidator = TxValidator()

            // Fetch protocol parameters from the chain
            let protocolParams = try await getProtocolParameters(context: context, quiet: json)

            let validationCtx = try await ValidationContext.from(
                transaction: tx,
                chainContext: context
            )

            // Run validation
            if !json {
                spacedPrint("\(.primary("━━━ Running Validation ━━━"))")
                
                let report = try await noora.progressStep(
                    message: "Validating transaction...",
                    successMessage: "Validation complete.",
                    errorMessage: "Validation failed unexpectedly.",
                    showSpinner: true
                ) { _ in
                    try await txValidator.validate(
                        transaction: tx,
                        protocolParams: protocolParams,
                        context: validationCtx,
                        chainContext: context
                    )
                }
                
                displayReport(report)
            } else {
                let report = try await txValidator.validate(
                    transaction: tx,
                    protocolParams: protocolParams,
                    context: validationCtx,
                    chainContext: context
                )
                spacedPrint("\(try report.toJSON())")
            }
        }

        // MARK: - Private Helpers

        private func displayReport(_ report: TxValidatorReport) {
            let view = report.transactionView

            spacedPrint("\(.primary("━━━ Transaction Validation Report ━━━"))")

            // TX overview
            let hasScriptsText: TerminalText = view.hasPlutusScripts ? "\(.success("Yes"))" : "\(.danger("No"))"
            
            noora.info(.alert(
                "TX ID: \(.primary(view.txId))",
                takeaways: [
                    "Fee: \(.primary("\(view.fee) lovelace"))",
                    "Inputs: \(.primary("\(view.inputs.count)"))",
                    "Outputs: \(.primary("\(view.outputs.count)"))",
                    "Collateral Inputs: \(.primary("\(view.collateralInputs.count)"))",
                    "Reference Inputs: \(.primary("\(view.referenceInputs.count)"))",
                    "Has Plutus Scripts: \(hasScriptsText)",
                ]
            ))
            
            print()
            printDivider()
            

            // Overall verdict
            spacedPrint("\(.primary("─── Verdict ───"))")

            let hasErrors = !report.allErrors.isEmpty
            let hasWarnings = !report.allWarnings.isEmpty

            if hasErrors {
                noora.error(.alert("✗ Transaction is INVALID"))
            } else if hasWarnings {
                noora.warning(.alert("✓ Transaction is VALID", takeaway: "Transaction passed validation but may have issues. Review warnings below."))
            } else {
                noora.success("✓ Transaction is VALID")
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

            if !errors.isEmpty {
                noora.error(.alert("✗ \(phaseName) failed with \(errors.count) error(s)"))
            } else if !warnings.isEmpty {
                noora.warning(.alert("✓ \(phaseName) passed", takeaway: "\(phaseName) passed but has \(warnings.count) warning(s). Review below."))
            } else {
                noora.success("✓ \(phaseName) passed")
            }
            
            print()
            
            if !errors.isEmpty {
                for error in errors {
                    
                    var errorsText: [TerminalText] = []
                    errorsText.append("\(.danger("[\(error.kind.description)]"))")
                    errorsText.append("▸ \(error.message)")
                    errorsText.append(" ↳ Field: \(.muted(error.fieldPath))")
                    
                    if let hint = error.hint {
                        errorsText.append(" ↳ Hint: \(.info(hint))\n")
                    }
                    
                    for line in errorsText {
                        formatPrint(line)
                    }
                    print()
                    
                }
                printDivider()
            }

            if !warnings.isEmpty {
                
                noora.warning(.alert(
                    "\(phaseName) has \(warnings.count) warning(s)",
                ))
                print()
                
                for warning in warnings {
                    var warningsText: [TerminalText] = []
                    warningsText.append("\(.accent("[\(warning.kind.description)]"))")
                    warningsText.append("▸ \(warning.message)")
                    warningsText.append(" ↳ Field: \(.muted(warning.fieldPath))")

                    if let hint = warning.hint {
                        warningsText.append(" ↳ Hint: \(.info(hint))\n")
                    }
                    
                    for line in warningsText {
                        formatPrint(line)
                    }
                    print()
                }
                printDivider()
            }

            if errors.isEmpty && warnings.isEmpty {
                spacedPrint("\(.muted("No issues found."))")
                printDivider()
            }
        }

    }
}
