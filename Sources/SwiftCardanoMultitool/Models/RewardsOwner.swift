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
    
    private enum CodingKeys: String, CodingKey {
        case name
        case stakeVkey = "stake_vkey"
        case stakeSkey = "stake_skey"
        case rewardAccount = "reward_account"
    }
    
    public init(
        name: String? = nil,
        stakeVkey: FilePath? = nil,
        stakeSkey: FilePath? = nil,
        rewardAccount: String? = nil
    ) {
        self.name = name
        self.rewardAccount = rewardAccount
        
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        self.stakeVkey = stakeVkey ?? (name.map { cwd.appending("\($0).stake.vkey") })
        self.stakeSkey = stakeSkey ?? (name.map { cwd.appending("\($0).stake.skey") })
    }
}
