import Foundation
import SwiftCardanoCore
import SwiftCardanoChain
import ArgumentParser
import Noora
import SystemPackage

func getAddressBy(title: TerminalText? = nil) async throws -> GetAddressBy {
    return noora.singleChoicePrompt(
        title: title ?? "Payment Address",
        question: "Enter address files by:",
        description: "Do you want to enter the name of the address files or select them from the current working directory?.",
    )
}

func enterAddressBy(title: TerminalText? = nil) async throws -> EnterAddressBy {
    return noora.singleChoicePrompt(
        title: title ?? "Payment Address",
        question: "Enter address by:",
        description: "Do you want to enter the address or AdaHandle directly or provide a file containing the address?.",
    )
}

func enterDRepBy(title: TerminalText? = nil) async throws -> EnterDRepBy {
    return noora.singleChoicePrompt(
        title: title ?? "Enter DRep",
        question: "Enter DRep by:",
        description: """
            Accepted formats:
            \n  • Bech32: drep1... (56 chars) or drep_script1... (63 chars)
            \n  • Hex: 56-character hex string (with or without 0x prefix)
            \n  • File: path to .drep.vkey file
            \n  • Special: 'always-abstain' or 'always-no-confidence'
            \n  • Aliases: 'abstain', 'noc', 'no-confidence'
            """,
    )
}

func getStakeAddress(title: TerminalText? = nil) async throws -> StakeAddressInfo {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let stakingFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".stake.addr") }
    
    if stakingFiles.isEmpty {
        noora.error(.alert(
            "No stake address files found in current directory.",
            takeaways: [
                "Please create a stake address first using the 'generate payment-and-stake-address' command."
            ]
        ))
        throw ExitCode.failure
    }
    
    let stakeAddressFileName = noora.singleChoicePrompt(
        title: title ?? "Stake Address",
        question: "Select the stake address file:",
        options: stakingFiles,
        description: "Available .stake.addr files in current directory"
    )
    
    let info = try AddressInfo(
        fromFile: cwd.appending(stakeAddressFileName),
        name: stakeAddressFileName.replacingOccurrences(of: ".stake.addr", with: "")
    )
    return StakeAddressInfo(info: info)
}

func getDestinationAddress(title: TerminalText? = nil) async throws -> PaymentAddressInfo {
    let addressBy = try await enterAddressBy(title: title)
    
    let info: AddressInfo
    
    switch addressBy {
        case .address:
            let bech32 = noora.textPrompt(
                title: "Bech32 Address",
                prompt: "Enter the address in Bech32 format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Address cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let name = noora.textPrompt(
                title: "Address Name",
                prompt: "Enter a name for this address (for reference purposes):",
                collapseOnAnswer: true,
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let address = try Address.fromBech32(bech32)
            
            info = try AddressInfo(name: name, address: address)
        case .adahandle:
            let adaHandle = noora.textPrompt(
                title: "AdaHandle",
                prompt: "Enter the AdaHandle (e.g., 'alice.ada'):",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "AdaHandle cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let name = noora.textPrompt(
                title: "Address Name",
                prompt: "Enter a name for this address (for reference purposes):",
                collapseOnAnswer: true,
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            info = try AddressInfo(name: name, adaHandle: adaHandle)
        case .path:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let addressFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".payment.addr") }
            
            if addressFiles.isEmpty {
                noora.error(.alert(
                    "No payment address files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate payment-and-stake-address' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let addressFileName = noora.singleChoicePrompt(
                title: "Payment Address",
                question: "Select the address file:",
                options: addressFiles,
                description: "Available .addr files in current directory"
            )
            
            info = try AddressInfo(
                fromFile: cwd.appending(addressFileName),
                name: addressFileName.replacingOccurrences(of: ".addr", with: "")
            )
    }
        
    return PaymentAddressInfo(info: info)
}

func getFeePaymentAddress(title: TerminalText? = nil) async throws -> PaymentAddressInfo {
    let addressBy = try await getAddressBy(title: title)
    
    let info: AddressInfo
    
    switch addressBy {
        case .path:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let addressFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".payment.addr") }
            
            if addressFiles.isEmpty {
                noora.error(.alert(
                    "No payment address files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate payment-and-stake-address' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let addressFileName = noora.singleChoicePrompt(
                title: "Fee Payment Address",
                question: "Select the fee payment address file:",
                options: addressFiles,
                description: "Available .payment.addr files in current directory"
            )
            
            info = try AddressInfo(
                fromFile: cwd.appending(addressFileName),
                name: addressFileName.replacingOccurrences(of: ".payment.addr", with: "")
            )
        case .name:
            let addressName = noora.textPrompt(
                title: "Fee Payment Address Name",
                prompt: "Enter the name of the fee payment address (as used during its creation):",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Address name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let addressFilePath = cwd.appending("\(addressName).payment.addr")
            
            info = try AddressInfo(
                fromFile: addressFilePath,
                name: addressName
            )
    }
    
    return PaymentAddressInfo(info: info)
}


func getTransactionFilePath(title: TerminalText? = nil) async throws -> FilePath {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let transactionFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".tx") }
    
    if transactionFiles.isEmpty {
        noora.error(.alert(
            "No transaction files found in current directory.",
            takeaways: [
                "Please create a transaction first.",
                "Make sure you are in the correct directory containing the transaction file."
                
            ]
        ))
        throw ExitCode.failure
    }
    
    let transactionFileName = noora.singleChoicePrompt(
        title: title ?? "Transaction File",
        question: "Select the transaction file:",
        options: transactionFiles,
        description: "Available .tx files in current directory",
        collapseOnSelection: true,
        filterMode: .enabled
    )
    
    return FilePath(transactionFileName)
}


func getSigningKeyFilePath(title: TerminalText? = nil) async throws -> FilePath {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let signingKeyFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".skey") || $0.hasSuffix(".hwsfile") }
    
    if signingKeyFiles.isEmpty {
        noora.error(.alert(
            "No signing key files found in current directory.",
            takeaways: [
                "Please create a signing key first.",
                "Make sure you are in the correct directory containing the signing key file."
                
            ]
        ))
        throw ExitCode.failure
    }
    
    let signingKeyFileName = noora.singleChoicePrompt(
        title: title ?? "Signing Key File",
        question: "Select the signing key file:",
        options: signingKeyFiles,
        description: "Available `.skey` and `.hwsfile` files in current directory",
        collapseOnSelection: true,
        filterMode: .enabled
    )
    
    return FilePath(signingKeyFileName)
}

