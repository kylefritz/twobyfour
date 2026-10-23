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
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return .blank }
            // `# ` (with a space) is a comment; `#9` will be a screw size.
            if line.hasPrefix("//") || line == "#" || line.hasPrefix("# ") { return .comment }
            do {
                switch try parse(lex(line)) {
                case .expression(let e):
                    return .value(try TwoByFourEngine.evaluate(e, in: env))
                case let .assignment(name, e):
                    let value = try TwoByFourEngine.evaluate(e, in: env)
                    env.variables[name] = value
                    return .assignment(name, value)
                }
            } catch let error as EngineError {
                return .error(error)
            } catch {
                return .error(.unexpected("\(error)"))
            }
        }
    }
}
