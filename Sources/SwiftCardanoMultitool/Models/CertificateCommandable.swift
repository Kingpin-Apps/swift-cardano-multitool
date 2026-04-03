import ArgumentParser
import Foundation
import SystemPackage
import Noora

protocol CertificateCommandable: TransactionSendable {
    var certificateOptions: SharedCertificateOptions { get set }
}


extension CertificateCommandable {
    
    // MARK: - Wizard
    
    mutating func wizardForCertificate() async throws {
        let outputFile = noora.textPrompt(
            title: "Output File",
            prompt: "Enter the output file path for the certificate. (leave blank for default):",
            collapseOnAnswer: true
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if outputFile.isEmpty {
            certificateOptions.outFile = nil
        } else {
            certificateOptions.outFile = FilePath(outputFile)
        }
        
        certificateOptions.generateTransaction = noora.yesOrNoChoicePrompt(
            title: "Generate Transaction",
            question: "Generate a transaction to submit the certificate?",
            defaultAnswer: false,
            description: "Select 'yes' to generate a transaction that includes the certificate. Select 'no' to only generate the certificate file."
        )
    }
}
