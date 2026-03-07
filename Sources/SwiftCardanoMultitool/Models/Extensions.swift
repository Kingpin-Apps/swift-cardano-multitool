import Foundation
import SystemPackage
import ArgumentParser
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoUtils
import Configuration
import Noora
import SwiftMnemonic

extension Noora {
    func secureTextPrompt(
        title: TerminalText? = nil,
        prompt: TerminalText,
        description: TerminalText? = nil
    ) -> String? {
        // Display Noora-styled prompt elements
        if let title = title {
            print(self.format(title))
        }
        print(self.format(prompt))
        if let description = description {
            print(self.format(description))
        }
        
        // Use secure input
        var buf = [CChar](repeating: 0, count: 8192)
        guard let password = readpassphrase("", &buf, buf.count, 0),
              let passwordStr = String(validatingCString: password) else {
            return nil
        }
        
        return passwordStr
    }
}

extension MultiAsset: @retroactive _SendableMetatype {
    public func toAssetsOutString() -> String {
        var assetsOutString = ""
        
        for (scriptHash, assetsUnderPolicy) in self.data {
            // Convert policyId (scriptHash) to hex
            let policyIdHex = scriptHash.payload.hexEncodedString()
            
            // For each asset under that policy
            for (assetName, amount) in assetsUnderPolicy.data {
                // Convert asset name (bytes) to hex
                let assetNameHex = assetName.payload.hexEncodedString()
                
                // The asset identifier (policyId + "." + assetNameHex) or "+" if you prefer
                let assetHashName = "\(policyIdHex).\(assetNameHex)"
                
                // Append in the format: +<amount> <policyId.assetNameHex>
                assetsOutString += "+\(amount) \(assetHashName)"
            }
        }
        
        return assetsOutString
    }
}
