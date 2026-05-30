import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("DateUtils")
struct DateUtilsTests {

    @Test("getCurrentTimestamp matches yyyy-MM-dd-HHmmss shape")
    func timestampShape() {
        let ts = DateUtils.getCurrentTimestamp()
        // 4-2-2-6 digits separated by dashes; total length 17
        #expect(ts.count == 17)
        let regex = #/^\d{4}-\d{2}-\d{2}-\d{6}$/#
        #expect(ts.wholeMatch(of: regex) != nil)
    }

    @Test("getCurrentTimestamp is round-trippable through the documented format")
    func timestampParsesBack() {
        let ts = DateUtils.getCurrentTimestamp()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        #expect(formatter.date(from: ts) != nil)
    }
}
