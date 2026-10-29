import Foundation
import Testing
@testable import TwoByFourKit

/// Runs every example in docs/SPEC.md. Each ```twobyfour block is one sheet;
/// a line written `input → answer` must show exactly that answer.
@Suite struct SpecTests {
    static let spec = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/SPEC.md")

    /// The blocks' lines, and the answer each `→` line expects, by block.
    static func blocks() throws -> [[(line: String, expected: String?)]] {
        var blocks: [[(String, String?)]] = []
        var current: [(String, String?)]?
        for line in try String(contentsOf: spec, encoding: .utf8).components(separatedBy: "\n") {
            if line.hasPrefix("```twobyfour") { current = []; continue }
            guard current != nil else { continue }
            if line.hasPrefix("```") {
                blocks.append(current!)
                current = nil
                continue
            }
            let parts = line.components(separatedBy: "→")
            let input = parts[0].trimmingCharacters(in: .whitespaces)
            let expected = parts.count > 1 ? parts.dropFirst().joined(separator: "→").trimmingCharacters(in: .whitespaces) : nil
            current!.append((input, expected))
        }
        return blocks
    }

    @Test func theSpecHasExamples() throws {
        let examples = try Self.blocks().flatMap { $0 }.filter { $0.expected != nil }
        #expect(examples.count > 50)
    }

    @Test func everyExampleShowsItsAnswer() throws {
        for (b, block) in try Self.blocks().enumerated() {
            let rows = NotepadModel.rows(for: block.map(\.line).joined(separator: "\n"), precision: .sixteenth)
            for (row, example) in zip(rows, block) {
                guard let expected = example.expected else { continue }
                #expect(row.display.label == expected, "block \(b + 1): \(example.line)")
            }
        }
    }
}
