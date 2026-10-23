import AppKit
import TwoByFourKit

/// Development aid: `twobyfour --snapshot-notepad <file.png> [--light]` draws
/// a sample sheet offscreen and exits. For checking the layout on a machine
/// with no one at the screen, and for README images.
enum Snapshot {
    static let sample = """
    // Back deck
    105"
    wall = 12' 6"
    wall - 2 * 1 1/2"
    1220 mm in ft
    10' / 3
    rim = 16' - 2 * 1 1/2" - 1/8" + a really long comment-ish line that has to wrap around to show alignment
    10 stone
    5' + 3 lb
    """

    static func notepad(to file: URL, light: Bool) throws {
        _ = NSApplication.shared
        let size = NSSize(width: 760, height: 300)
        let textView = NotepadTextView.make()
        textView.appearance = NSAppearance(named: light ? .aqua : .darkAqua)
        textView.precision = .thirtySecond
        textView.frame = NSRect(origin: .zero, size: size)
        textView.string = sample
        textView.refreshRows()
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        guard let rep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        textView.cacheDisplay(in: textView.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: file)
    }
}
