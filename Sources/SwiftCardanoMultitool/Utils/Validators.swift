import Noora

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
