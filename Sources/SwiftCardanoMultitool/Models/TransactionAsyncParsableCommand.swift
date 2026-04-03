import SystemPackage
import ArgumentParser
import SwiftCardanoCore


protocol TransactionAsyncParsableCommand: AsyncParsableCommand {
    var txFile: FilePath? { get set }
    var cborHex: String? { get set }
}


extension TransactionAsyncParsableCommand {
    
    // MARK: - Private Helpers
    
    func resolveCborHex() throws -> String {
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
    
    func resolveTransaction() throws -> Transaction {
        if let hex = cborHex {
            return try Transaction.fromCBORHex(hex)
        }
        if let file = txFile {
            let tx = try Transaction.load(from: file.string)
            return tx
        }
        noora.error("Transaction input is required.")
        throw ExitCode.validationFailure
    }
    
}
