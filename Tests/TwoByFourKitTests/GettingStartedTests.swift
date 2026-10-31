import Foundation
import Testing
@testable import TwoByFourKit

@Suite struct GettingStartedTests {
    @Test func everyLineOfTheGuideWorks() {
        let rows = NotepadModel.rows(for: GettingStarted.text, precision: .sixteenth)
        #expect(rows.filter { if case .result = $0.display { true } else { false } }.count >= 8)
        for row in rows {
            if case .error(let message) = row.display { Issue.record("line \(row.line + 1): \(message)") }
        }
    }

    @Test func everyLineFitsBesideItsAnswerOnAPhone() {
        for line in GettingStarted.text.components(separatedBy: "\n") {
            #expect(line.count <= 16, "\(line)")
        }
    }

    @MainActor @Test func aNewStoreStartsWithTheGuide() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("guide-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SheetStore(directory: dir)
        let first = store.createFirstSheet(guide: true)
        #expect(first.name == "Getting Started")
        #expect(first.text == GettingStarted.text)
        #expect(store.createFirstSheet(guide: false).name == "Scratch")
    }
}
