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
        certificateOptions.outFile = try optionalFilePathPrompt(
            title: "Output File",
            question: "Enter the output file path for the certificate. (leave blank for default):",
            mustExist: false
        )
        
        certificateOptions.generateTransaction = noora.yesOrNoChoicePrompt(
            title: "Generate Transaction",
            question: "Generate a transaction to submit the certificate?",
            defaultAnswer: false,
            description: "Select 'yes' to generate a transaction that includes the certificate. Select 'no' to only generate the certificate file."
        )
    }
}
