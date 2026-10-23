import Foundation

public enum Token: Equatable, Sendable {
    case number(Rational)
    /// A unit's canonical symbol: `'` becomes "ft", `in` stays "in".
    case unit(String)
    case ident(String)
    /// A board name like `2x4`, written without spaces.
    case nominal(String)
    case plus, minus, times, divide, lparen, rparen, equals
}

/// Splits one notepad line into tokens. Numbers come out exact, including
/// mixed numbers written the carpenter's way: `9 1/2` and `9-1/2`.
public func lex(_ line: String) throws -> [Token] {
    var lexer = Lexer(normalize(line))
    return try lexer.run()
}

/// Typographic marks and math symbols, mapped to the plain characters the
/// lexer reads. macOS substitutes smart quotes in most text fields.
private func normalize(_ line: String) -> [Character] {
    Array(line.map { c -> Character in
        switch c {
        case "’", "′", "‘": return "'"
        case "”", "″", "“": return "\""
        case "−", "–": return "-"
        case "×", "·": return "*"
        case "÷": return "/"
        default: return c
        }
    })
}

private struct Lexer {
    let chars: [Character]
    var i = 0
    var tokens: [Token] = []

    init(_ chars: [Character]) { self.chars = chars }

    func peek(_ offset: Int = 0) -> Character? {
        i + offset < chars.count ? chars[i + offset] : nil
    }

    static func isDigit(_ c: Character?) -> Bool { c.map { $0.isASCII && $0.isNumber } ?? false }
    static func isWordStart(_ c: Character?) -> Bool { c.map { $0.isLetter || $0 == "_" } ?? false }
    static func isWordPart(_ c: Character?) -> Bool {
        c.map { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "²" || $0 == "³" } ?? false
    }

    mutating func run() throws -> [Token] {
        while let c = peek() {
            if c.isWhitespace { i += 1; continue }
            if Self.isDigit(c) || (c == "." && Self.isDigit(peek(1))) {
                try number()
                continue
            }
            if Self.isWordStart(c) {
                word()
                continue
            }
            i += 1
            switch c {
            case "+": tokens.append(.plus)
            case "-": tokens.append(.minus)
            case "*": tokens.append(.times)
            case "/": tokens.append(.divide)
            case "(": tokens.append(.lparen)
            case ")": tokens.append(.rparen)
            case "=": tokens.append(.equals)
            case "'", "\"", "°":
                tokens.append(.unit(Units.lookup(String(c))!.symbol))
                // Drawings write 8'-6": feet, a dash, then inches. The dash
                // joins them; it isn't subtraction (that needs spaces).
                if c == "'", peek() == "-", Self.isDigit(peek(1)) { i += 1 }
            default:
                throw EngineError.unexpected(String(c))
            }
        }
        return tokens
    }

    /// Reads digits at `i` without consuming them; returns the digits and the
    /// index just past them.
    func digits(from start: Int) -> (String, Int) {
        var j = start
        while j < chars.count, Self.isDigit(chars[j]) { j += 1 }
        return (String(chars[start..<j]), j)
    }

    /// `n/d` starting at `start` with no spaces, not followed by another digit
    /// or a decimal point. Returns the fraction and the index past it.
    func fraction(at start: Int) throws -> (Rational, Int)? {
        let (num, afterNum) = digits(from: start)
        guard !num.isEmpty, afterNum < chars.count, chars[afterNum] == "/" else { return nil }
        let (den, afterDen) = digits(from: afterNum + 1)
        guard !den.isEmpty, afterDen >= chars.count || chars[afterDen] != "." else { return nil }
        guard let n = Int64(num), let d = Int64(den) else { throw EngineError.overflow }
        return (try Rational(n, d), afterDen)
    }

    mutating func number() throws {
        let (whole, afterWhole) = digits(from: i)

        // A board name: 2x4, 4x4 (no spaces).
        if !whole.isEmpty, afterWhole + 1 < chars.count, chars[afterWhole] == "x",
           Self.isDigit(chars[afterWhole + 1]) {
            let (second, afterSecond) = digits(from: afterWhole + 1)
            if !Self.isWordPart(afterSecond < chars.count ? chars[afterSecond] : nil) {
                tokens.append(.nominal("\(whole)x\(second)"))
                i = afterSecond
                return
            }
        }

        // A plain fraction: 1/2.
        if let (value, end) = try fraction(at: i) {
            tokens.append(.number(value))
            i = end
            return
        }

        // A decimal or whole number.
        var end = afterWhole
        var text = whole
        if end < chars.count, chars[end] == ".", Self.isDigit(end + 1 < chars.count ? chars[end + 1] : nil) {
            let (decimals, afterDecimals) = digits(from: end + 1)
            text += "." + decimals
            end = afterDecimals
        }
        var value = try Rational.parse(decimal: text)
        i = end

        // A mixed number, only after a whole number: `9 1/2` (one space) or `9-1/2`.
        if !text.contains("."), let sep = peek(), sep == " " || sep == "-",
           let (part, after) = try fraction(at: i + 1) {
            value = try value.adding(part)
            i = after
        }
        tokens.append(.number(value))
    }

    mutating func word() {
        // Multi-word units first: "sq ft", "square feet", "fl oz".
        let rest = String(chars[i...]).lowercased()
        for phrase in Units.phrases where rest.hasPrefix(phrase.lowercased()) {
            let end = i + phrase.count
            if !Self.isWordPart(end < chars.count ? chars[end] : nil) {
                tokens.append(.unit(Units.lookup(phrase)!.symbol))
                i = end
                return
            }
        }
        let start = i
        while Self.isWordPart(peek()) { i += 1 }
        let text = String(chars[start..<i])
        if let unit = Units.lookup(text) {
            tokens.append(.unit(unit.symbol))
        } else {
            tokens.append(.ident(text))
        }
    }
}
