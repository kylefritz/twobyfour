import Foundation

/// A key on the iPhone's carpenter keypad that edits text. (`abc` and `123`,
/// which only swap keyboards, aren't keys here.)
public enum KeypadKey: Equatable, Sendable {
    case digit(Int)
    case point, feet, inches, slash, space
    /// The `x` in a board name such as 2x10. Multiplying is `times`.
    case board
    case openParen, closeParen
    case plus, minus, times, divide, equals
    case newline, delete
}

/// What each keypad key does to the text.
///
/// Operators bring their own spaces because the engine reads `47-3/16` as
/// forty-seven and three sixteenths and `2x10` as a board: subtraction and
/// multiplication need to look like `47 − 3/16` and `2 × 10`.
public enum Keypad {
    /// Applies `key` to `text` with `selection` in UTF-16 offsets, as
    /// UITextView counts them. Returns the new text and the cursor after it.
    public static func apply(_ key: KeypadKey, to text: String, selection: NSRange) -> (text: String, selection: NSRange) {
        let ns = text as NSString
        switch key {
        case .delete:
            var range = selection
            if range.length == 0 {
                guard range.location > 0 else { return (text, selection) }
                range = ns.rangeOfComposedCharacterSequence(at: range.location - 1)
            }
            return (ns.replacingCharacters(in: range, with: ""), NSRange(location: range.location, length: 0))
        case .space:
            if before(selection, in: ns) == " " { return replace(selection, in: ns, with: "") }
            return replace(selection, in: ns, with: " ")
        case .plus, .minus, .times, .divide, .equals:
            let prior = before(selection, in: ns)
            let unary = prior == nil || prior == "\n" || prior == "("
            let lead = unary || prior == " " ? "" : " "
            return replace(selection, in: ns, with: lead + symbol(key) + (unary ? "" : " "))
        default:
            return replace(selection, in: ns, with: symbol(key))
        }
    }

    private static func symbol(_ key: KeypadKey) -> String {
        switch key {
        case .digit(let n): return String(n)
        case .point: return "."
        case .feet: return "'"
        case .inches: return "\""
        case .slash: return "/"
        case .space: return " "
        case .board: return "x"
        case .openParen: return "("
        case .closeParen: return ")"
        case .plus: return "+"
        case .minus: return "−"
        case .times: return "×"
        case .divide: return "÷"
        case .equals: return "="
        case .newline: return "\n"
        case .delete: return ""
        }
    }

    /// The character just before the selection, or nil at the very start.
    private static func before(_ selection: NSRange, in text: NSString) -> Character? {
        guard selection.location > 0 else { return nil }
        let range = text.rangeOfComposedCharacterSequence(at: selection.location - 1)
        return text.substring(with: range).first
    }

    private static func replace(_ selection: NSRange, in text: NSString, with insert: String) -> (text: String, selection: NSRange) {
        let result = text.replacingCharacters(in: selection, with: insert)
        return (result, NSRange(location: selection.location + (insert as NSString).length, length: 0))
    }
}
