import Foundation

public enum Op: Equatable, Sendable { case add, subtract, multiply, divide }

public indirect enum Expr: Equatable, Sendable {
    case number(Rational)
    /// An amount and a unit's canonical symbol.
    case quantity(Rational, String)
    case variable(String)
    case nominal(String)
    case negate(Expr)
    case binary(Op, Expr, Expr)
    /// The base to a whole-number power: `deck^2`.
    case power(Expr, Expr)
    /// Show the expression in the unit with this symbol.
    case convert(Expr, String)
}

public enum Statement: Equatable, Sendable {
    case expression(Expr)
    case assignment(String, Expr)
}

/// Turns one line's tokens into a statement. Lowest to highest precedence:
/// conversion (`in`/`to`/`as` + unit), `+ -`, `* /` (and a spaced `x`),
/// unary minus, `^`, then numbers with units, where lengths written side by
/// side largest first (`8' 9"`) are added. A variable's name can be several
/// words: `king stud = 8' 9"`.
public func parse(_ tokens: [Token]) throws -> Statement {
    var parser = Parser(tokens: tokens)
    return try parser.statement()
}

private struct Parser {
    let tokens: [Token]
    var i = 0

    func peek(_ offset: Int = 0) -> Token? {
        i + offset < tokens.count ? tokens[i + offset] : nil
    }

    mutating func next() throws -> Token {
        guard let t = peek() else { throw EngineError.unexpected("end of line") }
        i += 1
        return t
    }

    /// Words that are operators between names, never part of one.
    static let operatorWords: Set<String> = ["x", "to", "as"]

    mutating func statement() throws -> Statement {
        var words = 0
        while case .ident(let word)? = peek(words), words == 0 || !Self.operatorWords.contains(word) { words += 1 }
        if words > 0, peek(words) == .equals {
            let name = tokens[0..<words].map(\.text).joined(separator: " ")
            i = words + 1
            return .assignment(name, try wholeExpression())
        }
        if peek(1) == .equals, case .unit(let symbol)? = peek() {
            throw EngineError.reservedName(symbol)
        }
        return .expression(try wholeExpression())
    }

    /// `first` and the words right after it, as one variable's name.
    mutating func name(startingWith first: String) -> String {
        var words = [first]
        while case .ident(let word)? = peek(), !Self.operatorWords.contains(word) {
            words.append(word)
            i += 1
        }
        return words.joined(separator: " ")
    }

    mutating func wholeExpression() throws -> Expr {
        let e = try expression()
        if let leftover = peek() { throw EngineError.unexpected(leftover.text) }
        return e
    }

    /// Additive expression followed by any number of conversions.
    mutating func expression() throws -> Expr {
        var e = try additive()
        while let target = conversionTarget() {
            i += 2
            e = .convert(e, target)
        }
        return e
    }

    /// The unit after `in`, `to` or `as`, when the next two tokens are one.
    func conversionTarget() -> String? {
        guard case .unit(let symbol)? = peek(1) else { return nil }
        switch peek() {
        case .unit("in")?, .ident("to")?, .ident("as")?: return symbol
        default: return nil
        }
    }

    mutating func additive() throws -> Expr {
        var e = try term()
        while let t = peek(), t == .plus || t == .minus {
            i += 1
            e = .binary(t == .plus ? .add : .subtract, e, try term())
        }
        return e
    }

    mutating func term() throws -> Expr {
        var e = try unary()
        while true {
            switch peek() {
            case .times?, .ident("x")?:
                i += 1
                e = .binary(.multiply, e, try unary())
            case .divide?:
                i += 1
                e = .binary(.divide, e, try unary())
            default:
                return e
            }
        }
    }

    mutating func unary() throws -> Expr {
        if peek() == .minus {
            i += 1
            return .negate(try unary())
        }
        let base = try primary()
        guard peek() == .caret else { return base }
        i += 1
        // Right of `^` can be negative (`2^-1`) and chains to the right.
        return .power(base, try unary())
    }

    mutating func primary() throws -> Expr {
        switch try next() {
        case .number(let value):
            return try numberWithUnits(value)
        case .lparen:
            let e = try expression()
            guard try next() == .rparen else { throw EngineError.unexpected(tokens[i - 1].text) }
            return e
        case .ident(let word):
            return .variable(name(startingWith: word))
        case .nominal(let name):
            return .nominal(name)
        case let other:
            throw EngineError.unexpected(other.text)
        }
    }

    /// A number, its unit, and any smaller lengths written right after it.
    mutating func numberWithUnits(_ value: Rational) throws -> Expr {
        // `3 cubits` or `3 width`: a word right after a number multiplies it,
        // so an unknown word reads as "Unknown: cubits" rather than a syntax error.
        if case .ident(let word)? = peek(), !Self.operatorWords.contains(word) {
            i += 1
            return .binary(.multiply, .number(value), .variable(name(startingWith: word)))
        }
        guard case .unit(let symbol)? = peek() else { return .number(value) }
        i += 1
        var e = Expr.quantity(value, symbol)

        // `9.5 in mm`: a bare number, `in`, then a unit means inches, converted.
        if symbol == "in", case .unit(let target)? = peek(), target != "in" {
            i += 1
            return .convert(e, target)
        }

        var last = Units.lookup(symbol)!
        while last.dimension == .length, case .number(let more)? = peek() {
            // `8' 9`: a bare number right after feet is inches.
            var unit = Units.lookup("in")!
            var width = 1
            if case .unit(let s)? = peek(1) {
                unit = Units.lookup(s)!
                width = 2
            } else if last.symbol != "ft" {
                break
            }
            guard unit.dimension == .length, unit.toBase < last.toBase else { break }
            i += width
            e = .binary(.add, e, .quantity(more, unit.symbol))
            last = unit
        }
        return e
    }
}

extension Token {
    /// How the token reads in an error message.
    var text: String {
        switch self {
        case .number(let r): return r.description
        case .unit(let s), .ident(let s), .nominal(let s): return s
        case .plus: return "+"
        case .minus: return "-"
        case .times: return "×"
        case .divide: return "/"
        case .caret: return "^"
        case .lparen: return "("
        case .rparen: return ")"
        case .equals: return "="
        }
    }
}
