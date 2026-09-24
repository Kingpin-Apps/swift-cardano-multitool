import Foundation
import SystemPackage
import SwiftCardanoUtils

/// Rewards Owner model for stake pool rewards destination
public struct RewardsOwner: Codable, Sendable {
    public var name: String?
    
    @FilePathCodable
    public var stakeVkey: FilePath?
    
    @FilePathCodable
    public var stakeSkey: FilePath?

    /// The reward account (hex of the full reward address bytes), e.g. as
    /// registered on-chain. Used when the stake verification key file is not available.
    public var rewardAccount: String?

    /// The rewards stake key hash (hex). Used with the network to build the reward
    /// account when neither the stake verification key file nor reward_account is available.
    public var stakeKeyHash: String?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case stakeVkey = "stake_vkey"
        case stakeSkey = "stake_skey"
        case rewardAccount = "reward_account"
        case stakeKeyHash = "stake_key_hash"
    }
    
    public init(
        name: String? = nil,
        stakeVkey: FilePath? = nil,
        stakeSkey: FilePath? = nil,
        rewardAccount: String? = nil,
        stakeKeyHash: String? = nil
    ) {
        self.name = name
        self.rewardAccount = rewardAccount
        self.stakeKeyHash = stakeKeyHash
        
        self.stakeVkey = stakeVkey ?? (name.map { FileUtils.absolutePath("\($0).stake.vkey") })
        self.stakeSkey = stakeSkey ?? (name.map { FileUtils.absolutePath("\($0).stake.skey") })
    }
}
