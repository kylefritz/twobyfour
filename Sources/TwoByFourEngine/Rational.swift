import Foundation

/// An exact fraction, always reduced, with a positive denominator. Every
/// calculation in the engine uses these so `10' / 3` is exactly 3' 4" and
/// nothing drifts; overflow throws instead of trapping.
public struct Rational: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let numerator: Int64
    public let denominator: Int64

    public static let zero = Rational(unchecked: 0, 1)
    public static let one = Rational(unchecked: 1, 1)

    public init(_ numerator: Int64, _ denominator: Int64 = 1) throws {
        guard denominator != 0 else { throw EngineError.divideByZero }
        // Int64.min can't be negated, so refuse it rather than trap.
        guard numerator != .min, denominator != .min else { throw EngineError.overflow }
        let g = Self.gcd(numerator.magnitude, denominator.magnitude)
        var n = numerator / Int64(g), d = denominator / Int64(g)
        if d < 0 { n = -n; d = -d }
        self.init(unchecked: n, d)
    }

    private init(unchecked numerator: Int64, _ denominator: Int64) {
        self.numerator = numerator
        self.denominator = denominator
    }

    /// `"2.667"`, `"-0.5"`, `".25"` or `"12"`, exactly.
    public static func parse(decimal text: String) throws -> Rational {
        var digits = Substring(text)
        var negative = false
        if digits.first == "-" { negative = true; digits = digits.dropFirst() }
        let pieces = digits.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole = pieces[0], fraction = pieces.count > 1 ? pieces[1] : ""
        guard !(whole.isEmpty && fraction.isEmpty),
              (whole + fraction).allSatisfy(\.isASCII), (whole + fraction).allSatisfy(\.isNumber)
        else { throw EngineError.overflow }
        guard fraction.count <= 18, let n = Int64(whole + fraction) else { throw EngineError.overflow }
        var d: Int64 = 1
        for _ in 0..<fraction.count { d *= 10 }
        return try Rational(negative ? -n : n, d)
    }

    public var isZero: Bool { numerator == 0 }
    public var isNegative: Bool { numerator < 0 }
    public var negated: Rational { Rational(unchecked: -numerator, denominator) }
    public var magnitude: Rational { isNegative ? negated : self }
    public var doubleValue: Double { Double(numerator) / Double(denominator) }
    /// The whole-number part, truncating toward zero.
    public var wholePart: Int64 { numerator / denominator }

    public func adding(_ other: Rational) throws -> Rational {
        // Over the least common denominator, to keep numbers small.
        let g = Int64(Self.gcd(denominator.magnitude, other.denominator.magnitude))
        let left = try Self.checked(numerator.multipliedReportingOverflow(by: other.denominator / g))
        let right = try Self.checked(other.numerator.multipliedReportingOverflow(by: denominator / g))
        let n = try Self.checked(left.addingReportingOverflow(right))
        let d = try Self.checked((denominator / g).multipliedReportingOverflow(by: other.denominator))
        return try Rational(n, d)
    }

    public func subtracting(_ other: Rational) throws -> Rational {
        try adding(other.negated)
    }

    public func multiplied(by other: Rational) throws -> Rational {
        // Cancel across before multiplying so results that fit don't overflow on the way.
        let g1 = Int64(Self.gcd(numerator.magnitude, other.denominator.magnitude))
        let g2 = Int64(Self.gcd(other.numerator.magnitude, denominator.magnitude))
        let n = try Self.checked((numerator / g1).multipliedReportingOverflow(by: other.numerator / g2))
        let d = try Self.checked((denominator / g2).multipliedReportingOverflow(by: other.denominator / g1))
        return try Rational(n, d)
    }

    public func divided(by other: Rational) throws -> Rational {
        guard !other.isZero else { throw EngineError.divideByZero }
        return try multiplied(by: Rational(other.denominator, other.numerator))
    }

    /// The nearest multiple of `step`, ties away from zero.
    public func rounded(toMultipleOf step: Rational) throws -> Rational {
        let steps = try divided(by: step)
        let whole = steps.wholePart
        let remainder = try steps.subtracting(Rational(whole))
        // |remainder| >= 1/2 rounds away from zero.
        let twice = try remainder.magnitude.multiplied(by: Rational(2))
        var count = whole
        if twice >= .one { count += steps.isNegative ? -1 : 1 }
        return try Rational(count).multiplied(by: step)
    }

    public static func < (a: Rational, b: Rational) -> Bool {
        // Compare without overflow by going through the difference's sign;
        // fall back to doubles only if even that overflows.
        if let d = try? a.subtracting(b) { return d.isNegative }
        return a.doubleValue < b.doubleValue
    }

    public var description: String {
        denominator == 1 ? "\(numerator)" : "\(numerator)/\(denominator)"
    }

    private static func checked(_ result: (partialValue: Int64, overflow: Bool)) throws -> Int64 {
        guard !result.overflow, result.partialValue != .min else { throw EngineError.overflow }
        return result.partialValue
    }

    private static func gcd(_ a: UInt64, _ b: UInt64) -> UInt64 {
        var a = a, b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a == 0 ? 1 : a
    }
}
