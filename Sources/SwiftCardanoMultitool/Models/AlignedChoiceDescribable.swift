import Foundation

/// A choice in a `noora.singleChoicePrompt` whose `description` is rendered as
/// `name - details`, with `name` right-padded so the dashes line up across all
/// cases of the enum. Conform an enum and provide `name` + `details`; the
/// `description` default takes care of the alignment.
public protocol AlignedChoiceDescribable: CaseIterable, CustomStringConvertible {
    var name: String { get }
    var details: String { get }
}

extension AlignedChoiceDescribable where AllCases.Element == Self {
    public var description: String {
        let width = Self.allCases.map(\.name.count).max() ?? 0
        let padded = name.padding(toLength: width, withPad: " ", startingAt: 0)
        return "\(padded) - \(details)"
    }
}
