import Foundation
import SystemPackage
import SwiftCardanoUtils

/// Witness file model class for transaction signing witnesses
public struct TransactionWitness: Codable, Sendable {
    public var name: String?
    public var witness: TextEnvelope?
    public var id: UUID
    public var dateCreated: Date
    public var dateSigned: Date?
    public var type: TransactionType?
    public var ttl: Int?
    public var txBody: TextEnvelope?
    public var signingName: String?
    
    @FilePathCodable
    public var signingVkey: FilePath?
    
    @FilePathCodable
    public var poolFile: FilePath?
    
    public var poolMetaTicker: String?
    public var signedWitness: TextEnvelope?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case witness
        case id
        case dateCreated = "date_created"
        case dateSigned = "date_signed"
        case type
        case ttl
        case txBody = "tx_body"
        case signingName = "signing_name"
        case signingVkey = "signing_vkey"
        case poolFile = "pool_file"
        case poolMetaTicker = "pool_meta_ticker"
        case signedWitness = "signed_witness"
    }
    
    public init(
        name: String? = nil,
        witness: TextEnvelope? = nil,
        id: UUID = UUID(),
        dateCreated: Date = Date(),
        dateSigned: Date? = nil,
        type: TransactionType? = nil,
        ttl: Int? = nil,
        txBody: TextEnvelope? = nil,
        signingName: String? = nil,
        signingVkey: FilePath? = nil,
        poolFile: FilePath? = nil,
        poolMetaTicker: String? = nil,
        signedWitness: TextEnvelope? = nil
    ) {
        self.name = name
        self.witness = witness
        self.id = id
        self.dateCreated = dateCreated
        self.dateSigned = dateSigned
        self.type = type
        self.ttl = ttl
        self.txBody = txBody
        self.signingName = signingName
        self.signingVkey = signingVkey
        self.poolFile = poolFile
        self.poolMetaTicker = poolMetaTicker
        self.signedWitness = signedWitness
    }
}
