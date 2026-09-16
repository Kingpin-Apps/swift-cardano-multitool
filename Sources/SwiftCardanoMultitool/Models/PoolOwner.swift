import Foundation
import SystemPackage
import SwiftCardanoUtils

/// Pool Owner model (extends Delegator)
public struct PoolOwner: Codable, Sendable {
    public var name: String?
    public var witness: WitnessType
    
    @FilePathCodable
    public var stakeVkey: FilePath?
    
    @FilePathCodable
    public var stakeSkey: FilePath?
    
    @FilePathCodable
    public var delegationCertificate: FilePath?

    /// The owner's stake key hash (hex), e.g. as registered on-chain. Used when
    /// the stake verification key file is not available.
    public var stakeKeyHash: String?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case witness
        case stakeVkey = "stake_vkey"
        case stakeSkey = "stake_skey"
        case delegationCertificate = "delegation_certificate"
        case stakeKeyHash = "stake_key_hash"
    }
    
    public init(
        name: String? = nil,
        witness: WitnessType = .local,
        stakeVkey: FilePath? = nil,
        stakeSkey: FilePath? = nil,
        delegationCertificate: FilePath? = nil,
        stakeKeyHash: String? = nil
    ) {
        self.name = name
        self.witness = witness
        self.stakeKeyHash = stakeKeyHash
        
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        self.stakeVkey = stakeVkey ?? (name.map { cwd.appending("\($0).stake.vkey") })
        self.stakeSkey = stakeSkey ?? (name.map { cwd.appending("\($0).stake.skey") })
        self.delegationCertificate = delegationCertificate
    }
}
