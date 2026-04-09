import Foundation
import SystemPackage
import ArgumentParser
import SwiftCardanoCore


protocol TransactionAsyncParsableCommand: AsyncParsableCommand {
    var txFile: FilePath? { get set }
    var cborHex: String? { get set }
}


extension TransactionAsyncParsableCommand {
    
    var effectiveTxFile: FilePath {
        get async throws {
            let tempTxFilePath: String? = nil
            if let file = txFile {
                return file
            } else {
                let tempFilePath =  FilePath(
                    FileManager
                        .default
                        .temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("tx")
                        .path
                )
                
                defer {
                    if let path = tempTxFilePath {
                        try? FileManager.default.removeItem(atPath: path)
                    }
                }
                
                let tx = try resolveTransaction()
                try await FileUtils.dumpLockedFile(tempFilePath, data: try tx.toTextEnvelope()!)
                return tempFilePath
            }
        }
    }
    
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
