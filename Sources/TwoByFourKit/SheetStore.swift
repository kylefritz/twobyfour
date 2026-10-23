@_exported import TwoByFourEngine
import Combine
import Foundation

/// One named notepad: its text and how finely it rounds lengths.
public struct Sheet: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var text: String
    public var precision: Precision
    public var modified: Date

    public init(id: UUID = UUID(), name: String, text: String = "", precision: Precision = .sixteenth,
                modified: Date = Date()) {
        self.id = id
        self.name = name
        self.text = text
        self.precision = precision
        self.modified = modified
    }
}

/// Sheets saved as one JSON file each in `directory`, most recently edited
/// first. A file that can't be read is left alone, never deleted.
@MainActor
public final class SheetStore: ObservableObject {
    @Published public private(set) var sheets: [Sheet] = []
    public let directory: URL
    private let log: Log

    public init(directory: URL, log: Log = .shared) {
        self.directory = directory
        self.log = log
        load()
    }

    /// `~/Library/Application Support/twoByFour/Sheets`.
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("twoByFour/Sheets")
    }

    @discardableResult
    public func create(name: String = "Untitled") -> Sheet {
        let sheet = Sheet(name: name)
        save(sheet)
        return sheet
    }

    /// Saves `sheet`, stamping it as just edited.
    public func update(_ sheet: Sheet) {
        var sheet = sheet
        sheet.modified = Date()
        save(sheet)
    }

    public func delete(id: UUID) {
        try? FileManager.default.removeItem(at: file(for: id))
        sheets.removeAll { $0.id == id }
    }

    private func file(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    private func save(_ sheet: Sheet) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(sheet).write(to: file(for: sheet.id), options: .atomic)
        } catch {
            log.write("couldn't save sheet \(sheet.id): \(error)")
        }
        sheets.removeAll { $0.id == sheet.id }
        sheets.append(sheet)
        sort()
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        sheets = files.filter { $0.pathExtension == "json" }.compactMap { url in
            do {
                return try decoder.decode(Sheet.self, from: Data(contentsOf: url))
            } catch DecodingError.dataCorrupted(let context) {
                log.write("couldn't read sheet \(url.lastPathComponent): \(context.debugDescription)")
                return nil
            } catch {
                log.write("couldn't read sheet \(url.lastPathComponent): \(error)")
                return nil
            }
        }
        sort()
    }

    private func sort() {
        sheets.sort { $0.modified > $1.modified }
    }
}
