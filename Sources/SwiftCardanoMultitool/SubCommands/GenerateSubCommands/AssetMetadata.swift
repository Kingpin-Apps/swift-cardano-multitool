import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoTokenRegistry

extension GenerateMainCommand {

    struct AssetMeta: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "asset-meta",
            abstract: "Generate signed off-chain asset metadata for the Cardano Token Registry.",
            discussion: """
            Combines a native-script minting policy on disk with user-supplied
            metadata fields (name, description, ticker, url, decimals, logo) to
            produce a fully-signed Cardano Token Registry submission JSON
            (CIP-26) — ready to PR to the cardano-token-registry repository.

            Writes two files to the output directory:
              <policyId><assetNameHex>.json  — the canonical registry submission
              <policyName>.<assetName>.asset — local state for re-runs and querying

            Re-running with the same policy + asset reads the existing .asset
            sidecar, bumps the sequence number, and re-signs.
            """,
            aliases: ["assetmeta"]
        )

        @Option(name: .shortAndLong, help: "Stem of the policy on disk. Loads <name>.policy.{id,script,skey}.")
        var policyName: String? = nil

        @Option(name: .shortAndLong, help: "Asset name. Plain ASCII (e.g. 'MyToken') or {hex} for raw bytes (e.g. '{4d79546f6b656e}'). Max 32 bytes.")
        var assetName: String? = nil

        @Option(name: .long, help: "Display name of the asset (1-50 chars).")
        var metaName: String? = nil

        @Option(name: .long, help: "Description of the asset (1-500 chars).")
        var metaDescription: String? = nil

        @Option(name: .long, help: "Ticker symbol (2-9 chars).")
        var metaTicker: String? = nil

        @Option(name: .long, help: "Project URL (https:// only, max 250 chars).")
        var metaUrl: String? = nil

        @Option(name: .long, help: "Decimal places of the asset (0-255).")
        var metaDecimals: Int? = nil

        @Option(name: .long, help: "Path to a PNG logo file (max 64 KiB).")
        var metaLogoPath: String? = nil

        @Option(name: .long, help: "Output directory. Defaults to the current working directory.")
        var outputDir: String? = nil

        mutating func validate() throws {
            if let decimals = metaDecimals {
                guard (0...255).contains(decimals) else {
                    throw ValidationError("--meta-decimals must be between 0 and 255.")
                }
            }
        }

        mutating func wizard() async throws {
            policyName = try selectPolicyName()

            let rawAssetName = noora.textPrompt(
                title: "Asset Name",
                prompt: "Enter the asset name:",
                description: "Plain ASCII (e.g. 'MyToken') or wrap raw bytes in braces (e.g. '{4d79546f6b656e}'). Max 32 bytes.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Asset name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            assetName = rawAssetName

            metaName = noora.textPrompt(
                title: "Display Name",
                prompt: "Enter the display name (1-50 chars):",
                description: "Shown in wallets and explorers.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Display name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            metaDescription = noora.textPrompt(
                title: "Description",
                prompt: "Enter a description (1-500 chars):",
                description: "A short description of the asset.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Description cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            if noora.yesOrNoChoicePrompt(
                title: "Ticker",
                question: "Add a ticker symbol?",
                defaultAnswer: false,
                description: "2-9 character ticker (e.g. 'MTK')."
            ) {
                metaTicker = noora.textPrompt(
                    title: "Ticker",
                    prompt: "Enter the ticker (2-9 chars):",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Ticker cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if noora.yesOrNoChoicePrompt(
                title: "Project URL",
                question: "Add a project URL?",
                defaultAnswer: false,
                description: "Must start with https:// (max 250 chars)."
            ) {
                metaUrl = noora.textPrompt(
                    title: "URL",
                    prompt: "Enter the URL (https://...):",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "URL cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if noora.yesOrNoChoicePrompt(
                title: "Decimals",
                question: "Add a decimal-places value?",
                defaultAnswer: false,
                description: "Integer 0-255 (e.g. 6 for micro-units)."
            ) {
                let raw = noora.textPrompt(
                    title: "Decimals",
                    prompt: "Enter the number of decimal places (0-255):",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Decimals cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let n = Int(raw), (0...255).contains(n) else {
                    noora.error(.alert("Decimals must be an integer in 0-255."))
                    throw ExitCode.validationFailure
                }
                metaDecimals = n
            }

            if noora.yesOrNoChoicePrompt(
                title: "Logo",
                question: "Add a PNG logo?",
                defaultAnswer: false,
                description: "Path to a PNG file (max 64 KiB)."
            ) {
                metaLogoPath = noora.textPrompt(
                    title: "Logo Path",
                    prompt: "Enter the path to the PNG file:",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Logo path cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            try self.validate()
        }

        mutating func run() async throws {
            if policyName == nil && metaName == nil {
                try await self.wizard()
            }

            guard let policyName = policyName, !policyName.isEmpty else {
                noora.error(.alert("--policy-name is required."))
                throw ExitCode.validationFailure
            }
            guard let assetNameInput = assetName else {
                noora.error(.alert("--asset-name is required."))
                throw ExitCode.validationFailure
            }
            guard let metaNameValue = metaName, !metaNameValue.isEmpty else {
                noora.error(.alert("--meta-name is required."))
                throw ExitCode.validationFailure
            }
            guard let metaDescriptionValue = metaDescription, !metaDescriptionValue.isEmpty else {
                noora.error(.alert("--meta-description is required."))
                throw ExitCode.validationFailure
            }

            _ = try await MultitoolConfig.load()

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let outDir = outputDir.map { FilePath($0) } ?? cwd

            let policy = try loadPolicyForAssetMeta(name: policyName, in: cwd)
            let (assetDisplay, assetNameHex) = try parseAssetName(assetNameInput)

            let subjectHex = (policy.policyId + assetNameHex).lowercased()
            let subject: Subject
            do {
                subject = try Subject(subjectHex)
            } catch {
                noora.error(.alert(
                    "Invalid asset subject: \(.danger(subjectHex))",
                    takeaways: ["Expected 56-120 lowercase hex chars (policyId || assetNameHex)."]
                ))
                throw ExitCode.failure
            }

            let registryJSON = RegistryFile.canonicalURL(
                for: subject,
                in: URL(fileURLWithPath: outDir.string)
            )
            let sidecarName = assetDisplay.isEmpty ? policyName : "\(policyName).\(assetDisplay)"
            let sidecarPath = outDir.appending("\(sidecarName).asset")

            let previousSidecar = loadAssetSidecar(at: sidecarPath)
            let nextSeq = (previousSidecar?.sequenceNumber).map { $0 + 1 } ?? 0
            let action = previousSidecar == nil ? "created Token-Registry-JSON" : "updated Token-Registry-JSON"

            spacedPrint("Building registry entry for subject: \(.primary(subjectHex)) \(.muted("(seq \(nextSeq))"))")

            var entry = GoguenRegistryEntry(subject: subject)
            do {
                entry.policy = try WellKnown.Policy(nativeScript: policy.nativeScript)
            } catch {
                noora.error(.alert(
                    "Failed to encode the policy script: \(error.localizedDescription)",
                    takeaways: ["The script in \(policyName).policy.script could not be serialized for the registry entry."]
                ))
                throw ExitCode.failure
            }

            let seqNum = SequenceNumber(nextSeq)

            do {
                entry.name = Attested(
                    value: try WellKnown.Name(metaNameValue),
                    sequenceNumber: seqNum
                )
                entry.description = Attested(
                    value: try WellKnown.Description(metaDescriptionValue),
                    sequenceNumber: seqNum
                )
                if let t = metaTicker, !t.isEmpty {
                    entry.ticker = Attested(
                        value: try WellKnown.Ticker(t),
                        sequenceNumber: seqNum
                    )
                }
                if let u = metaUrl, !u.isEmpty {
                    entry.url = Attested(
                        value: try WellKnown.Url(u),
                        sequenceNumber: seqNum
                    )
                }
                if let d = metaDecimals {
                    entry.decimals = Attested(
                        value: try WellKnown.Decimals(d),
                        sequenceNumber: seqNum
                    )
                }
                if let logoPath = metaLogoPath, !logoPath.isEmpty {
                    let logoURL = URL(fileURLWithPath: logoPath)
                    let logoData = try Data(contentsOf: logoURL)
                    entry.logo = Attested(
                        value: try WellKnown.Logo(data: logoData),
                        sequenceNumber: seqNum
                    )
                }
            } catch let error as TokenRegistryError {
                noora.error(.alert(
                    "Metadata field rejected by the registry validator.",
                    takeaways: ["\(error)"]
                ))
                throw ExitCode.failure
            }

            let signer = try await loadAssetMetaSigner(skeyPath: policy.skeyPath)

            try _ = await noora.progressStep(
                message: "Signing metadata fields...",
                successMessage: "All fields signed.",
                errorMessage: "Signing failed.",
                showSpinner: true
            ) { _ in
                if entry.name        != nil { try signer.signName        (&entry.name!,        subject) }
                if entry.description != nil { try signer.signDescription (&entry.description!, subject) }
                if entry.ticker      != nil { try signer.signTicker      (&entry.ticker!,      subject) }
                if entry.url         != nil { try signer.signUrl         (&entry.url!,         subject) }
                if entry.logo        != nil { try signer.signLogo        (&entry.logo!,        subject) }
                if entry.decimals    != nil { try signer.signDecimals    (&entry.decimals!,    subject) }
            }

            let issues = entry.validate(options: .finalize)
            if !issues.isEmpty {
                noora.warning(.alert(
                    "Registry validation reported \(issues.count) issue(s).",
                    takeaway: "See the list below before deciding whether to save."
                ))
                for issue in issues {
                    spacedPrint("  \(.muted("•")) \(.danger("\(issue.description)"))")
                }
                let proceed = noora.yesOrNoChoicePrompt(
                    title: "Save anyway?",
                    question: "Save the entry despite validation issues?",
                    defaultAnswer: false
                )
                if !proceed {
                    noora.info("Aborted. Files not written.")
                    throw ExitCode.failure
                }
            }

            try? FileManager.default.removeItem(at: registryJSON)
            do {
                try RegistryFile.save(entry, to: registryJSON)
            } catch {
                noora.error(.alert(
                    "Failed to write registry JSON: \(error.localizedDescription)",
                    takeaways: ["Check write permissions in \(outDir.string)."]
                ))
                throw ExitCode.failure
            }

            let sidecar = AssetSidecar(
                metaName: metaNameValue,
                metaDescription: metaDescriptionValue,
                metaTicker: metaTicker,
                metaUrl: metaUrl,
                metaDecimals: metaDecimals,
                metaLogoPNG: metaLogoPath,
                name: assetDisplay,
                hexname: assetNameHex,
                policyID: policy.policyId,
                policyValidBeforeSlot: policy.validBeforeSlot.map { String($0) } ?? "unlimited",
                subject: subjectHex,
                sequenceNumber: nextSeq,
                lastUpdate: rfc2822Timestamp(),
                lastAction: action
            )

            try writeAssetSidecar(sidecar, to: sidecarPath)

            let registryFilePath = FilePath(registryJSON.path)
            try await FileUtils.fileLock(registryFilePath)
            try await FileUtils.fileLock(sidecarPath)

            print(noora.format(
                "\nRegistry Entry: \(.path(try .init(validating: registryFilePath.string)))\n"
            ))
            try await FileUtils.displayJSONFile(registryFilePath)

            print(noora.format(
                "\nAsset Sidecar: \(.path(try .init(validating: sidecarPath.string)))\n"
            ))
            try await FileUtils.displayJSONFile(sidecarPath)

            noora.success(.alert(
                "Asset metadata generated successfully.",
                takeaways: [
                    "Submit the registry JSON via a PR to the cardano-token-registry.",
                    "Run 'scm query asset-meta \(sidecarPath.string)' after the PR merges."
                ]
            ))
        }

        // MARK: - Helpers

        private func selectPolicyName() throws -> String {
            return try selectPolicyNameInteractive()
        }
    }
}