func getDRep(title: TerminalText? = nil) async throws -> DRep {
    let enterDRepBy = try await enterDRepBy(title: title)
    
    switch enterDRepBy {
        case .path:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let drepFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".drep.id") }
            
            if drepFiles.isEmpty {
                noora.error(.alert(
                    "No DRep ID files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'certificate drep' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let drepFileName = noora.singleChoicePrompt(
                title: "DRep ID",
                question: "Select the DRep ID file:",
                options: drepFiles,
                description: "Available .drep.id files in current directory"
            )
            
            return try DRep.load(from: cwd.appending(drepFileName).string)
        case .hex:
            let drepId = noora.textPrompt(
                title: "DRep ID",
                prompt: "Enter the DRep ID in hexadecimal format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "DRep ID cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try DRep(from: drepId.hexStringToData)
        case .bech32:
            let drepId = noora.textPrompt(
                title: "DRep ID",
                prompt: "Enter the DRep ID in Bech32 format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "DRep ID cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle friendly aliases
            let normalizedRaw: String
            switch drepId.lowercased() {
                case "abstain":
                    normalizedRaw = "drep_always_abstain"
                case "noc", "no-confidence":
                    normalizedRaw = "drep_always_no_confidence"
                default:
                    normalizedRaw = drepId
            }
            
            return try DRep(from: normalizedRaw)
        case .vkey:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let drepFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".drep.vkey") }
            
            if drepFiles.isEmpty {
                noora.error(.alert(
                    "No DRep Verification Keys files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate drep' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let drepFileName = noora.singleChoicePrompt(
                title: "DRep ID",
                question: "Select the DRep Verification Key file:",
                options: drepFiles,
                description: "Available .drep.vkey files in current directory"
            )
            let drepVKey = try DRepVerificationKey.load(from: cwd.appending(drepFileName).string)
            return DRep(credential: .verificationKeyHash(try drepVKey.hash()))
        case .skey:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let drepFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".drep.skey") }
            
            if drepFiles.isEmpty {
                noora.error(.alert(
                    "No DRep Verification Keys files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate drep' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let drepFileName = noora.singleChoicePrompt(
                title: "DRep ID",
                question: "Select the DRep Signing Key file:",
                options: drepFiles,
                description: "Available .drep.skey files in current directory"
            )
            let drepSKey = try DRepSigningKey.load(
                from: cwd.appending(drepFileName).string
            )
            let drepVKey: DRepVerificationKey = try drepSKey.toVerificationKey()
            return DRep(credential: .verificationKeyHash(try drepVKey.hash()))
        case .mnemonics:
            throw SwiftCardanoMultitoolError.notImplemented
    }
}
