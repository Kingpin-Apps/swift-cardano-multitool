import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

/// The registration parameters a user can choose to edit.
enum PoolParamField: String, CaseIterable, CustomStringConvertible, Equatable {
    case pledge
    case cost
    case margin
    case relays
    case owners
    case rewardAccount
    case vrfKey
    case metadata

    var description: String {
        switch self {
            case .pledge: return "Pledge"
            case .cost: return "Cost"
            case .margin: return "Margin"
            case .relays: return "Relays"
            case .owners: return "Owners"
            case .rewardAccount: return "Reward account"
            case .vrfKey: return "VRF key"
            case .metadata: return "Metadata"
        }
    }
}

/// Prompt for a single relay.
func promptPoolRelay() -> PoolRelay {
    let relayType: SPORelayType = noora.singleChoicePrompt(
        title: "Relay Type",
        question: "Select the relay type:",
        description: "IP for direct IP address, DNS for domain name."
    )

    let host = noora.textPrompt(
        title: "Relay Host",
        prompt: relayType == .ip
            ? "Enter the relay IP address:"
            : "Enter the relay DNS hostname:",
        collapseOnAnswer: true,
        validationRules: [
            NonEmptyValidationRule(error: "Host cannot be empty."),
            LengthValidationRule(max: 64, error: "Host must be 64 chars or less.")
        ]
    ).trimmingCharacters(in: .whitespacesAndNewlines)

    let hostType: HostType
    if relayType == .ip {
        hostType = noora.singleChoicePrompt(
            title: "Host Type",
            question: "Select the host type:",
            options: [HostType.ipv4, HostType.ipv6],
            description: "IPv4 or IPv6 address type."
        )
    } else {
        hostType = noora.singleChoicePrompt(
            title: "Host Type",
            question: "Select the DNS host type:",
            options: [HostType.single, HostType.multi],
            description: "Single host (A/AAAA record) or multi-host (SRV record, no port)."
        )
    }

    var port: String? = nil
    if hostType != .multi {
        let portInput = noora.textPrompt(
            title: "Relay Port",
            prompt: "Enter the relay port (default 3001):",
            collapseOnAnswer: true,
            validationRules: [
                PortOrEmptyValidationRule(error: "Port must be empty or between 1 and 65535.")
            ]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        port = portInput.isEmpty ? "3001" : portInput
    }

    return PoolRelay(type: relayType, host: host, port: port, hostType: hostType)
}

/// Lovelace as a plain ADA amount for prompt defaults, e.g. `340` or `1.5`.
private func adaDefault(_ lovelace: Int) -> String {
    "\(Decimal(lovelace) / AdaFormatter.lovelacePerAda)"
}

/// Walk the user through editing the selected fields of a pool's parameters.
func editPoolParams(
    _ draft: inout PoolParamsDraft,
    fields: [PoolParamField],
    minPoolCost: Int,
    network: NetworkId,
    keys: PoolKeyFileMatcher
) async throws {
    let adaFormatter = AdaFormatter(defaultUnit: .ada)

    for field in PoolParamField.allCases where fields.contains(field) {
        print(noora.format("\n\(.primary("── \(field.description) ──"))\n"))

        switch field {
            case .pledge:
                let input = noora.textPrompt(
                    title: "Pledge",
                    prompt: "Enter the new pledge (e.g., 100K, 1.5M ADA, 100000000000 lovelace):",
                    description: "Currently \(PoolParamsFormat.ada(draft.pledge)). Defaults to ADA.",
                    defaultValue: adaDefault(draft.pledge),
                    collapseOnAnswer: true,
                    validationRules: [AdaValidationRule(defaultUnit: .ada, error: "Pledge must be a non-negative ADA amount.")]
                )
                draft.pledge = Int(adaFormatter.toLovelace(input) ?? UInt64(draft.pledge))

            case .cost:
                let input = noora.textPrompt(
                    title: "Cost",
                    prompt: "Enter the new fixed cost per epoch (minimum \(lovelaceToAdaFormatString(UInt64(minPoolCost)))):",
                    description: "Currently \(PoolParamsFormat.ada(draft.cost)). Defaults to ADA.",
                    defaultValue: adaDefault(draft.cost),
                    collapseOnAnswer: true,
                    validationRules: [AdaValidationRule(
                        defaultUnit: .ada,
                        minLovelace: UInt64(minPoolCost),
                        error: "Cost must be at least \(lovelaceToAdaFormatString(UInt64(minPoolCost)))."
                    )]
                )
                draft.cost = Int(adaFormatter.toLovelace(input) ?? UInt64(draft.cost))

            case .margin:
                var margin: UnitInterval? = nil
                while margin == nil {
                    let input = noora.textPrompt(
                        title: "Margin",
                        prompt: "Enter the new margin (e.g., 0.05, 5% or 1/20):",
                        description: "Currently \(PoolParamsFormat.margin(draft.margin)).",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Margin cannot be empty.")]
                    )
                    margin = PoolParamsFormat.parseMargin(input)
                    if margin == nil {
                        noora.warning(.alert("Margin must be a number between 0 and 1, a percentage, or a fraction."))
                    }
                }
                draft.margin = margin!

            case .relays:
                try editRelays(&draft)

            case .owners:
                try editOwners(&draft, keys: keys)

            case .rewardAccount:
                let key = try promptStakeKey(
                    title: "Reward Account",
                    question: "Select the stake key that receives the pool rewards:",
                    keys: keys
                )
                draft.rewardAccount = try key.rewardAccount(network: network)

            case .vrfKey:
                let path = try filePathPrompt(
                    title: "VRF Verification Key",
                    question: "Select the new VRF verification key:",
                    description: "Changing the VRF key requires the node to run with the matching VRF signing key.",
                    fileMatches: { $0.hasSuffix(".vrf.vkey") || $0.hasSuffix(".json") }
                )
                draft.vrfKeyHash = try VRFVerificationKey.load(from: FileUtils.absolutePath(path).string).hash()

            case .metadata:
                try await editMetadata(&draft)
        }
    }
}

private func editRelays(_ draft: inout PoolParamsDraft) throws {
    enum Action: String, CaseIterable, CustomStringConvertible {
        case add = "Add a relay"
        case remove = "Remove relays"
        case done = "Done"
        var description: String { rawValue }
    }

    while true {
        let current = draft.relays.isEmpty ? "none" : draft.relays.map(\.displayString).joined(separator: ", ")
        let options = draft.relays.isEmpty ? [Action.add, .done] : Action.allCases
        let action = noora.singleChoicePrompt(
            title: "Relays",
            question: "Current relays: \(current)",
            options: options
        )
        switch action {
            case .add:
                draft.relays.append(promptPoolRelay())
            case .remove:
                let removed = noora.multipleChoicePrompt(
                    title: "Remove Relays",
                    question: "Select the relays to remove:",
                    options: draft.relays.map(\.displayString)
                )
                draft.relays.removeAll { removed.contains($0.displayString) }
            case .done:
                return
        }
    }
}

private func editOwners(_ draft: inout PoolParamsDraft, keys: PoolKeyFileMatcher) throws {
    enum Action: String, CaseIterable, CustomStringConvertible {
        case add = "Add an owner"
        case remove = "Remove owners"
        case done = "Done"
        var description: String { rawValue }
    }

    func label(_ hash: VerificationKeyHash) -> String {
        let name = keys.stakeVkey(for: hash).flatMap(PoolKeyFileMatcher.keyName)
        return name.map { "\($0) (\(hash.payload.toHex))" } ?? hash.payload.toHex
    }

    while true {
        let action = noora.singleChoicePrompt(
            title: "Owners",
            question: "Current owners: \(draft.owners.map(label).joined(separator: ", "))",
            options: draft.owners.count > 1 ? Action.allCases : [.add, .done],
            description: "Every owner must sign the registration transaction with their stake signing key."
        )
        switch action {
            case .add:
                let key = try promptStakeKey(
                    title: "Pool Owner",
                    question: "Select the new owner's stake key:",
                    keys: keys
                )
                if !draft.owners.contains(where: { $0.payload == key.keyHash.payload }) {
                    draft.owners.append(key.keyHash)
                }
            case .remove:
                let removed = noora.multipleChoicePrompt(
                    title: "Remove Owners",
                    question: "Select the owners to remove:",
                    options: draft.owners.map(label),
                    maxLimit: .limited(count: draft.owners.count - 1, errorMessage: "A pool needs at least one owner.")
                )
                draft.owners.removeAll { removed.contains(label($0)) }
            case .done:
                return
        }
    }
}

/// Prompt for a stake key: a stake verification key file, a stake address, or a key hash.
func promptStakeKey(title: String, question: String, keys: PoolKeyFileMatcher) throws -> StakeKeyArgument {
    let fromFile = "Stake verification key file"
    let enterManually = "Enter a stake address or key hash"
    let choice = noora.singleChoicePrompt(
        title: TerminalText(stringLiteral: title),
        question: TerminalText(stringLiteral: question),
        options: [fromFile, enterManually]
    )

    if choice == fromFile {
        let path = try filePathPrompt(
            title: TerminalText(stringLiteral: title),
            question: "Select the stake verification key file:",
            description: "Stake verification keys (.stake.vkey, .json) are suggested.",
            fileMatches: { $0.hasSuffix(".stake.vkey") || $0.hasSuffix(".json") },
            validationRules: [StakeVkeyFileValidationRule(error: "Not a stake verification key file.")]
        )
        let absolute = FileUtils.absolutePath(path)
        guard let hash = PoolKeyFileMatcher.stakeKeyHash(ofVkeyFile: absolute) else {
            throw SwiftCardanoMultitoolError.valueError("Could not read the stake verification key \(path.string).")
        }
        return StakeKeyArgument(keyHash: hash, vkeyFile: absolute)
    }

    while true {
        let input = noora.textPrompt(
            title: TerminalText(stringLiteral: title),
            prompt: "Enter a stake address (stake1...) or 56-character stake key hash:",
            collapseOnAnswer: true,
            validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
        )
        if let key = StakeKeyArgument(argument: input) {
            return key
        }
        noora.warning(.alert("Not a key-based stake address, stake key hash, or stake verification key file."))
    }
}

private func editMetadata(_ draft: inout PoolParamsDraft) async throws {
    enum Action: String, CaseIterable, CustomStringConvertible {
        case content = "Edit name, ticker, description or homepage"
        case url = "Point to a different metadata URL"
        case remove = "Remove metadata"
        var description: String { rawValue }
    }

    let action = noora.singleChoicePrompt(
        title: "Metadata",
        question: "How would you like to change the pool metadata?",
        options: Action.allCases,
        description: "Content edits write a new <pool>.metadata.json that you must upload to the metadata URL before submitting."
    )

    switch action {
        case .content:
            let name = noora.textPrompt(
                title: "Pool Name",
                prompt: "Enter the pool display name (max 50 chars):",
                defaultValue: draft.metadataName,
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Name cannot be empty."),
                    LengthValidationRule(max: 50, error: "Name must be 50 chars or less.")
                ]
            )
            let ticker = noora.textPrompt(
                title: "Pool Ticker",
                prompt: "Enter the pool ticker (3-5 uppercase letters or digits):",
                defaultValue: draft.metadataTicker,
                collapseOnAnswer: true,
                validationRules: [LengthValidationRule(min: 3, max: 5, error: "Ticker must be 3-5 characters.")]
            ).uppercased()
            let description = noora.textPrompt(
                title: "Pool Description",
                prompt: "Enter the pool description (max 255 chars):",
                defaultValue: draft.metadataDescription,
                collapseOnAnswer: true,
                validationRules: [LengthValidationRule(max: 255, error: "Description must be 255 chars or less.")]
            )
            let homepage = noora.textPrompt(
                title: "Pool Homepage",
                prompt: "Enter the pool homepage URL:",
                defaultValue: draft.metadataHomepage,
                collapseOnAnswer: true,
                validationRules: [LengthValidationRule(max: 64, error: "Homepage must be 64 chars or less.")]
            )
            let url = noora.textPrompt(
                title: "Metadata URL",
                prompt: "Enter the URL where the new metadata.json will be hosted:",
                description: "Keep the current URL if you will replace the file there.",
                defaultValue: draft.metadataUrl,
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Metadata URL cannot be empty."),
                    LengthValidationRule(max: 64, error: "Metadata URL must be 64 chars or less.")
                ]
            )
            draft.metadataName = name
            draft.metadataTicker = ticker
            draft.metadataDescription = description
            draft.metadataHomepage = homepage
            draft.metadataUrl = url
            draft.metadataContentEdited = true
            // The hash is computed from the generated metadata.json before building the certificate.

        case .url:
            let url = noora.textPrompt(
                title: "Metadata URL",
                prompt: "Enter the new metadata URL:",
                defaultValue: draft.metadataUrl,
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Metadata URL cannot be empty."),
                    LengthValidationRule(max: 64, error: "Metadata URL must be 64 chars or less.")
                ]
            )
            draft.metadataUrl = url
            draft.metadataContentEdited = false

            let download = noora.yesOrNoChoicePrompt(
                title: "Metadata Hash",
                question: "Download the file at this URL to compute its hash?",
                defaultAnswer: true,
                description: "Choose no to enter the hash yourself (e.g. the file is not uploaded yet)."
            )
            if download {
                do {
                    draft.metadataHash = try await noora.progressStep(
                        message: "Downloading \(url)...",
                        successMessage: "Computed the metadata hash.",
                        errorMessage: "Could not download the metadata file.",
                        showSpinner: true
                    ) { _ in try await downloadPoolMetadataHash(url: url) }
                    return
                } catch {
                    noora.warning(.alert("\(error.localizedDescription)", takeaway: "Enter the hash manually instead."))
                }
            }
            draft.metadataHash = noora.textPrompt(
                title: "Metadata Hash",
                prompt: "Enter the metadata hash (64 hex characters):",
                collapseOnAnswer: true,
                validationRules: [LengthValidationRule(min: 64, max: 64, error: "The hash must be 64 hex characters.")]
            ).lowercased()

        case .remove:
            draft.metadataUrl = nil
            draft.metadataHash = nil
            draft.metadataName = nil
            draft.metadataTicker = nil
            draft.metadataDescription = nil
            draft.metadataHomepage = nil
            draft.metadataContentEdited = false
    }
}

/// Accepts a readable stake verification key file.
private struct StakeVkeyFileValidationRule: ValidatableRule {
    let error: ValidatableError

    func validate(input: String) -> Bool {
        PoolKeyFileMatcher.stakeKeyHash(ofVkeyFile: FileUtils.absolutePath(FilePath(input))) != nil
    }
}
