import Foundation
import Testing
import SystemPackage
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("MintBurnUtils")
struct MintBurnUtilsTests {

    // MARK: - MintAction.signedAmount

    @Test("MintAction.mint produces a positive signed amount")
    func mintSignedPositive() {
        #expect(MintAction.mint.signedAmount(1) == 1)
        #expect(MintAction.mint.signedAmount(1_000_000) == 1_000_000)
    }

    @Test("MintAction.burn produces a negative signed amount")
    func burnSignedNegative() {
        #expect(MintAction.burn.signedAmount(1) == -1)
        #expect(MintAction.burn.signedAmount(1_000_000) == -1_000_000)
    }

    @Test("MintAction past-tense and file-suffix labels match expectations")
    func actionLabels() {
        #expect(MintAction.mint.pastTense == "minted")
        #expect(MintAction.burn.pastTense == "burned")
        #expect(MintAction.mint.fileSuffix == "mint")
        #expect(MintAction.burn.fileSuffix == "burn")
    }

    // MARK: - splitPolicyAssetPositional

    @Test("Plain PolicyName.AssetName splits on the dot")
    func splitPlain() {
        let r = splitPolicyAssetPositional("foo.MYTOK")
        #expect(r.policyName == "foo")
        #expect(r.assetName == "MYTOK")
    }

    @Test("PolicyName with hex asset is left intact")
    func splitWithHexBraces() {
        let r = splitPolicyAssetPositional("foo.{deadbeef}")
        #expect(r.policyName == "foo")
        #expect(r.assetName == "{deadbeef}")
    }

    @Test("Bare PolicyName parses to the default (empty) asset")
    func splitBare() {
        let r = splitPolicyAssetPositional("foo")
        #expect(r.policyName == "foo")
        #expect(r.assetName == "")
    }

    @Test("Splits on the FIRST unbraced dot only")
    func splitFirstDotOnly() {
        // Asset name "bar.baz" — the script's `bash` convention treats everything after
        // the first '.' as the asset name verbatim.
        let r = splitPolicyAssetPositional("foo.bar.baz")
        #expect(r.policyName == "foo")
        #expect(r.assetName == "bar.baz")
    }

    @Test("Trims whitespace from the input")
    func splitTrimsWhitespace() {
        let r = splitPolicyAssetPositional("  foo.MYTOK  ")
        #expect(r.policyName == "foo")
        #expect(r.assetName == "MYTOK")
    }

    // MARK: - buildMintMultiAsset

    @Test("buildMintMultiAsset stores a positive quantity for mint")
    func buildMintPositive() throws {
        let policy = String(repeating: "a", count: 56)
        let asset = "4d59544f4b" // "MYTOK"
        let ma = try buildMintMultiAsset(
            policyIdHex: policy,
            assetNameHex: asset,
            signedQty: 1_000
        )
        let scriptHash = ScriptHash(payload: policy.hexStringToData)
        let assetName = try AssetName(payload: asset.hexStringToData)
        #expect(ma.data[scriptHash]?.data[assetName] == 1_000)
    }

    @Test("buildMintMultiAsset preserves a negative quantity for burn")
    func buildBurnNegative() throws {
        let policy = String(repeating: "a", count: 56)
        let asset = "4d59544f4b"
        let ma = try buildMintMultiAsset(
            policyIdHex: policy,
            assetNameHex: asset,
            signedQty: -500
        )
        let scriptHash = ScriptHash(payload: policy.hexStringToData)
        let assetName = try AssetName(payload: asset.hexStringToData)
        #expect(ma.data[scriptHash]?.data[assetName] == -500)
    }

