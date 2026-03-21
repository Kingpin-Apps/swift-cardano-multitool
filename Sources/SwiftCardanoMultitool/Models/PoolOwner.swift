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
    
    private enum CodingKeys: String, CodingKey {
        case name
        case witness
        case stakeVkey = "stake_vkey"
        case stakeSkey = "stake_skey"
        case delegationCertificate = "delegation_certificate"
    }
    
    public init(
        name: String? = nil,
        witness: WitnessType = .local,
        stakeVkey: FilePath? = nil,
        stakeSkey: FilePath? = nil,
        delegationCertificate: FilePath? = nil
    ) {
        self.name = name
        self.witness = witness
        
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        self.stakeVkey = stakeVkey ?? (name.map { cwd.appending("\($0).stake.vkey") })
        self.stakeSkey = stakeSkey ?? (name.map { cwd.appending("\($0).stake.skey") })
        self.delegationCertificate = delegationCertificate
    }
}
