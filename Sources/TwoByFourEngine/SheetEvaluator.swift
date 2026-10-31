import Foundation

public enum LineOutcome: Equatable, Sendable {
    case blank
    case comment
    case value(Quantity)
    case assignment(String, Quantity)
    case error(EngineError)
}

public enum SheetEvaluator {
    /// Splits on every line break the Mac text system recognizes (CRLF, CR,
    /// NEL, U+2028, U+2029 as well as LF), so the notepad and the engine
    /// always agree on which answer belongs to which line.
    public static func lines(_ text: String) -> [Substring] {
        text.split(omittingEmptySubsequences: false) { c in
            c == "\n" || c == "\r\n" || c == "\r" || c == "\u{85}" || c == "\u{2028}" || c == "\u{2029}"
        }
    }

    /// One outcome per line, top to bottom. A variable is visible only to
    /// the lines below its assignment, and an error never stops later lines.
    public static func evaluate(_ text: String) -> [LineOutcome] {
        var env = Scope()
        return lines(text).map { raw in
            let whole = raw.trimmingCharacters(in: .whitespaces)
            if whole.isEmpty { return .blank }
            // `# ` (with a space) is a comment; `#9` will be a screw size.
            if whole.hasPrefix("//") || whole == "#" || whole.hasPrefix("# ") { return .comment }
            let line = withoutComment(whole)
            do {
                switch try parse(lex(line)) {
                case .expression(let e):
                    return .value(try TwoByFourEngine.evaluate(e, in: env))
                case let .assignment(name, e):
                    let value = try TwoByFourEngine.evaluate(e, in: env)
                    env[name] = value
                    return .assignment(name, value)
                }
            } catch let error as EngineError {
                return .error(error)
            } catch {
                return .error(.unexpected("\(error)"))
            }
        }
    }

    /// The line up to a comment: a `#` after a space, followed by a space or
    /// nothing. `deck^2 # 144 sqft` is `deck^2`; `#10` stays (a screw size).
    static func withoutComment(_ line: String) -> String {
        let chars = Array(line)
        for (k, c) in chars.enumerated() where c == "#" && k > 0 && chars[k - 1].isWhitespace {
            if k + 1 == chars.count || chars[k + 1].isWhitespace {
                return String(chars[..<k]).trimmingCharacters(in: .whitespaces)
            }
        }
        return line
    }
}
