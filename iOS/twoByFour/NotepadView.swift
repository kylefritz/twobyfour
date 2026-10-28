import SwiftUI
import TwoByFourKit
import UIKit

/// The notepad: plain text with each line's answer at the right, level with
/// the line's first row even when it wraps. Typing uses the carpenter keypad;
/// tapping an answer shows its other units.
struct NotepadEditor: UIViewRepresentable {
    @Binding var text: String
    var precision: Precision

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> NotepadTextView {
        let view = NotepadTextView.make()
        view.delegate = context.coordinator
        view.text = text
        view.precision = precision
        view.refreshRows()
        DispatchQueue.main.async { view.becomeFirstResponder() }
        return view
    }

    func updateUIView(_ view: NotepadTextView, context: Context) {
        context.coordinator.text = $text
        var changed = false
        // Setting text from here doesn't call textViewDidChange, so the
        // answers are refreshed by hand.
        if view.text != text {
            view.text = text
            changed = true
        }
        if view.precision != precision {
            view.precision = precision
            changed = true
        }
        if changed { view.refreshRows() }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func textViewDidChange(_ textView: UITextView) {
            guard let view = textView as? NotepadTextView else { return }
            text.wrappedValue = view.text
            view.refreshRows()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
            // Return on the letters keyboard finishes the line: back to the keypad.
            if replacementText == "\n", let view = textView as? NotepadTextView, view.showingLetters {
                DispatchQueue.main.async { view.showKeypad() }
            }
            return true
        }
    }
}

final class NotepadTextView: UITextView {
    var precision: Precision = .sixteenth
    private(set) var showingLetters = false
    private let column = ResultsColumnView()
    private lazy var keypad = KeypadView { [weak self] action in self?.handle(action) }
    private lazy var lettersBar = LettersBar { [weak self] in self?.showKeypad() }

    static let font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    static let gap: CGFloat = 12
    static let inset: CGFloat = 12

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// A TextKit 1 text view, for its line fragment geometry. Built by hand:
    /// `init(usingTextLayoutManager:)` skips this subclass's stored properties.
    static func make() -> NotepadTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        let view = NotepadTextView(frame: .zero, textContainer: container)
        view.configure()
        return view
    }

    private func configure() {
        font = Self.font
        textColor = .label
        backgroundColor = .systemBackground
        alwaysBounceVertical = true
        keyboardDismissMode = .none
        // Smart quotes would turn 8' 9" into 8’ 9”. The engine reads both,
        // but what's on screen should be what was typed.
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        autocorrectionType = .no
        autocapitalizationType = .none
        spellCheckingType = .no
        dataDetectorTypes = []
        inputView = keypad
        column.onOpen = { [weak self] result in self?.openOtherUnits(result) }
        addSubview(column)
    }

    /// How wide the answers column is.
    private var resultsWidth: CGFloat { min(200, max(110, bounds.width * 0.4)) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = UIEdgeInsets(top: Self.inset, left: Self.inset, bottom: Self.inset,
                                 right: Self.inset + resultsWidth + Self.gap)
        if textContainerInset != inset { textContainerInset = inset }
        layoutColumn()
    }

    func refreshRows() {
        column.rows = NotepadModel.rows(for: text, precision: precision)
        layoutColumn()
    }

    /// Places the column right of the text and tells it where each line starts.
    private func layoutColumn() {
        let layout = layoutManager
        layout.ensureLayout(for: textContainer)
        let x = bounds.width - Self.inset - resultsWidth
        column.frame = CGRect(x: x, y: 0, width: resultsWidth,
                              height: max(contentSize.height, bounds.height))

        let string = text as NSString
        var tops: [Int: CGRect] = [:]
        var lineStart = 0
        for row in column.rows {
            guard lineStart < string.length else { break }
            let lineRange = string.lineRange(for: NSRange(location: lineStart, length: 0))
            let glyph = layout.glyphIndexForCharacter(at: lineRange.location)
            let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            tops[row.line] = CGRect(x: 0, y: textContainerInset.top + fragment.minY,
                                    width: resultsWidth, height: fragment.height)
            lineStart = NSMaxRange(lineRange)
        }
        column.lineRects = tops
        column.setNeedsDisplay()
        // UITextView adds views of its own as it lays out; stay above them.
        if subviews.last !== column { bringSubviewToFront(column) }
    }

    // MARK: Keypad

    private func handle(_ action: KeypadView.Action) {
        switch action {
        case .key(let key): type(key)
        case .letters: showLetters()
        }
    }

    /// Applies a keypad key through the text view's own editing, so undo and
    /// the delegate see it like typing.
    private func type(_ key: KeypadKey) {
        let old = text ?? ""
        let (new, selection) = Keypad.apply(key, to: old, selection: selectedRange)
        guard new != old else { return }
        let (range, replacement) = Self.difference(from: old as NSString, to: new as NSString)
        if let start = position(from: beginningOfDocument, offset: range.location),
           let end = position(from: start, offset: range.length),
           let textRange = textRange(from: start, to: end) {
            replace(textRange, withText: replacement)
        }
        selectedRange = selection
        scrollRangeToVisible(selection)
    }

    /// The smallest replacement that turns `old` into `new`.
    static func difference(from old: NSString, to new: NSString) -> (NSRange, String) {
        var prefix = 0
        while prefix < old.length, prefix < new.length, old.character(at: prefix) == new.character(at: prefix) {
            prefix += 1
        }
        var suffix = 0
        while suffix < old.length - prefix, suffix < new.length - prefix,
              old.character(at: old.length - 1 - suffix) == new.character(at: new.length - 1 - suffix) {
            suffix += 1
        }
        let range = NSRange(location: prefix, length: old.length - prefix - suffix)
        return (range, new.substring(with: NSRange(location: prefix, length: new.length - prefix - suffix)))
    }

    private func showLetters() {
        showingLetters = true
        inputView = nil
        inputAccessoryView = lettersBar
        reloadInputViews()
    }

    func showKeypad() {
        showingLetters = false
        inputView = keypad
        inputAccessoryView = nil
        reloadInputViews()
    }

    private func openOtherUnits(_ result: FormattedResult) {
        Log.shared.write("opened other units for \(result.primary.text)")
        let host = UIHostingController(rootView: OtherUnitsView(result: result))
        host.sheetPresentationController?.detents = [.medium()]
        host.sheetPresentationController?.prefersGrabberVisible = true
        window?.rootViewController?.topmost.present(host, animated: true)
    }
}

