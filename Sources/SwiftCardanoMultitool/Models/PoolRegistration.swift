import Foundation
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

/// Registration model for stake pool registration information
public struct PoolRegistration: Codable, Sendable {
    
    public var witness: RegistrationWitness?
    
    public var certCreated: Date?
    
    @FilePathCodable
    public var certificate: FilePath?
    
    public var protectionKey: String?
    public var epoch: Int?
    public var submitted: Date?
    public var submittedStatus: String?
    public var proof: String?
    
    private enum CodingKeys: String, CodingKey {
        case witness
        case certCreated = "cert_created"
        case certificate
        case protectionKey = "protection_key"
        case epoch
        case submitted
        case submittedStatus = "submitted_status"
        case proof
    }
    
    public init(
        witness: RegistrationWitness? = nil,
        certCreated: Date? = nil,
        certificate: FilePath? = nil,
        protectionKey: String? = nil,
        epoch: Int? = nil,
        submitted: Date? = nil,
        submittedStatus: String? = nil,
        proof: String? = nil
    ) {
        self.witness = witness
        self.certCreated = certCreated
        self.certificate = certificate
        self.protectionKey = protectionKey
        self.epoch = epoch
        self.submitted = submitted
        self.submittedStatus = submittedStatus
        self.proof = proof
    }
    
    public func getCertificate() throws -> SwiftCardanoCore.PoolRegistration {
        guard let certificate else {
            throw SwiftCardanoMultitoolError
                .valueError("Certificate file path is missing.")
        }
        return try SwiftCardanoCore.PoolRegistration.load(from: certificate.string)

    }
}
