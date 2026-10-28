import Foundation
import Testing
@testable import TwoByFourKit

@Suite struct DiagnosticsTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("logs-\(UUID().uuidString)")

    @Test func onlyNewOrChangedAnswersAreLogged() {
        let old = "105\"\nwall = 12'\nwall - 3\""
        let new = "105\"\nwall = 12' 6\"\nwall - 3\"\n\n5' + 3 lb"
        #expect(Diagnostics.changes(from: old, to: new, precision: .sixteenth) == [
            "line 2: wall = 12' 6\" → 12' 6\"",
            // Unchanged text, but its answer moved with `wall`.
            "line 3: wall - 3\" → 12' 3\"",
            "line 5: 5' + 3 lb → error: Can't add length and weight",
        ])
    }

    @Test func roundedAnswersAreLoggedWithTheirMark() {
        #expect(Diagnostics.changes(from: "", to: "1220 mm", precision: .thirtySecond)
            == ["line 1: 1220 mm → ≈ 4' 0 1/32\""])
    }

    @Test func tailReadsTheLastLinesAcrossARollover() {
        let log = Log(file: dir.appendingPathComponent("t.log"), maxBytes: 60)
        for n in 1...6 {
            log.write("entry \(n)")
            log.flush()
        }
        let tail = log.tail(3)
        #expect(tail.count == 3)
        #expect(tail.map { $0.components(separatedBy: " ").suffix(2).joined(separator: " ") }
            == ["entry 4", "entry 5", "entry 6"])
    }

    @Test func tailOfAMissingLogIsEmpty() {
        #expect(Log(file: dir.appendingPathComponent("none.log")).tail(10).isEmpty)
    }

    @Test func theReportHasTheBuildTheSheetAndTheLog() {
        let sheet = Sheet(name: "Deck", text: "105\"\n2x4 + ", precision: .eighth)
        let report = Diagnostics.report(version: "0.1.1-beta.3", commit: "abc1234", preview: "",
                                        sheet: sheet, log: ["12:00 launched"])
        #expect(report.contains("twoByFour 0.1.1-beta.3 (abc1234)"))
        #expect(report.contains("macOS "))
        #expect(report.contains("Sheet \"Deck\", rounding to 1/8\""))
        #expect(report.contains("line 1: 105\" → 8' 9\""))
        #expect(report.contains("line 2: 2x4 + → error: "))
        #expect(report.hasSuffix("12:00 launched\n```\n"))
    }

    @Test func reportNamesThisPlatform() {
        let report = Diagnostics.report(version: "1.0", commit: "", preview: "", sheet: nil, log: [])
        let second = report.split(separator: "\n")[1]
        #if os(macOS)
        #expect(second.hasPrefix("macOS ") && second.contains("update channel:"))
        #else
        #expect(second.hasPrefix("iOS "))
        #endif
    }
}
