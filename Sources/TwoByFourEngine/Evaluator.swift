import Foundation

/// The variables defined so far on a sheet. Names ignore case: `Deck` is `deck`.
public struct Scope: Sendable {
    private var values: [String: Quantity] = [:]
    public init() {}

    public subscript(name: String) -> Quantity? {
        get { values[name.lowercased()] }
        set { values[name.lowercased()] = newValue }
    }
}

public func evaluate(_ expr: Expr, in env: Scope) throws -> Quantity {
    switch expr {
    case .number(let value):
        return .number(value)
    case let .quantity(amount, symbol):
        return try Quantity(amount, Units.lookup(symbol)!)
    case .variable(let name):
        guard let value = env[name] else { throw EngineError.unknownTerm(name) }
        return value
    case .nominal(let name):
        throw EngineError.unknownSize(name)
    case .negate(let inner):
        return try evaluate(inner, in: env).negated
    case let .binary(op, left, right):
        let a = try evaluate(left, in: env), b = try evaluate(right, in: env)
        switch op {
        case .add: return try a.adding(b)
        case .subtract: return try a.subtracting(b)
        case .multiply: return try a.multiplied(by: b)
        case .divide: return try a.divided(by: b)
        }
    case let .power(base, exponent):
        return try power(evaluate(base, in: env), evaluate(exponent, in: env))
    case let .convert(inner, symbol):
        return try evaluate(inner, in: env).converted(to: Units.lookup(symbol)!)
    }
}

/// `base` multiplied by itself `exponent` times, which must be a plain whole
/// number; a negative power divides instead.
private func power(_ base: Quantity, _ exponent: Quantity) throws -> Quantity {
    guard exponent.dimension == .none, exponent.value.denominator == 1 else { throw EngineError.fractionalPower }
    // Anything past this overflows an exact value long before the loop matters.
    guard exponent.value.numerator.magnitude <= 64 else { throw EngineError.overflow }
    var result = Quantity.number(try Rational(1))
    for _ in 0..<exponent.value.numerator.magnitude {
        result = try exponent.value.isNegative ? result.divided(by: base) : result.multiplied(by: base)
    }
    return result
}
