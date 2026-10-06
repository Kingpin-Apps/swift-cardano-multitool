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

/// Suffixes that mark a file as a transaction, longest first.
private let transactionFileSuffixes = [".unwitnessed.tx", ".signed.tx", ".raw.tx", ".tx", ".unwitnessed", ".signed", ".raw", ".json"]

/// The name of a transaction file without its transaction suffix, used to name the
/// files made from it: `qwe1.unwitnessed.tx`, `qwe1.signed.tx` and `qwe1.tx` all give `qwe1`.
func transactionBaseName(_ path: FilePath) -> String {
    let name = path.lastComponent?.string ?? path.string
    for suffix in transactionFileSuffixes where name.hasSuffix(suffix) && name.count > suffix.count {
        return String(name.dropLast(suffix.count))
    }
    return name
}

/// The role a signing key plays, from its file name: `qwe1.node.skey` → `node`,
/// `owner.payment.hwsfile` → `payment`, `payment.skey` → `payment`.
func signingKeyRole(_ path: FilePath) -> String {
    let stem = path.stem ?? path.lastComponent?.string ?? "key"
    return stem.split(separator: ".").last.map(String.init) ?? stem
}

