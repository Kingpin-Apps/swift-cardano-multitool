import Foundation
import ArgumentParser
import SwiftCardanoChain
import SystemPackage

/// A struct that represents payment address information and conforms to `ExpressibleByArgument`.
/// It can be initialized from various input formats including AdaHandle, Bech32 address, or file paths.
public struct PaymentAddressInfo: ExpressibleByArgument {
    var info: AddressInfo
    // MARK: ExpressibleByArgument

    public init (info: AddressInfo) {
        self.info = info
    }
    
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("$") {
            // Case 1: $adahandle
            guard let info = try? AddressInfo(fromAdaHandle: trimmed) else {
                return nil
            }
            self.init(info: info)
        }
        else if trimmed.hasPrefix("addr") {
            // Case 2: Bech32 address (starts with addr or stake)
            guard let info = try? AddressInfo(fromAddressString: trimmed) else {
                return nil
            }
            self.init(info: info)
        } else {
            // Case 3: File path or name (e.g., owner.payment, owner, or /full/path/to/file.addr)
            let addressFileName = trimmed
            let fileManager = FileManager.default

            // Try the path as given (handles absolute and cwd-relative paths)
            if fileManager.fileExists(atPath: addressFileName) {
                guard let info = try? AddressInfo(fromFile: FilePath(addressFileName)) else {
                    return nil
                }
                self.init(info: info)
                return
            }

            // Try common file name variations in the current directory
            let variations = [
                "\(addressFileName).payment.addr",
                "\(addressFileName).addr"
            ]

            let foundFiles = variations.filter { fileManager.fileExists(atPath: $0) }

            guard foundFiles.count == 1, let firstFile = foundFiles.first else {
                return nil
            }

            guard let info = try? AddressInfo(fromFile: FilePath(firstFile)) else {
                return nil
            }
            self.init(info: info)
        }
    }
    
}
