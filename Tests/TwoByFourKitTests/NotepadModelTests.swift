import Testing
@testable import TwoByFourKit

@Suite struct NotepadModelTests {
    @Test func eachLineGetsItsAnswer() {
        let rows = NotepadModel.rows(for: "105\"\n\n// hi\nwall = 12' 6\"\nwall - 3\"", precision: .sixteenth)
        #expect(rows.map(\.line) == [0, 1, 2, 3, 4])
        #expect(rows.map(\.display.primaryText) == ["8' 9\" (105\")", nil, nil, "12' 6\" (150\")", "12' 3\" (147\")"])
    }

    @Test func roundedAnswersAreMarked() {
        let rows = NotepadModel.rows(for: "1220 mm", precision: .thirtySecond)
        #expect(rows[0].display.primaryText == "4' 0 1/32\" (48 1/32\")")
        guard case .result(let result) = rows[0].display else { Issue.record("no result"); return }
        #expect(!result.primary.isExact)
        #expect(rows[0].display.label == "≈ 4' 0 1/32\" (48 1/32\")")
    }

    @Test func errorsShowTheirMessage() {
        let rows = NotepadModel.rows(for: "5' + 3 lb", precision: .sixteenth)
        #expect(rows[0].display == .error("Can't add length and weight"))
        #expect(rows[0].display.label == "Can't add length and weight")
    }
}