    @Test("buildMintMultiAsset rejects a non-56-char policy ID")
    func buildRejectsShortPolicy() {
        let policy = String(repeating: "a", count: 55) // too short
        #expect(throws: (any Error).self) {
            _ = try buildMintMultiAsset(
                policyIdHex: policy,
                assetNameHex: "",
                signedQty: 1
            )
        }
    }

    @Test("buildMintMultiAsset accepts an empty asset name (default asset)")
    func buildEmptyAssetName() throws {
        let policy = String(repeating: "b", count: 56)
        let ma = try buildMintMultiAsset(
            policyIdHex: policy,
            assetNameHex: "",
            signedQty: 1
        )
        let scriptHash = ScriptHash(payload: policy.hexStringToData)
        let defaultAsset = try AssetName(payload: Data())
        #expect(ma.data[scriptHash]?.data[defaultAsset] == 1)
    }

    // MARK: - computeMintBurnTTL

    @Test("Unlimited policy → tip + extra")
    func ttlUnlimited() throws {
        let policy = LoadedMintBurnPolicy(
            name: "p",
            policyId: String(repeating: "a", count: 56),
            nativeScript: .invalidBefore(BeforeScript(slot: 0)), // ignored — only validBeforeSlot drives logic
            signingKeyPath: FilePath("/tmp/p.policy.skey"),
            vkeyPath: FilePath("/tmp/p.policy.vkey"),
            isHardwareWallet: false,
            validBeforeSlot: nil
        )
        let ttl = try computeMintBurnTTL(
            tipSlot: 1_000,
            policy: policy,
            extraSlots: 500,
            action: .mint
        )
        #expect(ttl == 1_500)
    }

    @Test("Time-locked policy clamps TTL to validBeforeSlot - 1 when smaller")
    func ttlTimeLockedClamps() throws {
        let policy = LoadedMintBurnPolicy(
            name: "p",
            policyId: String(repeating: "a", count: 56),
            nativeScript: .invalidBefore(BeforeScript(slot: 0)),
            signingKeyPath: FilePath("/tmp/p.policy.skey"),
            vkeyPath: FilePath("/tmp/p.policy.vkey"),
            isHardwareWallet: false,
            validBeforeSlot: 1_100
        )
        let ttl = try computeMintBurnTTL(
            tipSlot: 1_000,
            policy: policy,
            extraSlots: 500,
            action: .mint
        )
        // tip + extra would be 1500; policy expires at 1100; clamp to 1099.
        #expect(ttl == 1_099)
    }

    @Test("Time-locked policy still in the future returns tip + extra when smaller than the clamp")
    func ttlTimeLockedPicksTipPlusExtraWhenSmaller() throws {
        let policy = LoadedMintBurnPolicy(
            name: "p",
            policyId: String(repeating: "a", count: 56),
            nativeScript: .invalidBefore(BeforeScript(slot: 0)),
            signingKeyPath: FilePath("/tmp/p.policy.skey"),
            vkeyPath: FilePath("/tmp/p.policy.vkey"),
            isHardwareWallet: false,
            validBeforeSlot: 100_000
        )
        let ttl = try computeMintBurnTTL(
            tipSlot: 1_000,
            policy: policy,
            extraSlots: 500,
            action: .mint
        )
        #expect(ttl == 1_500)
    }

    @Test("Expired time-locked policy throws")
    func ttlExpiredThrows() {
        let policy = LoadedMintBurnPolicy(
            name: "p",
            policyId: String(repeating: "a", count: 56),
            nativeScript: .invalidBefore(BeforeScript(slot: 0)),
            signingKeyPath: FilePath("/tmp/p.policy.skey"),
            vkeyPath: FilePath("/tmp/p.policy.vkey"),
            isHardwareWallet: false,
            validBeforeSlot: 500
        )
        #expect(throws: (any Error).self) {
            _ = try computeMintBurnTTL(
                tipSlot: 1_000,
                policy: policy,
                extraSlots: 100,
                action: .burn
            )
        }
    }

    // MARK: - sidecar round-trip

    @Test("updateMintBurnSidecar creates a new file on first call and bumps it on subsequent calls")
    func sidecarCreateThenBump() throws {
        let tmp = FilePath(
            FileManager.default.temporaryDirectory
                .appendingPathComponent("scm-mintburn-test-\(UUID().uuidString).asset").path
        )
        defer { try? FileManager.default.removeItem(atPath: tmp.string) }

        let policy = LoadedMintBurnPolicy(
            name: "testmint",
            policyId: String(repeating: "a", count: 56),
            nativeScript: .invalidBefore(BeforeScript(slot: 0)),
            signingKeyPath: FilePath("/tmp/p.policy.skey"),
            vkeyPath: FilePath("/tmp/p.policy.vkey"),
            isHardwareWallet: false,
            validBeforeSlot: nil
        )

        try updateMintBurnSidecar(
            at: tmp,
            policy: policy,
            assetDisplay: "MYTOK",
            assetNameHex: "4d59544f4b",
            action: .mint,
            amount: 1_000
        )

        let first = loadAssetSidecar(at: tmp)
        #expect(first?.sequenceNumber == 0)
        #expect(first?.lastAction == "minted 1000 tokens")
        #expect(first?.policyID == policy.policyId)
        #expect(first?.hexname == "4d59544f4b")
        #expect(first?.subject.lowercased() == (policy.policyId + "4d59544f4b").lowercased())
        #expect(first?.policyValidBeforeSlot == "unlimited")

        try updateMintBurnSidecar(
            at: tmp,
            policy: policy,
            assetDisplay: "MYTOK",
            assetNameHex: "4d59544f4b",
            action: .burn,
            amount: 200
        )

        let second = loadAssetSidecar(at: tmp)
        #expect(second?.sequenceNumber == 1)
        #expect(second?.lastAction == "burned 200 tokens")
    }
}
