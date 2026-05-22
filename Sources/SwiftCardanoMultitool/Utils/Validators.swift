import Foundation
import Noora
import SwiftCardanoCore

/// A validation rule that accepts a Cardano pool ID in either bech32 (`pool1…`) or 56-character hex form.
public struct PoolIdValidationRule: ValidatableRule {
    public let error: ValidatableError

    public init(error: ValidatableError) {
        self.error = error
    }

    public func validate(input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.hasPrefix("pool") {
            return PoolOperator.isValidBech32(trimmed)
        }

        let hexCandidate = (trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X"))
            ? String(trimmed.dropFirst(2))
            : trimmed
        // PoolKeyHash is 28 bytes → 56 hex chars.
        guard hexCandidate.count == 56 else { return false }
        let hexSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return hexCandidate.unicodeScalars.allSatisfy { hexSet.contains($0) }
    }
}

/// A validation rule that accepts an empty string OR a valid TCP/UDP port number (1–65535).
public struct PortOrEmptyValidationRule: ValidatableRule {
    public let error: ValidatableError

    public init(error: ValidatableError) {
        self.error = error
    }

    public func validate(input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        guard let port = Int(trimmed) else { return false }
        return port >= 1 && port <= 65535
    }
}

/// A validation rule that checks if the input is an Integer and optionally validates its length against specified minimum and maximum bounds.
public struct IntegerValidationRule: ValidatableRule {
    // MARK: Properties
    
    /// The minimum allowed value.
    let min: Int
    
    /// The maximum allowed value.
    let max: Int
    
    /// The error to return when the input's length is outside the valid range.
    public let error: ValidatableError
    
    // MARK: Initialization
    
    /// Initializes a `LengthValidationRule` with minimum and maximum constraints.
    ///
    /// - Parameters:
    ///   - min: The minimum allowed value for the input string (default is 0).
    ///   - max: The maximum allowed value for the input string (default is Int.max).
    ///   - error: The error to return if the input value is outside the valid range.
    public init(min: Int = .zero, max: Int = .max, error: ValidatableError) {
        self.min = min
        self.max = max
        self.error = error
    }
    
    // MARK: ValidatableRule
    
    /// Validates the input string by checking if it is an integer and within the specified range.
    ///
    /// - Parameter input: The string input to validate.
    /// - Returns: A Boolean indicating whether the input length is within the valid range.
    public func validate(input: String) -> Bool {
        if let integer = Int(input) {
            return integer >= min && integer <= max
        }
        return false
    }
}
