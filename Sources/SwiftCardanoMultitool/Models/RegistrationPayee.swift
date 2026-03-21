import Foundation
import SystemPackage
import SwiftCardanoUtils

/// Registration Payee model class
public struct RegistrationPayee: Codable, Sendable {
    public var name: String
    public var amount: Int?
    public var amountReturn: Int?
    public var address: String?
    
    @FilePathCodable
    public var skey: FilePath?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case amount
        case amountReturn = "amount_return"
        case address
        case skey
    }
    
    public init(
        name: String,
        amount: Int? = nil,
        amountReturn: Int? = nil,
        address: String? = nil,
        skey: FilePath? = nil
    ) {
        self.name = name
        self.amount = amount
        self.amountReturn = amountReturn
        self.address = address
        self.skey = skey
    }
}
