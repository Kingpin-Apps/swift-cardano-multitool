import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoTxValidator

extension TransactionMainCommand {
    struct Inspect: TransactionAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "inspect",
            abstract: "Inspect transaction fields.",
            usage: """
            scm transaction inspect --tx-file test.tx
            scm transaction inspect --cbor-hex 84a500...
            """,
            discussion: """
            Parse a Cardano transaction and display its fields in a human-readable format.
            Accepts either a Cardano text envelope file (.tx) or a raw CBOR hex string.
            Use --json to output the full TransactionView as formatted JSON.
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
                    txFile = try await getTransactionFilePath(title: "Select a transaction file to inspect.")
            }
        }

        // MARK: - Run

        mutating func run() async throws {
            if txFile == nil && cborHex == nil {
                try await wizard()
            }

            let hex = try resolveCborHex()
            let validator = TxValidator()

            let view: TransactionView
            do {
                view = try validator.inspect(cborHex: hex)
            } catch {
                noora.error(.alert(
                    "Failed to parse transaction.",
                    takeaways: ["\(error.localizedDescription)"]
                ))
                throw ExitCode.failure
            }

            if json {
                spacedPrint("\(try JSONExport.encode(view))")
            } else {
                try await displayTransactionView(view)
            }
        }

        // MARK: - Private Helpers

        private func displayTransactionView(_ view: TransactionView) async throws {
            print(noora.format("\n\(.primary("━━━ Transaction Inspect ━━━"))\n"))

            // Pre-compute ternary TerminalText values so the compiler can infer the type
            let validStatus: TerminalText = view.isValid ? "\(.success("✓ Yes"))" : "\(.danger("✗ No"))"
            let plutusStatus: TerminalText = view.hasPlutusScripts ? "\(.accent("Yes"))" : "\(.muted("No"))"
            let networkStatus: TerminalText
            if let netId = view.networkId {
                networkStatus = netId == 1 ? "\(.success("Mainnet (1)"))" : "\(.danger("Testnet (0)"))"
            } else {
                networkStatus = "\(.muted("Not specified"))"
            }
            
            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            
            let explorer = config.blockchainExplorer.explorer(
                network: cardanoConfig.network
            )

            // Overview
            noora.info(.alert(
                "TX ID: \(.primary(view.txId))",
                takeaways: [
                    "Valid: \(validStatus)",
                    "Fee: \(.primary("\(view.fee) lovelace"))",
                    "Network ID: \(networkStatus)",
                    "Witness Count: \(.primary("\(view.witnessCount)"))",
                    "Has Plutus Scripts: \(plutusStatus)",
                    "Redeemer Count: \(.primary("\(view.redeemerCount)"))",
                ]
            ))

            // Validity interval
            if view.validityStart != nil || view.ttl != nil {
                let startStr: TerminalText = view.validityStart.map { "from slot \(.primary("\($0)"))" } ?? ""
                let ttlStr: TerminalText = view.ttl.map { "to slot \(.primary("\($0)"))" } ?? ""
                spacedPrint("Validity: \(startStr) \(ttlStr)")
            }

            // Script data hash
            if let sdh = view.scriptDataHash {
                spacedPrint("Script Data Hash: \(.muted(sdh))")
            }

            // Auxiliary data hash
            if let adh = view.auxiliaryDataHash {
                spacedPrint("Auxiliary Data Hash: \(.muted(adh))")
            }
            
            let utxoColumns = [
                TableColumn(title: "Index", width: .auto, alignment: .right),
                TableColumn(title: "Hash", width: .auto, alignment: .left),
                TableColumn(title: "URL", width: .auto, alignment: .left)
            ]

            // Inputs
            print(noora.format("\n\(.primary("─── Inputs (\(view.inputs.count)) ───"))\n"))
            if view.inputs.isEmpty {
                spacedPrint("\(.muted("No inputs."))")
            } else {
                var inputRows: [[TerminalText]] = []
                
                for (i, ref) in view.inputs.enumerated() {
                    let parts = ref.components(separatedBy: "#")
                    
                    guard parts.count == 2 else {
                        inputRows.append([
                            TerminalText("\(i + 1)"),
                            "\(.danger("Invalid input format"))"
                        ])
                        continue
                    }
                    
                    let txURL = try explorer.viewTransaction(
                        transactionId: TransactionId(payload: parts[0].hexStringToData)
                    )
                    inputRows.append([
                        "\(.muted("\(parts[1])"))",
                        "\(.primary("\(parts[0])"))",
                        "\(.muted("\(txURL.absoluteString)"))",
                    ])
                }
                
                let tableData = TableData(columns: utxoColumns, rows: inputRows)
                noora.table(tableData)
            }

            if !view.referenceInputs.isEmpty {
                print(noora.format("\n\(.primary("─── Reference Inputs (\(view.referenceInputs.count)) ───"))\n"))
                var refRows: [[TerminalText]] = []
                
                for (i, ref) in view.referenceInputs.enumerated() {
                    let parts = ref.components(separatedBy: "#")
                    
                    guard parts.count == 2 else {
                        refRows.append([
                            TerminalText("\(i + 1)"),
                            "\(.danger("Invalid input format"))"
                        ])
                        continue
                    }
                    
                    let txURL = try explorer.viewTransaction(
                        transactionId: TransactionId(payload: parts[0].hexStringToData)
                    )
                    refRows.append([
                        "\(.muted("\(parts[1])"))",
                        "\(.primary("\(parts[0])"))",
                        "\(.muted("\(txURL.absoluteString)"))",
                    ])
                }
                
                let tableData = TableData(columns: utxoColumns, rows: refRows)
                noora.table(tableData)
            }

            if !view.collateralInputs.isEmpty {
                print(noora.format("\n\(.primary("─── Collateral Inputs (\(view.collateralInputs.count)) ───"))\n"))
                var colRows: [[TerminalText]] = []
                
                for (i, ref) in view.collateralInputs.enumerated() {
                    let parts = ref.components(separatedBy: "#")
                    
                    guard parts.count == 2 else {
                        colRows.append([
                            TerminalText("\(i + 1)"),
                            "\(.danger("Invalid input format"))"
                        ])
                        continue
                    }
                    
                    let txURL = try explorer.viewTransaction(
                        transactionId: TransactionId(payload: parts[0].hexStringToData)
                    )
                    colRows.append([
                        "\(.muted("\(parts[1])"))",
                        "\(.primary("\(parts[0])"))",
                        "\(.muted("\(txURL.absoluteString)"))",
                    ])
                }
                
                let tableData = TableData(columns: utxoColumns, rows: colRows)
                noora.table(tableData)
            }

            // Outputs
            print(noora.format("\n\(.primary("─── Outputs (\(view.outputs.count)) ───"))\n"))
            if view.outputs.isEmpty {
                spacedPrint("\(.muted("No outputs."))")
            } else {
                let outColumns = [
                    TableColumn(title: "Index", width: .auto, alignment: .right),
                    TableColumn(title: "Address", width: .auto, alignment: .left),
                    TableColumn(title: "Lovelace", width: .auto, alignment: .left),
                    TableColumn(title: "Flags", width: .auto, alignment: .left),
                ]
                
                var outRows: [[TerminalText]] = []
                for (i, out) in view.outputs.enumerated() {
                    var flags: [String] = []
                    if out.hasInlineDatum { flags.append("InlineDatum") }
                    if out.hasDatumHash { flags.append("DatumHash") }
                    if out.hasScriptRef { flags.append("ScriptRef") }
                    let flagStr = flags.isEmpty ? "-" : flags.joined(separator: ", ")
                    
//                    let addressURL = try explorer.viewAddress(
//                        address: Address.fromBech32(out.address)
//                    )
                    
                    outRows.append([
                        "\(.muted("\(i + 1)"))",
                        "\(.primary("\(out.address)"))",
                        "\(.success("\(out.lovelace)"))",
                        "\(.accent("\(flagStr)"))",
                    ])
                }
                
                let tableData = TableData(columns: outColumns, rows: outRows)
                noora.table(tableData)
            }

            if let cr = view.collateralReturn {
                print(noora.format("\n\(.primary("─── Collateral Return ───"))\n"))
                spacedPrint("Address: \(.primary(cr.address))")
                spacedPrint("Lovelace: \(.success("\(cr.lovelace)"))")
                if let tc = view.totalCollateral {
                    spacedPrint("Total Collateral: \(.primary("\(tc) lovelace"))")
                }
            }

            // Mint
            if let mint = view.mint, !mint.isEmpty {
                print(noora.format("\n\(.primary("─── Mint / Burn ───"))\n"))
                let mintHeaders: [TableCellStyle] = [.primary("Policy ID"), .primary("Asset Name"), .primary("Amount")]
                var mintRows: [StyledTableRow] = []
                for (policyId, assets) in mint {
                    for (assetName, qty) in assets {
                        let style: TableCellStyle = qty >= 0 ? .success("+\(qty)") : .danger("\(qty)")
                        mintRows.append([.muted(policyId), .primary(assetName.isEmpty ? "(lovelace)" : assetName), style])
                    }
                }
                noora.table(headers: mintHeaders, rows: mintRows)
            }

            // Required signers
            if !view.requiredSigners.isEmpty {
                print(noora.format("\n\(.primary("─── Required Signers (\(view.requiredSigners.count)) ───"))\n"))
                let sigHeaders: [TableCellStyle] = [.primary("#"), .primary("Key Hash")]
                let sigRows: [StyledTableRow] = view.requiredSigners.enumerated().map { i, kh in
                    [.plain("\(i + 1)"), .muted(kh)]
                }
                noora.table(headers: sigHeaders, rows: sigRows)
            }

            print()
        }
    }
}
