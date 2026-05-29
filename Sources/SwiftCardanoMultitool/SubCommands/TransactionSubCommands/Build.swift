import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Logging
import Path

/// Display wrapper for UTxOs shown in the input selection multi-select prompt.
private struct UTxOInputOption: CustomStringConvertible, Equatable {
    let input: String       // txHash#index
    let lovelace: UInt64
    let hasMultiAsset: Bool

    var description: String {
        let ada = lovelaceToAdaFormatString(lovelace)
        let suffix = hasMultiAsset ? " + multi-asset" : ""
        return "\(input)  \(ada)\(suffix)"
    }
}

extension TransactionMainCommand {
    struct Build: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "build",
            abstract: "Build a balanced transaction (automatically calculates fees).",
            usage: """
            scm transaction build \\
                --tx-in abc123...#0 \\
                --tx-out addr1...+2000000 \\
                --change-address addr1... \\
                --out-file tx.body
            """,
            discussion: """
            Builds a balanced transaction from explicit inputs and outputs. Fees are
            automatically calculated. Mirrors cardano-cli conway transaction build.

            For advanced Plutus script options (--spending-tx-in-reference,
            --tx-in-script-file, etc.), use --extra-args to pass them directly to
            cardano-cli, or use --use-cardano-cli.
            """
        )

        // MARK: - Required Arguments

        @Option(name: .long, parsing: .upToNextOption, help: "Transaction input (TxId#TxIx). Repeat for multiple inputs.")
        var txIn: [String] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Transaction output as ADDRESS VALUE. Repeat for multiple outputs.")
        var txOut: [String] = []

        @Option(name: .long, help: "Address where ADA in excess of the tx fee will go.")
        var changeAddress: String?

        @Option(name: [.short, .long], help: "Output filepath of the JSON TxBody.")
        var outFile: FilePath?

        // MARK: - Reference / Collateral Inputs

        @Option(name: .long, parsing: .upToNextOption, help: "Read-only reference input (TxId#TxIx). Repeat for multiple.")
        var readOnlyTxInReference: [String] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Collateral input (TxId#TxIx). Repeat for multiple.")
        var txInCollateral: [String] = []

        @Option(name: .long, help: "Collateral return output as ADDRESS VALUE.")
        var txOutReturnCollateral: String?

        @Option(name: .long, help: "Total collateral amount in lovelace.")
        var txTotalCollateral: Int?

        // MARK: - Required Signers

        @Option(name: .long, parsing: .upToNextOption, help: "Required signer key file path. Repeat for multiple.")
        var requiredSigner: [FilePath] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Required signer verification key hash. Repeat for multiple.")
        var requiredSignerHash: [String] = []

        // MARK: - Script Control

        @Flag(help: "Assertion that the script is valid (default).")
        var scriptValid = false

        @Flag(help: "Assertion that the script is invalid. If submitted, collateral will be taken.")
        var scriptInvalid = false

        @Option(name: .long, help: "Override the number of witnesses the transaction requires.")
        var witnessOverride: Int?

        // MARK: - Temporal

        @Option(name: .long, help: "Time that transaction is valid from (in slots).")
        var invalidBefore: Int?

        @Option(name: .long, help: "Time that transaction is valid until (in slots).")
        var invalidHereafter: Int?

        // MARK: - Minting

        @Option(name: .long, parsing: .upToNextOption, help: "Mint value in multi-asset syntax. Repeat for multiple. Each mint value should be followed by its script via --extra-args.")
        var mint: [String] = []

        // MARK: - Certificates

        @Option(name: .long, parsing: .upToNextOption, help: "Certificate file path. Repeat for multiple.")
        var certificateFile: [FilePath] = []

        // MARK: - Withdrawals

        @Option(name: .long, parsing: .upToNextOption, help: "Withdrawal as StakeAddress+Lovelace. Repeat for multiple.")
        var withdrawal: [String] = []

        // MARK: - Metadata

        @Flag(help: "Use detailed JSON schema conversion for metadata.")
        var jsonMetadataDetailedSchema = false

        @Option(name: .long, parsing: .upToNextOption, help: "Auxiliary script file path. Repeat for multiple.")
        var auxiliaryScriptFile: [FilePath] = []

        @Option(name: .long, parsing: .upToNextOption, help: "JSON metadata file path. Repeat for multiple.")
        var metadataJsonFile: [FilePath] = []

        @Option(name: .long, parsing: .upToNextOption, help: "CBOR metadata file path. Repeat for multiple.")
        var metadataCborFile: [FilePath] = []

        // MARK: - Governance

        @Option(name: .long, parsing: .upToNextOption, help: "Vote file path. Repeat for multiple.")
        var voteFile: [FilePath] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Proposal file path. Repeat for multiple.")
        var proposalFile: [FilePath] = []

        @Option(name: .long, help: "Treasury donation amount in lovelace.")
        var treasuryDonation: UInt64?

        // MARK: - Output Control

        @Flag(help: "Produce transaction in canonical CBOR (RFC7049).")
        var outCanonicalCbor = false

        // MARK: - Extra / Advanced Args

        @Option(name: .long, parsing: .upToNextOption, help: "Extra arguments passed verbatim to cardano-cli (for advanced script options like --spending-tx-in-reference, --tx-in-script-file, etc.).")
        var extraArgs: [String] = []

        // MARK: - Backend / Save / Submit

        @Flag(help: "Use cardano-cli to build the transaction (default: SwiftCardano).")
        var useCardanoCLI = false

        @Flag(inversion: .prefixedNo, help: "Save built transaction body to file.")
        var save = true

        @Flag(help: "Sign and submit the transaction after building.")
        var submit = false

        // MARK: - Validation

        mutating func validate() throws {
            let pattern = "^[0-9a-fA-F]{64}#[0-9]+$"
            for input in txIn {
                guard input.range(of: pattern, options: .regularExpression) != nil else {
                    throw ValidationError("Invalid tx-in format '\(input)'. Expected: txHash#index (64 hex + # + number)")
                }
            }
            for col in txInCollateral {
                guard col.range(of: pattern, options: .regularExpression) != nil else {
                    throw ValidationError("Invalid collateral format '\(col)'. Expected: txHash#index")
                }
            }
            for ref in readOnlyTxInReference {
                guard ref.range(of: pattern, options: .regularExpression) != nil else {
                    throw ValidationError("Invalid reference input format '\(ref)'. Expected: txHash#index")
                }
            }
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            // === REQUIRED: Transaction Inputs ===
            spacedPrint("\n\(.primary("━━━ Transaction Inputs ━━━"))\n")
            let txInPattern = "^[0-9a-fA-F]{64}#[0-9]+$"
            var addMore = true
            while addMore {
                let method = noora.singleChoicePrompt(
                    title: "Input Method",
                    question: "How do you want to specify this input?",
                    options: ["By Address (browse UTxOs)", "By Transaction ID (manual entry)"],
                    description: "You can mix both methods across multiple inputs."
                )

                if method == "By Address (browse UTxOs)" {
                    let addrStr = noora.textPrompt(
                        title: "Address",
                        prompt: "Enter the address to fetch UTxOs from:",
                        description: "Bech32 address (addr1...) or $adahandle",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Address cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    guard let addr = try? Address(from: .string(addrStr)) else {
                        noora.warning(.alert("Invalid address: \(addrStr). Skipped."))
                        continue
                    }

                    do {
                        let config = try await MultitoolConfig.load()
                        let context = try await getContext(config: config)

                        let utxos = try await noora.progressStep(
                            message: "Fetching UTxOs at \(addrStr)...",
                            successMessage: "UTxOs retrieved.",
                            errorMessage: "Failed to retrieve UTxOs.",
                            showSpinner: true
                        ) { _ in
                            try await context.utxos(address: addr)
                        }

                        guard !utxos.isEmpty else {
                            noora.warning(.alert("No UTxOs found at: \(addrStr)"))
                            continue
                        }

                        let options: [UTxOInputOption] = utxos.map { utxo in
                            UTxOInputOption(
                                input: utxo.input.description,
                                lovelace: UInt64(utxo.output.lovelace),
                                hasMultiAsset: !utxo.output.amount.multiAsset.data.isEmpty
                            )
                        }

                        let selected = noora.multipleChoicePrompt(
                            title: "Select UTxOs",
                            question: "Select the UTxOs to use as transaction inputs:",
                            options: options,
                            description: "Space to select, enter to confirm."
                        )

                        for opt in selected {
                            if !txIn.contains(opt.input) {
                                txIn.append(opt.input)
                            }
                        }
                    } catch {
                        noora.warning(.alert(
                            "Could not fetch UTxOs: \(error)",
                            takeaway: "Check your node/endpoint configuration in scm settings."
                        ))
                    }
                } else {
                    // By Transaction ID
                    let input = noora.textPrompt(
                        title: "Tx Input \(txIn.count + 1)",
                        prompt: "Enter transaction input (txHash#index):",
                        description: "Example: abc123...def456#0",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Tx input cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    if input.range(of: txInPattern, options: .regularExpression) != nil {
                        txIn.append(input)
                    } else {
                        noora.warning(.alert("Invalid format '\(input)'. Expected: txHash#index (64 hex + # + number). Skipped."))
                    }
                }

                if !txIn.isEmpty {
                    addMore = noora.yesOrNoChoicePrompt(
                        title: "Add More Inputs",
                        question: "Add more transaction inputs?",
                        defaultAnswer: false
                    )
                }
            }

            // === REQUIRED: Transaction Outputs ===
            spacedPrint("\n\(.primary("━━━ Transaction Outputs ━━━"))\n")
            addMore = true
            while addMore {
                let output = noora.textPrompt(
                    title: "Tx Output \(txOut.count + 1)",
                    prompt: "Enter transaction output (ADDRESS+VALUE):",
                    description: "Example: addr1...xyz+2000000 or addr1...xyz+2000000+1 policyId.assetName",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Tx output cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)

                txOut.append(output)

                addMore = noora.yesOrNoChoicePrompt(
                    title: "Add Another Output",
                    question: "Add another transaction output?",
                    defaultAnswer: false
                )
            }

            // === REQUIRED: Change Address ===
            spacedPrint("\n\(.primary("━━━ Change Address ━━━"))\n")
            changeAddress = noora.textPrompt(
                title: "Change Address",
                prompt: "Enter the change address (bech32):",
                description: "Excess ADA after fees will be sent here.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Change address cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            // === OPTIONAL SECTIONS — multi-select ===
            let optionalSectionChoices: [String] = [
                "Minting",
                "Validity Window (invalid-before / invalid-hereafter)",
                "Certificates",
                "Withdrawals",
                "Collateral (for Plutus scripts)",
                "Required Signers",
                "Read-only Reference Inputs",
                "Metadata",
                "Governance (Votes / Proposals)",
                "Treasury Donation",
                "Script Validity Override",
                "Witness Override",
            ]

            let selectedSections = noora.multipleChoicePrompt(
                title: "Optional Features",
                question: "Which optional features do you need? (Select all that apply)",
                options: optionalSectionChoices,
                description: "Use space to select, enter to confirm. Select none to finish with just the basics."
            )

            let needs = Set(selectedSections)

            // === OPTIONAL: Minting ===
            if needs.contains("Minting") {
                spacedPrint("\n\(.primary("━━━ Minting ━━━"))\n")
                addMore = true
                while addMore {
                    let mintValue = noora.textPrompt(
                        title: "Mint Value \(mint.count + 1)",
                        prompt: "Enter mint value (multi-asset syntax):",
                        description: "Example: 100 abc123....tokenName",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !mintValue.isEmpty {
                        mint.append(mintValue)

                        let scriptPath = noora.textPrompt(
                            title: "Mint Script File",
                            prompt: "Enter minting script file path (leave empty to provide via --extra-args):",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)

                        if !scriptPath.isEmpty {
                            extraArgs += ["--mint-script-file", scriptPath]
                        }
                    }

                    addMore = noora.yesOrNoChoicePrompt(
                        title: "Add More Minting",
                        question: "Add another mint value?",
                        defaultAnswer: false
                    )
                }
            }

            // === OPTIONAL: Validity Window ===
            if needs.contains("Validity Window (invalid-before / invalid-hereafter)") {
                spacedPrint("\n\(.primary("━━━ Validity Window ━━━"))\n")
                let beforeStr = noora.textPrompt(
                    title: "Invalid Before",
                    prompt: "Enter invalid-before slot (leave empty to skip):",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !beforeStr.isEmpty, let slot = Int(beforeStr) {
                    invalidBefore = slot
                }

                let hereafterStr = noora.textPrompt(
                    title: "Invalid Hereafter",
                    prompt: "Enter invalid-hereafter slot (leave empty to skip):",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !hereafterStr.isEmpty, let slot = Int(hereafterStr) {
                    invalidHereafter = slot
                }
            }

            // === OPTIONAL: Certificates ===
            if needs.contains("Certificates") {
                spacedPrint("\n\(.primary("━━━ Certificates ━━━"))\n")
                addMore = true
                while addMore {
                    let certPath = noora.textPrompt(
                        title: "Certificate File \(certificateFile.count + 1)",
                        prompt: "Enter certificate file path:",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !certPath.isEmpty {
                        certificateFile.append(FilePath(certPath))
                    }

                    addMore = noora.yesOrNoChoicePrompt(
                        title: "Add Another Certificate",
                        question: "Add another certificate?",
                        defaultAnswer: false
                    )
                }
            }

            // === OPTIONAL: Withdrawals ===
            if needs.contains("Withdrawals") {
                spacedPrint("\n\(.primary("━━━ Withdrawals ━━━"))\n")
                addMore = true
                while addMore {
                    let w = noora.textPrompt(
                        title: "Withdrawal \(withdrawal.count + 1)",
                        prompt: "Enter withdrawal (StakeAddress+Lovelace):",
                        description: "Example: stake1...+1000000",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !w.isEmpty { withdrawal.append(w) }

                    addMore = noora.yesOrNoChoicePrompt(
                        title: "Add Another Withdrawal",
                        question: "Add another withdrawal?",
                        defaultAnswer: false
                    )
                }
            }

            // === OPTIONAL: Collateral ===
            if needs.contains("Collateral (for Plutus scripts)") {
                spacedPrint("\n\(.primary("━━━ Collateral ━━━"))\n")
                addMore = true
                while addMore {
                    let col = noora.textPrompt(
                        title: "Collateral Input \(txInCollateral.count + 1)",
                        prompt: "Enter collateral input (txHash#index):",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !col.isEmpty { txInCollateral.append(col) }

                    addMore = noora.yesOrNoChoicePrompt(
                        title: "Add Another Collateral",
                        question: "Add another collateral input?",
                        defaultAnswer: false
                    )
                }

                let returnCol = noora.textPrompt(
                    title: "Collateral Return",
                    prompt: "Enter collateral return output (ADDRESS+VALUE, leave empty to skip):",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !returnCol.isEmpty { txOutReturnCollateral = returnCol }

                let totalColStr = noora.textPrompt(
                    title: "Total Collateral",
                    prompt: "Enter total collateral amount (e.g., 5 ADA, 5000000 lovelace; leave empty to skip):",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !totalColStr.isEmpty,
                   let lovelace = AdaFormatter(defaultUnit: .ada).toLovelace(totalColStr) {
                    txTotalCollateral = Int(lovelace)
                }
            }

            // === OPTIONAL: Required Signers ===
            if needs.contains("Required Signers") {
                spacedPrint("\n\(.primary("━━━ Required Signers ━━━"))\n")
                addMore = true
                while addMore {
                    let choice = noora.singleChoicePrompt(
                        title: "Signer Type",
                        question: "How do you want to specify the required signer?",
                        options: ["Key file path", "Verification key hash"],
                        description: "Required signers must sign the transaction."
                    )

                    if choice == "Key file path" {
                        let path = noora.textPrompt(
                            title: "Signer Key File",
                            prompt: "Enter signing key file path:",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !path.isEmpty { requiredSigner.append(FilePath(path)) }
                    } else {
                        let hash = noora.textPrompt(
                            title: "Signer Key Hash",
                            prompt: "Enter verification key hash:",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !hash.isEmpty { requiredSignerHash.append(hash) }
                    }

                    addMore = noora.yesOrNoChoicePrompt(
                        title: "Add Another Signer",
                        question: "Add another required signer?",
                        defaultAnswer: false
                    )
                }
            }

            // === OPTIONAL: Read-only Reference Inputs ===
            if needs.contains("Read-only Reference Inputs") {
                spacedPrint("\n\(.primary("━━━ Read-only Reference Inputs ━━━"))\n")
                addMore = true
                while addMore {
                    let ref = noora.textPrompt(
                        title: "Reference Input \(readOnlyTxInReference.count + 1)",
                        prompt: "Enter read-only reference input (txHash#index):",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !ref.isEmpty { readOnlyTxInReference.append(ref) }

                    addMore = noora.yesOrNoChoicePrompt(
                        title: "Add Another Reference Input",
                        question: "Add another reference input?",
                        defaultAnswer: false
                    )
                }
            }

            // === OPTIONAL: Metadata ===
            if needs.contains("Metadata") {
                spacedPrint("\n\(.primary("━━━ Metadata ━━━"))\n")

                let addJsonMeta = noora.yesOrNoChoicePrompt(
                    title: "JSON Metadata",
                    question: "Add JSON metadata files?",
                    defaultAnswer: false
                )
                if addJsonMeta {
                    addMore = true
                    while addMore {
                        let path = noora.textPrompt(
                            title: "Metadata JSON File \(metadataJsonFile.count + 1)",
                            prompt: "Enter JSON metadata file path:",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !path.isEmpty { metadataJsonFile.append(FilePath(path)) }
                        addMore = noora.yesOrNoChoicePrompt(
                            title: "Add Another",
                            question: "Add another JSON metadata file?",
                            defaultAnswer: false
                        )
                    }
                }

                let addCborMeta = noora.yesOrNoChoicePrompt(
                    title: "CBOR Metadata",
                    question: "Add CBOR metadata files?",
                    defaultAnswer: false
                )
                if addCborMeta {
                    addMore = true
                    while addMore {
                        let path = noora.textPrompt(
                            title: "Metadata CBOR File \(metadataCborFile.count + 1)",
                            prompt: "Enter CBOR metadata file path:",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !path.isEmpty { metadataCborFile.append(FilePath(path)) }
                        addMore = noora.yesOrNoChoicePrompt(
                            title: "Add Another",
                            question: "Add another CBOR metadata file?",
                            defaultAnswer: false
                        )
                    }
                }

                let addAux = noora.yesOrNoChoicePrompt(
                    title: "Auxiliary Scripts",
                    question: "Add auxiliary script files?",
                    defaultAnswer: false
                )
                if addAux {
                    addMore = true
                    while addMore {
                        let path = noora.textPrompt(
                            title: "Auxiliary Script File \(auxiliaryScriptFile.count + 1)",
                            prompt: "Enter auxiliary script file path:",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !path.isEmpty { auxiliaryScriptFile.append(FilePath(path)) }
                        addMore = noora.yesOrNoChoicePrompt(
                            title: "Add Another",
                            question: "Add another auxiliary script file?",
                            defaultAnswer: false
                        )
                    }
                }

                jsonMetadataDetailedSchema = noora.yesOrNoChoicePrompt(
                    title: "Metadata Schema",
                    question: "Use detailed JSON metadata schema?",
                    defaultAnswer: false,
                    description: "Use detailed schema conversion from JSON to tx metadata."
                )
            }

            // === OPTIONAL: Governance ===
            if needs.contains("Governance (Votes / Proposals)") {
                spacedPrint("\n\(.primary("━━━ Governance ━━━"))\n")

                let addVotes = noora.yesOrNoChoicePrompt(
                    title: "Votes",
                    question: "Add vote files?",
                    defaultAnswer: false
                )
                if addVotes {
                    addMore = true
                    while addMore {
                        let path = noora.textPrompt(
                            title: "Vote File \(voteFile.count + 1)",
                            prompt: "Enter vote file path:",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !path.isEmpty { voteFile.append(FilePath(path)) }
                        addMore = noora.yesOrNoChoicePrompt(
                            title: "Add Another",
                            question: "Add another vote file?",
                            defaultAnswer: false
                        )
                    }
                }

                let addProposals = noora.yesOrNoChoicePrompt(
                    title: "Proposals",
                    question: "Add proposal files?",
                    defaultAnswer: false
                )
                if addProposals {
                    addMore = true
                    while addMore {
                        let path = noora.textPrompt(
                            title: "Proposal File \(proposalFile.count + 1)",
                            prompt: "Enter proposal file path:",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !path.isEmpty { proposalFile.append(FilePath(path)) }
                        addMore = noora.yesOrNoChoicePrompt(
                            title: "Add Another",
                            question: "Add another proposal file?",
                            defaultAnswer: false
                        )
                    }
                }
            }

            // === OPTIONAL: Treasury Donation ===
            if needs.contains("Treasury Donation") {
                spacedPrint("\n\(.primary("━━━ Treasury Donation ━━━"))\n")
                let donStr = noora.textPrompt(
                    title: "Treasury Donation",
                    prompt: "Enter donation amount (e.g., 100 ADA, 100000000 lovelace):",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !donStr.isEmpty,
                   let amount = AdaFormatter(defaultUnit: .ada).toLovelace(donStr) {
                    treasuryDonation = amount
                }
            }

            // === OPTIONAL: Script Validity Override ===
            if needs.contains("Script Validity Override") {
                let validity = noora.singleChoicePrompt(
                    title: "Script Validity",
                    question: "Set script validity assertion:",
                    options: ["Script Valid (default)", "Script Invalid"],
                    description: "If invalid: script will fail and collateral will be taken."
                )
                scriptInvalid = validity == "Script Invalid"
            }

            // === OPTIONAL: Witness Override ===
            if needs.contains("Witness Override") {
                let wStr = noora.textPrompt(
                    title: "Witness Override",
                    prompt: "Enter witness count override:",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !wStr.isEmpty, let count = Int(wStr) {
                    witnessOverride = count
                }
            }

            // === Output File ===
            spacedPrint("\n\(.primary("━━━ Output ━━━"))\n")
            let outPath = noora.textPrompt(
                title: "Output File",
                prompt: "Enter output file path for the transaction body:",
                description: "The built and balanced transaction will be saved here.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Output file path is required.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            outFile = FilePath(outPath)

            useCardanoCLI = noora.yesOrNoChoicePrompt(
                title: "Build Method",
                question: "Use cardano-cli to build transaction?",
                defaultAnswer: false,
                description: "Default: SwiftCardano. Use cardano-cli for advanced script options."
            )

            save = noora.yesOrNoChoicePrompt(
                title: "Save Transaction",
                question: "Save transaction body to file?",
                defaultAnswer: true
            )

            submit = noora.yesOrNoChoicePrompt(
                title: "Sign and Submit",
                question: "Sign and submit the transaction after building?",
                defaultAnswer: false
            )

            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if txIn.isEmpty || changeAddress == nil || outFile == nil {
                try await wizard()
            }

            guard !txIn.isEmpty else {
                noora.error("At least one --tx-in is required.")
                throw ExitCode.validationFailure
            }

            guard let changeAddress = changeAddress else {
                noora.error("--change-address is required.")
                throw ExitCode.validationFailure
            }

            guard let outFile = outFile else {
                noora.error("--out-file is required.")
                throw ExitCode.validationFailure
            }

            // Resolve relative paths against CWD so downstream helpers (AbsolutePath, etc.) don't fail.
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let resolvedOutFile = outFile.string.hasPrefix("/") ? outFile : cwd.appending(outFile.string)

            let config = try await MultitoolConfig.load()
            let logger = getLogger(config: config)

            spacedPrint("\n\(.primary("━━━ Building Transaction ━━━"))\n")

            if useCardanoCLI {
                try await buildWithCardanoCLI(
                    config: config,
                    logger: logger,
                    changeAddress: changeAddress,
                    outFile: resolvedOutFile
                )
            } else {
                try await buildWithSwiftCardano(
                    config: config,
                    logger: logger,
                    changeAddress: changeAddress,
                    outFile: resolvedOutFile
                )
            }

            if submit {
                await TransactionMainCommand.Sign.main([
                    "--tx-file", resolvedOutFile.string,
                    "--submit"
                ])
            } else if !save {
                try? FileManager.default.removeItem(atPath: resolvedOutFile.string)
            }
        }

        // MARK: - cardano-cli Build

        private func buildWithCardanoCLI(
            config: MultitoolConfig,
            logger: Logger,
            changeAddress: String,
            outFile: FilePath
        ) async throws {
            let cli = try await CardanoCLI(
                configuration: Config(cardano: config.cardano),
                logger: logger
            )

            var args: [String] = []

            for input in txIn {
                args += ["--tx-in", input]
            }
            for output in txOut {
                args += ["--tx-out", output]
            }
            args += ["--change-address", changeAddress]

            for ref in readOnlyTxInReference {
                args += ["--read-only-tx-in-reference", ref]
            }
            for col in txInCollateral {
                args += ["--tx-in-collateral", col]
            }
            if let ret = txOutReturnCollateral {
                args += ["--tx-out-return-collateral", ret]
            }
            if let total = txTotalCollateral {
                args += ["--tx-total-collateral", "\(total)"]
            }
            for signer in requiredSigner {
                args += ["--required-signer", signer.string]
            }
            for hash in requiredSignerHash {
                args += ["--required-signer-hash", hash]
            }

            if scriptInvalid {
                args.append("--script-invalid")
            } else if scriptValid {
                args.append("--script-valid")
            }
            if let override = witnessOverride {
                args += ["--witness-override", "\(override)"]
            }

            if let before = invalidBefore {
                args += ["--invalid-before", "\(before)"]
            }
            if let hereafter = invalidHereafter {
                args += ["--invalid-hereafter", "\(hereafter)"]
            }

            for mintValue in mint {
                args += ["--mint", mintValue]
            }

            for cert in certificateFile {
                args += ["--certificate-file", cert.string]
            }
            for w in withdrawal {
                args += ["--withdrawal", w]
            }

            if jsonMetadataDetailedSchema {
                args.append("--json-metadata-detailed-schema")
            }
            for aux in auxiliaryScriptFile {
                args += ["--auxiliary-script-file", aux.string]
            }
            for jsonMeta in metadataJsonFile {
                args += ["--metadata-json-file", jsonMeta.string]
            }
            for cborMeta in metadataCborFile {
                args += ["--metadata-cbor-file", cborMeta.string]
            }

            for vote in voteFile {
                args += ["--vote-file", vote.string]
            }
            for proposal in proposalFile {
                args += ["--proposal-file", proposal.string]
            }
            if let donation = treasuryDonation {
                args += ["--treasury-donation", "\(donation)"]
            }

            if outCanonicalCbor {
                args.append("--out-canonical-cbor")
            }

            args += extraArgs
            args += ["--out-file", outFile.string]

            spacedPrint("Using \(.primary("cardano-cli")) to build transaction...")

            let fee = try await cli.transaction.build(arguments: args)

            noora.success(.alert(
                "Transaction built successfully.",
                takeaways: [
                    "Fee: \(.primary("\(lovelaceToAdaString(UInt64(fee)))")) / \(.primary("\(fee)")) lovelace",
                    "Saved to: \(.path(try AbsolutePath(validating: outFile.string)))"
                ]
            ))
        }

        // MARK: - SwiftCardano Build

        private func buildWithSwiftCardano(
            config: MultitoolConfig,
            logger: Logger,
            changeAddress: String,
            outFile: FilePath
        ) async throws {
            let context = try await getContext(config: config)
            let txBuilder = TxBuilder(context: context, logger: logger)

            spacedPrint("Using \(.primary("swift-cardano")) to build transaction...")

            guard let changeAddr = try? Address(from: .string(changeAddress)) else {
                noora.error(.alert(
                    "Invalid change address: \(changeAddress)",
                    takeaways: ["Ensure the address is a valid bech32 Cardano address."]
                ))
                throw ExitCode.validationFailure
            }

            // Resolve tx-ins by querying UTxOs at the change address
            spacedPrint("\nResolving transaction inputs from chain...")
            let allUtxos = try await noora.progressStep(
                message: "Fetching UTxOs from change address...",
                successMessage: "UTxOs retrieved.",
                errorMessage: "Failed to retrieve UTxOs.",
                showSpinner: true
            ) { _ in
                try await context.utxos(address: changeAddr)
            }

            let utxoMap = Dictionary(uniqueKeysWithValues: allUtxos.map { ($0.input.description, $0) })

            var unresolvedInputs: [String] = []
            for input in txIn {
                if let utxo = utxoMap[input] {
                    txBuilder.addInput(utxo)
                } else {
                    unresolvedInputs.append(input)
                }
            }

            if !unresolvedInputs.isEmpty {
                noora.warning(.alert(
                    "Could not resolve \(unresolvedInputs.count) input(s) from the change address: \(unresolvedInputs.joined(separator: ", "))",
                    takeaway: "These UTxOs may belong to a different address. Use --use-cardano-cli for transactions spanning multiple addresses."
                ))

                if txBuilder.inputs.isEmpty {
                    noora.error("No inputs could be resolved. Cannot build transaction.")
                    throw ExitCode.failure
                }

                let continueAnyway = noora.yesOrNoChoicePrompt(
                    title: "Continue?",
                    question: "Continue building with only the resolvable inputs?",
                    defaultAnswer: false
                )
                guard continueAnyway else {
                    throw ExitCode.failure
                }
            }

            // Transaction outputs
            for outputStr in txOut {
                // Parse "ADDRESS+VALUE" — split on first '+'
                let plusIdx = outputStr.firstIndex(of: "+")
                guard let plusIdx else {
                    noora.warning(.alert("Could not parse tx-out '\(outputStr)' — missing '+'. Skipped."))
                    continue
                }
                let addrStr = String(outputStr[..<plusIdx])
                let valueStr = String(outputStr[outputStr.index(after: plusIdx)...])

                guard let addr = try? Address(from: .string(addrStr)) else {
                    noora.warning(.alert("Invalid address in tx-out '\(outputStr)'. Skipped."))
                    continue
                }
                guard let lovelace = Int(valueStr.trimmingCharacters(in: .whitespaces)) else {
                    noora.warning(.alert(
                        "Could not parse lovelace value in tx-out '\(outputStr)'. Skipped.",
                        takeaway: "Multi-asset outputs require --use-cardano-cli."
                    ))
                    continue
                }
                let txOutput = TransactionOutput(address: addr, amount: Value(coin: Int64(lovelace)))
                try txBuilder.addOutput(txOutput)
            }

            // Validity window
            if let before = invalidBefore { txBuilder.validityStart = SlotNumber(before) }
            if let hereafter = invalidHereafter { txBuilder.ttl = SlotNumber(hereafter) }

            // Witness override
            if let override = witnessOverride { txBuilder.witnessOverride = override }

            // Certificates — loading from file is not available in the SwiftCardano public API.
            // Warn the user and suggest --use-cardano-cli.
            if !certificateFile.isEmpty {
                noora.warning(.alert(
                    "Certificate files are not supported in SwiftCardano build mode.",
                    takeaway: "Use --use-cardano-cli to include certificates in the transaction."
                ))
            }

            // Withdrawals
            for withdrawalStr in withdrawal {
                guard let plusIdx = withdrawalStr.lastIndex(of: "+") else {
                    noora.warning(.alert("Could not parse withdrawal '\(withdrawalStr)' — missing '+'. Skipped."))
                    continue
                }
                let stakeAddrStr = String(withdrawalStr[..<plusIdx])
                let amountStr = String(withdrawalStr[withdrawalStr.index(after: plusIdx)...])
                guard let amount = UInt64(amountStr.trimmingCharacters(in: .whitespaces)),
                      let stakeAddr = try? Address(from: .string(stakeAddrStr)) else {
                    noora.warning(.alert("Could not parse withdrawal '\(withdrawalStr)'. Skipped."))
                    continue
                }
                var withdrawals = txBuilder.withdrawals ?? Withdrawals([:])
                withdrawals.data[RewardAccount(stakeAddr.toBytes())] = Coin(amount)
                txBuilder.withdrawals = withdrawals
            }

            // Treasury donation
            if let donation = treasuryDonation {
                try txBuilder.addTreasuryDonation(Int(donation))
            }

            // Build
            let txBody = try await txBuilder.build(changeAddress: changeAddr)
            let tx = Transaction(
                transactionBody: txBody,
                transactionWitnessSet: try txBuilder.buildWitnessSet(),
                auxiliaryData: txBuilder.auxiliaryData
            )

            try tx.save(to: outFile.string, overwrite: true)

            noora.success(.alert(
                "Transaction built successfully.",
                takeaways: [
                    "Fee: \(.primary("\(lovelaceToAdaString(UInt64(txBody.fee)))")) / \(.primary("\(txBody.fee)")) lovelace",
                    "Inputs: \(.primary("\(txBody.inputs.count)"))",
                    "Outputs: \(.primary("\(txBody.outputs.count)"))",
                    "Saved to: \(.path(try AbsolutePath(validating: outFile.string)))"
                ]
            ))
        }
    }
}
