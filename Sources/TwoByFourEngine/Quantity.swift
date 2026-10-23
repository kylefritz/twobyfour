import Foundation

/// A number with a kind, stored exactly in base units (inches, pounds,
/// degrees). `displayUnit` is the unit someone asked to see with `in`/`to`.
public struct Quantity: Equatable, Sendable {
    public var value: Rational
    public var dimension: Dimension
    public var displayUnit: Unit?

    public init(value: Rational, dimension: Dimension, displayUnit: Unit? = nil) {
        self.value = value
        self.dimension = dimension
        self.displayUnit = displayUnit
    }

    /// `amount` of `unit`, e.g. 9 1/2 inches.
    public init(_ amount: Rational, _ unit: Unit) throws {
        self.init(value: try amount.multiplied(by: unit.toBase), dimension: unit.dimension)
    }

    public static func number(_ value: Rational) -> Quantity {
        Quantity(value: value, dimension: .none)
    }

    public func adding(_ other: Quantity) throws -> Quantity {
        guard dimension == other.dimension else {
            throw EngineError.mismatch("add", dimension.name, other.dimension.name)
        }
        return Quantity(value: try value.adding(other.value), dimension: dimension)
    }

    public func subtracting(_ other: Quantity) throws -> Quantity {
        guard dimension == other.dimension else {
            throw EngineError.mismatch("subtract", dimension.name, other.dimension.name)
        }
        return Quantity(value: try value.subtracting(other.value), dimension: dimension)
    }

    public func multiplied(by other: Quantity) throws -> Quantity {
        Quantity(value: try value.multiplied(by: other.value), dimension: try dimension.multiplied(by: other.dimension))
    }

    public func divided(by other: Quantity) throws -> Quantity {
        Quantity(value: try value.divided(by: other.value), dimension: try dimension.divided(by: other.dimension))
    }

    public var negated: Quantity {
        Quantity(value: value.negated, dimension: dimension, displayUnit: displayUnit)
    }

    /// The same amount, to be shown in `unit`.
    public func converted(to unit: Unit) throws -> Quantity {
        guard unit.dimension == dimension else {
            throw EngineError.cannotConvert(dimension.name, unit.dimension.name)
        }
        return Quantity(value: value, dimension: dimension, displayUnit: unit)
    }
}
