import AppKit
import SwiftUI
import TwoByFourKit

/// The notepad: a plain-text editor with each line's answer drawn in a
/// column on the right, level with the line's first row even when it wraps.
/// Clicking an answer shows its other units.
struct NotepadEditor: NSViewRepresentable {
    @Binding var text: String
    var precision: Precision

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NotepadTextView.make()
        textView.delegate = context.coordinator
        textView.string = text
        textView.precision = precision
        textView.refreshRows()

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NotepadTextView else { return }
        context.coordinator.text = $text
        if textView.string != text { textView.string = text }
        if textView.precision != precision {
            textView.precision = precision
            textView.refreshRows()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NotepadTextView else { return }
            text.wrappedValue = textView.string
            textView.refreshRows()
        }
    }
}

final class NotepadTextView: NSTextView {
    var precision: Precision = .sixteenth
    /// Draws the answers; a subview, so it scrolls with the text.
    private let column = ResultsColumnView()

    static let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    static let gap: CGFloat = 16

    override init(frame: NSRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        configure()
    }

    /// A TextKit 1 text view, for its line fragment geometry.
    static func make() -> NotepadTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        layout.addTextContainer(container)
        return NotepadTextView(frame: .zero, textContainer: container)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func configure() {
        font = Self.font
        typingAttributes = [.font: Self.font, .foregroundColor: NSColor.textColor]
        textContainerInset = NSSize(width: 12, height: 12)
        isRichText = false
        allowsUndo = true
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        // Smart quotes would turn 8' 9" into 8’ 9”. The engine reads both,
        // but what's on screen should be what was typed.
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        addSubview(column)
    }

    /// How wide the answers column is.
    private var resultsWidth: CGFloat { min(300, max(140, bounds.width * 0.4)) }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Text wraps before the answers column.
        let width = max(80, newSize.width - textContainerInset.width * 2 - resultsWidth - Self.gap)
        if let container = textContainer, container.size.width != width {
            container.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        }
        layoutColumn()
    }

    override func didChangeText() {
        super.didChangeText()
        layoutColumn()
    }

    func refreshRows() {
        column.rows = NotepadModel.rows(for: string, precision: precision)
        layoutColumn()
    }

    /// Places the column right of the text and tells it where each line starts.
    private func layoutColumn() {
        guard let layout = layoutManager, let container = textContainer else { return }
        layout.ensureLayout(for: container)
        let x = textContainerOrigin.x + container.size.width + Self.gap
        column.frame = NSRect(x: x, y: 0, width: max(0, bounds.width - x - textContainerInset.width),
                              height: bounds.height)

        let text = string as NSString
        var tops: [Int: NSRect] = [:]
        var lineStart = 0
        for row in column.rows {
            guard lineStart < text.length else { break }
            let lineRange = text.lineRange(for: NSRange(location: lineStart, length: 0))
            let glyph = layout.glyphIndexForCharacter(at: lineRange.location)
            let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            tops[row.line] = NSRect(x: 0, y: textContainerOrigin.y + fragment.minY,
                                    width: column.bounds.width, height: fragment.height)
            lineStart = NSMaxRange(lineRange)
        }
        column.lineRects = tops
        column.needsDisplay = true
        window?.invalidateCursorRects(for: column)
    }
}

/// The answers, each level with its line. Click one for its other units.
final class ResultsColumnView: NSView {
    var rows: [ResultRow] = []
    var lineRects: [Int: NSRect] = [:]
    private var popover: NSPopover?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        for row in rows {
            guard let text = shown(row), let rect = lineRects[row.line] else { continue }
            attributed(row, text).draw(in: rect)
        }
    }

    /// The answer, or its shorter form when the whole one won't fit.
    private func shown(_ row: ResultRow) -> String? {
        guard let label = row.display.label, let rect = lineRects[row.line] else { return row.display.label }
        return attributed(row, label).size().width <= rect.width ? label : row.display.compactLabel
    }

    private func attributed(_ row: ResultRow, _ text: String) -> NSAttributedString {
        let isError: Bool
        if case .error = row.display { isError = true } else { isError = false }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byTruncatingHead
        return NSAttributedString(string: text, attributes: [
            .font: isError ? NSFont.systemFont(ofSize: 12) : NotepadTextView.font,
            .foregroundColor: isError ? NSColor.tertiaryLabelColor : NSColor.systemOrange,
            .paragraphStyle: paragraph,
        ])
    }

    /// The drawn answer's own area, right-aligned in its line.
    private func hitRect(_ row: ResultRow) -> NSRect? {
        guard case .result = row.display, let text = shown(row), let rect = lineRects[row.line] else { return nil }
        let width = min(rect.width, attributed(row, text).size().width)
        return NSRect(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only answers take clicks; everywhere else goes to the text.
        let local = convert(point, from: superview)
        return rows.contains { hitRect($0)?.contains(local) == true } ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let row = rows.first(where: { hitRect($0)?.contains(point) == true }),
              case .result(let result) = row.display, let rect = hitRect(row) else { return }
        Log.shared.write("opened other units for line \(row.line + 1): \(result.primary.text)")
        popover?.close()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ResultPopover(result: result) { [weak popover] in
            popover?.close()
        })
        popover.show(relativeTo: rect, of: self, preferredEdge: .maxY)
        self.popover = popover
    }

    override func resetCursorRects() {
        for row in rows {
            if let rect = hitRect(row) { addCursorRect(rect, cursor: .pointingHand) }
        }
    }
}
