import Foundation

/// What kind of thing a quantity is, as powers of length, mass and angle:
/// area is length², a plain number is all zeros.
public struct Dimension: Hashable, Sendable {
    public var length: Int8
    public var mass: Int8
    public var angle: Int8

    public init(length: Int8 = 0, mass: Int8 = 0, angle: Int8 = 0) {
        self.length = length
        self.mass = mass
        self.angle = angle
    }

    public static let none = Dimension()
    public static let length = Dimension(length: 1)
    public static let area = Dimension(length: 2)
    public static let volume = Dimension(length: 3)
    public static let mass = Dimension(mass: 1)
    public static let angle = Dimension(angle: 1)

    public func multiplied(by other: Dimension) -> Dimension {
        Dimension(length: length + other.length, mass: mass + other.mass, angle: angle + other.angle)
    }

    public func divided(by other: Dimension) -> Dimension {
        Dimension(length: length - other.length, mass: mass - other.mass, angle: angle - other.angle)
    }

    /// The word used in messages: "Can't add length and weight".
    public var name: String {
        switch self {
        case .none: return "number"
        case .length: return "length"
        case .area: return "area"
        case .volume: return "volume"
        case .mass: return "weight"
        case .angle: return "angle"
        default:
            let parts = [("length", length), ("weight", mass), ("angle", angle)]
                .filter { $0.1 != 0 }
                .map { $0.1 == 1 ? $0.0 : "\($0.0)^\($0.1)" }
            return parts.joined(separator: "·")
        }
    }
}

/// A unit, sized in the engine's base units: inches (and in², in³), pounds
/// and degrees. Every factor is exact: 1 in = 25.4 mm, 1 lb = 0.45359237 kg.
public struct Unit: Hashable, Sendable {
    /// The canonical name, used to look the unit up again and to display it.
    public let symbol: String
    public let dimension: Dimension
    public let toBase: Rational
}

public enum Units {
    /// The unit a word names, or nil. Exact spelling first, then lowercase,
    /// so `L` and `mL` work alongside `ft` and `FT`.
    public static func lookup(_ word: String) -> Unit? {
        byWord[word] ?? byWord[word.lowercased()]
    }

    public static var all: [Unit] { table.map(\.unit) }

    private static func r(_ n: Int64, _ d: Int64 = 1) -> Rational { try! Rational(n, d) }
    private static func dec(_ s: String) -> Rational { try! Rational.parse(decimal: s) }

    private static let inchesPerMeter = r(5000, 127)          // 1 / 0.0254
    private static let cubicInchesPerLiter = try! r(1000).divided(by: dec("16.387064"))
    private static let poundsPerKilogram = r(100_000_000, 45_359_237)

    private static func cube(_ x: Rational) -> Rational { try! x.multiplied(by: x).multiplied(by: x) }
    private static func square(_ x: Rational) -> Rational { try! x.multiplied(by: x) }

    private static let table: [(unit: Unit, words: [String])] = {
        let m = inchesPerMeter
        func length(_ s: String, _ f: Rational, _ w: [String]) -> (Unit, [String]) {
            (Unit(symbol: s, dimension: .length, toBase: f), [s] + w)
        }
        func area(_ s: String, _ f: Rational, _ w: [String]) -> (Unit, [String]) {
            (Unit(symbol: s, dimension: .area, toBase: f), [s] + w)
        }
        func volume(_ s: String, _ f: Rational, _ w: [String]) -> (Unit, [String]) {
            (Unit(symbol: s, dimension: .volume, toBase: f), [s] + w)
        }
        func mass(_ s: String, _ f: Rational, _ w: [String]) -> (Unit, [String]) {
            (Unit(symbol: s, dimension: .mass, toBase: f), [s] + w)
        }
        let gallon = r(231)
        return [
            length("in", r(1), ["\"", "inch", "inches"]),
            length("ft", r(12), ["'", "foot", "feet"]),
            length("yd", r(36), ["yard", "yards"]),
            length("mi", r(63360), ["mile", "miles"]),
            length("mm", try! m.divided(by: r(1000)), ["millimeter", "millimeters", "millimetre", "millimetres"]),
            length("cm", try! m.divided(by: r(100)), ["centimeter", "centimeters", "centimetre", "centimetres"]),
            length("m", m, ["meter", "meters", "metre", "metres"]),
            length("km", try! m.multiplied(by: r(1000)), ["kilometer", "kilometers", "kilometre", "kilometres"]),

            area("sq in", r(1), ["sqin", "in²", "in2", "square inch", "square inches"]),
            area("sq ft", r(144), ["sqft", "ft²", "ft2", "square foot", "square feet"]),
            area("sq yd", r(1296), ["sqyd", "yd²", "yd2", "square yard", "square yards"]),
            area("m²", square(m), ["m2", "sqm", "sq m", "square meter", "square meters"]),
            area("acre", r(43560 * 144), ["acres"]),

            volume("cu in", r(1), ["cuin", "in³", "in3", "cubic inch", "cubic inches"]),
            volume("cu ft", r(1728), ["cuft", "ft³", "ft3", "cubic foot", "cubic feet"]),
            volume("cu yd", r(46656), ["cuyd", "yd³", "yd3", "cubic yard", "cubic yards"]),
            volume("m³", cube(m), ["m3", "cubic meter", "cubic meters"]),
            volume("L", cubicInchesPerLiter, ["l", "liter", "liters", "litre", "litres"]),
            volume("mL", try! cubicInchesPerLiter.divided(by: r(1000)), ["ml", "milliliter", "milliliters"]),
            volume("gal", gallon, ["gallon", "gallons"]),
            volume("qt", try! gallon.divided(by: r(4)), ["quart", "quarts"]),
            volume("cup", try! gallon.divided(by: r(16)), ["cups"]),
            volume("fl oz", try! gallon.divided(by: r(128)), ["floz"]),

            mass("lb", r(1), ["lbs", "pound", "pounds"]),
            mass("oz", r(1, 16), ["ounce", "ounces"]),
            mass("kg", poundsPerKilogram, ["kilogram", "kilograms"]),
            mass("g", try! poundsPerKilogram.divided(by: r(1000)), ["gram", "grams"]),
            mass("st", r(14), ["stone", "stones"]),
            mass("ton", r(2000), ["tons"]),

            (Unit(symbol: "°", dimension: .angle, toBase: r(1)), ["°", "deg", "degree", "degrees"]),
        ]
    }()

    private static let byWord: [String: Unit] = {
        var map: [String: Unit] = [:]
        for (unit, words) in table {
            for word in words { map[word] = unit }
        }
        // Typographic marks macOS and other apps substitute for ' and ".
        for mark in ["’", "′", "‘"] { map[mark] = map["'"] }
        for mark in ["”", "″", "“"] { map[mark] = map["\""] }
        return map
    }()

    /// Every multi-word unit phrase, longest first, for the lexer.
    static let phrases: [String] = byWord.keys.filter { $0.contains(" ") }.sorted { $0.count > $1.count }
}
