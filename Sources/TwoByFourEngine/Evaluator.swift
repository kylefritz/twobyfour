import Foundation

/// The variables defined so far on a sheet.
public struct Environment: Sendable {
    public var variables: [String: Quantity] = [:]
    public init() {}
}

public func evaluate(_ expr: Expr, in env: Environment) throws -> Quantity {
    switch expr {
    case .number(let value):
        return .number(value)
    case let .quantity(amount, symbol):
        return try Quantity(amount, Units.lookup(symbol)!)
    case .variable(let name):
        guard let value = env.variables[name] else { throw EngineError.unknownTerm(name) }
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
    case let .convert(inner, symbol):
        return try evaluate(inner, in: env).converted(to: Units.lookup(symbol)!)
    }
}
