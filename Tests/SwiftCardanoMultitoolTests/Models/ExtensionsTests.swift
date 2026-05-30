import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("MultiAsset.toAssetsOutString")
struct MultiAssetExtensionTests {

    @Test("empty MultiAsset produces an empty string")
    func emptyMultiAsset() {
        let ma = MultiAsset([:])
        #expect(ma.toAssetsOutString() == "")
    }

    @Test("single policy and asset render as '+<amount> <policyHex>.<assetNameHex>'")
    func singleAssetFormat() throws {
        // 28-byte policy id (56 hex chars) of all 0xab bytes.
        let policyHex = String(repeating: "ab", count: 28)
        // AssetName(from:) treats "MyToken" as plain UTF-8 since it's not valid hex.
        // UTF-8 of "MyToken" is 4d 79 54 6f 6b 65 6e.
        let assetNameHex = "4d79546f6b656e"
        let amount: Int64 = 100

        let ma = try MultiAsset(from: [policyHex: ["MyToken": amount]])
        #expect(ma.toAssetsOutString() == "+\(amount) \(policyHex).\(assetNameHex)")
    }

    @Test("multiple policies each appear as their own +<amount> token")
    func multipleAssetsAllAppear() throws {
        let policyA = String(repeating: "11", count: 28)
        let policyB = String(repeating: "22", count: 28)
        // "Apple" → 4170706c65, "Banana" → 42616e616e61
        let ma = try MultiAsset(from: [
            policyA: ["Apple": 5],
            policyB: ["Banana": 7]
        ])
        let out = ma.toAssetsOutString()
        // Iteration order over the underlying dictionary is unspecified, so assert
        // each expected token substring is present rather than the full string.
        #expect(out.contains("+5 \(policyA).4170706c65"))
        #expect(out.contains("+7 \(policyB).42616e616e61"))
    }

    @Test("amounts above Int32.max are preserved")
    func handlesLargeAmounts() throws {
        let policyHex = String(repeating: "cd", count: 28)
        let big: Int64 = 9_999_999_999
        let ma = try MultiAsset(from: [policyHex: ["Big": big]])
        #expect(ma.toAssetsOutString().contains("+\(big) "))
    }
}
