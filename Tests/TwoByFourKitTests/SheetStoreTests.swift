import Foundation
import Testing
@testable import TwoByFourKit

@MainActor
@Suite struct SheetStoreTests {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sheets-\(UUID().uuidString)")
    /// Keeps test failures out of the real app log.
    var testLog: Log { Log(file: dir.appendingPathExtension("log")) }

    @Test func aNewSheetIsSavedAndReloads() throws {
        let store = SheetStore(directory: dir, log: testLog)
        var sheet = store.create(name: "Back deck")
        sheet.text = "span = 12' 6\""
        store.update(sheet)

        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(sheet.id).json").path))
        let reloaded = SheetStore(directory: dir, log: testLog)
        #expect(reloaded.sheets.map(\.name) == ["Back deck"])
        #expect(reloaded.sheets.first?.text == "span = 12' 6\"")
        #expect(reloaded.sheets.first?.precision == .sixteenth)
    }

    @Test func theMostRecentlyEditedSheetComesFirst() throws {
        let store = SheetStore(directory: dir, log: testLog)
        var first = store.create(name: "First")
        _ = store.create(name: "Second")
        first.text = "1'"
        store.update(first)
        #expect(store.sheets.map(\.name) == ["First", "Second"])
    }

    @Test func deletingRemovesTheFile() throws {
        let store = SheetStore(directory: dir, log: testLog)
        let sheet = store.create()
        store.delete(id: sheet.id)
        #expect(store.sheets.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(sheet.id).json").path))
    }

    @Test func anUnreadableFileIsSkippedNotDeleted() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let bad = dir.appendingPathComponent("bad.json")
        try Data("not json".utf8).write(to: bad)
        let store = SheetStore(directory: dir, log: testLog)
        _ = store.create(name: "Good")
        let log = testLog
        let reloaded = SheetStore(directory: dir, log: log)
        #expect(reloaded.sheets.map(\.name) == ["Good"])
        #expect(FileManager.default.fileExists(atPath: bad.path))
        #expect(log.tail(5).contains { $0.contains("couldn't read sheet bad.json: The given data was not valid JSON.") })
    }
}
