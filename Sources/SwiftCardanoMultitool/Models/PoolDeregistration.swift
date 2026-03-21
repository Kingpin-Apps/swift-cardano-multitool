import Foundation
import SystemPackage
import SwiftCardanoUtils

/// Deregistration model for stake pool deregistration information
public struct PoolDeregistration: Codable, Sendable {
    public var submitted: Date?
    public var certCreated: Date?
    
    @FilePathCodable
    public var certificate: FilePath?
    
    public var epoch: Int?
    public var proof: String?
    public var payeeName: String?
    public var payeeAddress: String?
    
    @FilePathCodable
    public var payeeSkey: FilePath?
    
    @FilePathCodable
    public var payeeHwsFile: FilePath?
    
    private enum CodingKeys: String, CodingKey {
        case submitted
        case certCreated = "cert_created"
        case certificate
        case epoch
        case proof
        case payeeName = "payee_name"
        case payeeAddress = "payee_address"
        case payeeSkey = "payee_skey"
        case payeeHwsFile = "payee_hws_file"
    }
    
    public init(
        submitted: Date? = nil,
        certCreated: Date? = nil,
        certificate: FilePath? = nil,
        epoch: Int? = nil,
        proof: String? = nil,
        payeeName: String? = nil,
        payeeAddress: String? = nil,
        payeeSkey: FilePath? = nil,
        payeeHwsFile: FilePath? = nil
    ) {
        self.submitted = submitted
        self.certCreated = certCreated
        self.certificate = certificate
        self.epoch = epoch
        self.proof = proof
        self.payeeName = payeeName
        self.payeeAddress = payeeAddress
        self.payeeSkey = payeeSkey
        self.payeeHwsFile = payeeHwsFile
    }
}
