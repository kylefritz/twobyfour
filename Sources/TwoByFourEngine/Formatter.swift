import Foundation

/// The finest tape-measure mark a sheet rounds lengths to.
public enum Precision: Int, CaseIterable, Codable, Sendable {
    case half = 2, quarter = 4, eighth = 8, sixteenth = 16, thirtySecond = 32, sixtyFourth = 64

    public var label: String { "1/\(rawValue)\"" }
    var step: Rational { try! Rational(1, Int64(rawValue)) }
}

/// Text to show, and whether it's the exact value (`=`) or rounded (`≈`).
public struct FormattedValue: Equatable, Sendable {
    public let text: String
    public let isExact: Bool

    public init(text: String, isExact: Bool) {
        self.text = text
        self.isExact = isExact
    }
}

/// The answer shown on the line, and the other ways to write it that
/// clicking the answer reveals.
public struct FormattedResult: Equatable, Sendable {
    public let primary: FormattedValue
    public let alternates: [FormattedValue]
    /// `primary` without extras, for when it doesn't fit: `7' 4"` for `7' 4" (88")`.
    public let compact: FormattedValue
}

public enum ResultFormatter {
    public static func format(_ q: Quantity, precision: Precision) throws -> FormattedResult {
        var forms: [FormattedValue]
        var primary: FormattedValue
        var compact: FormattedValue?
        switch q.dimension {
        case .length:
            forms = [try feetInches(q.value, precision: precision),
                     try inches(q.value, precision: precision),
                     try decimal(q.value, unit: "m"),
                     try decimal(q.value, unit: "cm"),
                     try decimal(q.value, unit: "mm")]
            // Feet and inches also say the total, and inches say the feet:
            // `7' 4" (88")`, `48" (4' 0")`. Under a foot the two are the same,
            // so it's just `9 1/2"`.
            let (feet, inches) = (forms[0], forms[1])
            func both(_ first: FormattedValue, _ second: FormattedValue) -> FormattedValue {
                feet.text == inches.text ? first
                    : FormattedValue(text: "\(first.text) (\(second.text))", isExact: first.isExact)
            }
            switch q.displayUnit?.symbol {
            case nil, "ft"?:
                primary = both(feet, inches)
                compact = feet
            case "in"?:
                primary = both(inches, feet)
                compact = inches
            case let symbol?: primary = try decimal(q.value, unit: symbol)
            }
        case .area:
            (primary, forms) = try decimals(q, default: "sq ft", others: ["sq in", "m²"])
        case .volume:
            (primary, forms) = try decimals(q, default: "cu ft", others: ["cu yd", "gal", "L"])
        case .mass:
            (primary, forms) = try decimals(q, default: "lb", others: ["kg", "oz"])
        case .angle:
            (primary, forms) = try decimals(q, default: "°", others: [])
        case .none:
            primary = try decimal(q.value, unit: nil)
            forms = []
        default:
            primary = try decimal(q.value, unit: nil)
            primary = FormattedValue(text: "\(primary.text) (\(q.dimension.name) in inches/pounds)", isExact: primary.isExact)
            forms = []
        }
        // A rounded answer also shows its exact value, first.
        if !primary.isExact {
            forms.insert(try exact(q), at: 0)
        }
        var seen: Set<String> = [primary.text]
        let alternates = forms.filter { seen.insert($0.text).inserted }
        return FormattedResult(primary: primary, alternates: alternates, compact: compact ?? primary)
    }

    private static func decimals(_ q: Quantity, default symbol: String, others: [String]) throws
        -> (FormattedValue, [FormattedValue]) {
        let primary = try decimal(q.value, unit: q.displayUnit?.symbol ?? symbol)
        let forms = try ([symbol] + others).map { try decimal(q.value, unit: $0) }
        return (primary, forms)
    }

    /// `8' 9"`, `4' 0 1/32"`, or inches only under a foot: `9 1/2"`.
    /// Rounds before splitting off feet, so 11' 11 31/32" becomes 12' 0".
    public static func feetInches(_ inches: Rational, precision: Precision) throws -> FormattedValue {
        let rounded = try inches.rounded(toMultipleOf: precision.step)
        let size = rounded.magnitude
        let sign = rounded.isNegative ? "-" : ""
        let isExact = rounded == inches
        guard size >= (try Rational(12)) else {
            return FormattedValue(text: sign + mixed(size) + "\"", isExact: isExact)
        }
        let feet = try size.divided(by: Rational(12)).wholePart
        let rest = try size.subtracting(Rational(feet).multiplied(by: Rational(12)))
        let restText = rest.isZero ? "0" : (rest.wholePart == 0 ? "0 " + mixed(rest) : mixed(rest))
        return FormattedValue(text: "\(sign)\(feet)' \(restText)\"", isExact: isExact)
    }

