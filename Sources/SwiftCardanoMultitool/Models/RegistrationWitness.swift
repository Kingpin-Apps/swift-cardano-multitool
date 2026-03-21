import Foundation

/// Registration Witness model class
public struct RegistrationWitness: Codable, Sendable {
    /// Unique identifier for this registration witness
    public var id: UUID
    
    /// Date this registration witness was created
    public var date: Date
    
    /// The type of registration transaction
    public var type: TransactionType?
    
    /// The transaction body
    public var txBody: TextEnvelope?
    
    /// The list of witnesses for this registration
    public var witnesses: [TransactionWitness]
    
    /// The payee for the registration
    public var payee: RegistrationPayee?
    
    /// Time to live for the transaction
    public var ttl: Int?
    
    /// Whether a hardware wallet is included in the witnesses
    public var hardwareWalletIncluded: Bool
    
    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case type
        case txBody = "tx_body"
        case witnesses
        case payee
        case ttl
        case hardwareWalletIncluded = "hardware_wallet_included"
    }
    
    /// The valid transaction types for a registration witness
    private static let validTransactionTypes: Set<TransactionType> = [
        .poolRegistration,
        .poolReRegistration,
        .poolRetirement
    ]
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: TransactionType? = nil,
        txBody: TextEnvelope? = nil,
        witnesses: [TransactionWitness] = [],
        payee: RegistrationPayee? = nil,
        ttl: Int? = nil,
        hardwareWalletIncluded: Bool = false
    ) throws {
        self.id = id
        self.date = date
        
        if let type = type {
            guard Self.validTransactionTypes.contains(type) else {
                throw SwiftCardanoMultitoolError.valueError(
                    "Transaction type for registration witness is \(type) but must be either " +
                    "POOL_REGISTRATION, POOL_RE_REGISTRATION, or POOL_RETIREMENT."
                )
            }
        }
        self.type = type
        
        self.txBody = txBody
        self.witnesses = witnesses
        self.payee = payee
        self.ttl = ttl
        self.hardwareWalletIncluded = hardwareWalletIncluded
    }
}

