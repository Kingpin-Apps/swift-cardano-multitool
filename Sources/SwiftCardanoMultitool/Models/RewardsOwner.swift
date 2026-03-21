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
    
    private enum CodingKeys: String, CodingKey {
        case name
        case stakeVkey = "stake_vkey"
        case stakeSkey = "stake_skey"
    }
    
    public init(
        name: String? = nil,
        stakeVkey: FilePath? = nil,
        stakeSkey: FilePath? = nil
    ) {
        self.name = name
        
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        self.stakeVkey = stakeVkey ?? (name.map { cwd.appending("\($0).stake.vkey") })
        self.stakeSkey = stakeSkey ?? (name.map { cwd.appending("\($0).stake.skey") })
    }
}
