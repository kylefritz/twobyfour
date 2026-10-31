import AppKit
import TwoByFourKit

/// Development aid: `twobyfour --snapshot-notepad <file.png> [--sheet <text file>] [--light]`
/// draws a sheet offscreen and exits: the given text, or a sample. For PR
/// screenshots (`scripts/screenshots`), for checking the layout on a machine
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

    static func notepad(to file: URL, text: String = sample, light: Bool) throws {
        _ = NSApplication.shared
        let width: CGFloat = 760
        let textView = NotepadTextView.make()
        textView.appearance = NSAppearance(named: light ? .aqua : .darkAqua)
        textView.precision = .thirtySecond
        textView.frame = NSRect(x: 0, y: 0, width: width, height: 300)
        textView.string = text
        textView.refreshRows()
        // Grow to fit the sheet, so a long one isn't cut off.
        let container = textView.textContainer!
        textView.layoutManager?.ensureLayout(for: container)
        let used = textView.layoutManager?.usedRect(for: container).height ?? 0
        let height = max(300, ceil(used + 2 * textView.textContainerInset.height + 16))
        textView.frame.size = NSSize(width: width, height: height)
        textView.refreshRows()
        textView.layoutManager?.ensureLayout(for: container)
        guard let rep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        textView.cacheDisplay(in: textView.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: file)
    }
}
