import Testing
@testable import SwiftCardanoMultitool

private enum SampleChoice: String, CaseIterable, AlignedChoiceDescribable {
    case short
    case longerName
    case longestNameHere

    var name: String {
        switch self {
        case .short: return "Short"
        case .longerName: return "Longer"
        case .longestNameHere: return "Longest Name"
        }
    }

    var details: String {
        switch self {
        case .short: return "short detail"
        case .longerName: return "longer detail"
        case .longestNameHere: return "longest detail"
        }
    }
}

@Suite("AlignedChoiceDescribable")
struct AlignedChoiceDescribableTests {

    @Test("right-pads the name to the width of the longest name")
    func padsToLongestName() {
        let descriptions = SampleChoice.allCases.map(\.description)
        // The dash position should be identical across all cases.
        let dashIndices = descriptions.map { $0.distance(from: $0.startIndex, to: $0.firstIndex(of: "-")!) }
        #expect(Set(dashIndices).count == 1)
    }

    @Test("renders as 'name - details' with name padded to widest name")
    func rendersAsNameDashDetails() {
        let widest = SampleChoice.allCases.map(\.name.count).max()!
        for choice in SampleChoice.allCases {
            let expected = choice.name.padding(toLength: widest, withPad: " ", startingAt: 0) + " - " + choice.details
            #expect(choice.description == expected)
        }
    }

    @Test("preserves the original name characters before the padding")
    func preservesOriginalName() {
        for choice in SampleChoice.allCases {
            #expect(choice.description.hasPrefix(choice.name))
        }
    }
}