private extension UIViewController {
    var topmost: UIViewController { presentedViewController?.topmost ?? self }
}

/// The answers, each level with its line. Tap one for its other units.
final class ResultsColumnView: UIView {
    var rows: [ResultRow] = []
    var lineRects: [Int: CGRect] = [:]
    var onOpen: ((FormattedResult) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ rect: CGRect) {
        for row in rows {
            guard let label = row.display.label, let line = lineRects[row.line] else { continue }
            attributed(row, label).draw(in: line)
        }
    }

    private func attributed(_ row: ResultRow, _ text: String) -> NSAttributedString {
        let isError: Bool
        if case .error = row.display { isError = true } else { isError = false }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        // A long answer keeps its end (the inches); an error keeps its start.
        paragraph.lineBreakMode = isError ? .byTruncatingTail : .byTruncatingHead
        return NSAttributedString(string: text, attributes: [
            .font: isError ? UIFont.systemFont(ofSize: 13) : NotepadTextView.font,
            .foregroundColor: isError ? UIColor.tertiaryLabel : UIColor.systemOrange,
            .paragraphStyle: paragraph,
        ])
    }

    /// The drawn answer's own area, right-aligned in its line, made at least
    /// a fingertip wide.
    private func hitRect(_ row: ResultRow) -> CGRect? {
        guard case .result = row.display, let text = row.display.label, let line = lineRects[row.line] else { return nil }
        let width = min(line.width, max(44, attributed(row, text).size().width))
        return CGRect(x: line.maxX - width, y: line.minY, width: width, height: max(line.height, 32))
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Only answers take taps; everywhere else goes to the text.
        rows.contains { hitRect($0)?.contains(point) == true }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        guard let row = rows.first(where: { hitRect($0)?.contains(point) == true }),
              case .result(let result) = row.display else { return }
        onOpen?(result)
    }
}