    /// Inches only, to the chosen fraction: `105"`, `48 1/32"`.
    public static func inches(_ inches: Rational, precision: Precision) throws -> FormattedValue {
        let rounded = try inches.rounded(toMultipleOf: precision.step)
        let sign = rounded.isNegative ? "-" : ""
        return FormattedValue(text: sign + mixed(rounded.magnitude) + "\"", isExact: rounded == inches)
    }

    /// `value` (in base units) in `unit`, to at most three decimals:
    /// `2.667 m`, `63.503 kg`. With no unit, just the number.
    public static func decimal(_ value: Rational, unit symbol: String?) throws -> FormattedValue {
        var amount = value
        if let symbol {
            amount = try value.divided(by: Units.lookup(symbol)!.toBase)
        }
        let rounded = try amount.rounded(toMultipleOf: Rational(1, 1000))
        // `rounded` is a whole number of thousandths.
        let thousandths = try rounded.multiplied(by: Rational(1000)).numerator
        let whole = thousandths.magnitude / 1000, fraction = thousandths.magnitude % 1000
        var text = (thousandths < 0 ? "-" : "") + "\(whole)"
        if fraction != 0 {
            var digits = String(format: "%03llu", fraction)
            while digits.hasSuffix("0") { digits.removeLast() }
            text += "." + digits
        }
        if let symbol { text += symbol == "°" ? "°" : " \(symbol)" }
        return FormattedValue(text: text, isExact: rounded == amount)
    }

    /// The exact value: lengths in inches as a fraction (`13 49/381"`),
    /// anything else in its shown unit as a terminating decimal when there is
    /// one (`63.5029318 kg`) or else a fraction (`1/3`).
    static func exact(_ q: Quantity) throws -> FormattedValue {
        if q.dimension == .length, q.displayUnit == nil || ["ft", "in"].contains(q.displayUnit!.symbol) {
            let sign = q.value.isNegative ? "-" : ""
            return FormattedValue(text: sign + mixed(q.value.magnitude) + "\"", isExact: true)
        }
        let symbol: String? = q.displayUnit?.symbol ?? defaultSymbol(q.dimension)
        let amount = try symbol.map { try q.value.divided(by: Units.lookup($0)!.toBase) } ?? q.value
        let sign = amount.isNegative ? "-" : ""
        var text = sign + (terminatingDecimal(amount.magnitude) ?? mixed(amount.magnitude))
        if let symbol { text += symbol == "°" ? "°" : " \(symbol)" }
        return FormattedValue(text: text, isExact: true)
    }

    private static func defaultSymbol(_ dimension: Dimension) -> String? {
        switch dimension {
        case .length: return "in"
        case .area: return "sq ft"
        case .volume: return "cu ft"
        case .mass: return "lb"
        case .angle: return "°"
        default: return nil
        }
    }

    /// `63.5029318` when the value ends within 12 decimals, else nil.
    private static func terminatingDecimal(_ value: Rational) -> String? {
        var d = value.denominator
        var places = 0
        while d % 2 == 0 { d /= 2 }
        while d % 5 == 0 { d /= 5 }
        guard d == 1 else { return nil }
        var scaled = value
        while scaled.denominator != 1 {
            guard places < 12, let next = try? scaled.multiplied(by: Rational(10)) else { return nil }
            scaled = next
            places += 1
        }
        var digits = String(scaled.numerator)
        guard places > 0 else { return digits }
        while digits.count <= places { digits = "0" + digits }
        digits.insert(".", at: digits.index(digits.endIndex, offsetBy: -places))
        return digits
    }

    /// `9 1/2`, `3/8`, `12`: a non-negative value as a whole number and a
    /// reduced fraction.
    private static func mixed(_ value: Rational) -> String {
        let whole = value.wholePart
        let fraction = (try? value.subtracting(Rational(whole))) ?? .zero
        if fraction.isZero { return "\(whole)" }
        let part = "\(fraction.numerator)/\(fraction.denominator)"
        return whole == 0 ? part : "\(whole) \(part)"
    }
}
