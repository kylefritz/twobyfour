import Foundation

/// Why a line couldn't be worked out. `message` is what the notepad shows.
public enum EngineError: Error, Equatable, Sendable {
    case overflow
    case divideByZero
    /// Verb, then the two kinds: ("add", "length", "weight").
    case mismatch(String, String, String)
    case cannotConvert(String, String)
    /// Something the line can't contain at that spot.
    case unexpected(String)
    /// A unit's name used as a variable: `m = 3`.
    case reservedName(String)
    /// A word that isn't a unit or a variable defined above.
    case unknownTerm(String)
    /// A board name the engine doesn't know yet.
    case unknownSize(String)

    public var message: String {
        switch self {
        case .overflow: return "Number too large to work out exactly"
        case .divideByZero: return "Can't divide by zero"
        case let .mismatch(verb, a, b): return "Can't \(verb) \(a) and \(b)"
        case let .cannotConvert(a, b): return "Can't convert \(a) to \(b)"
        case .unexpected("end of line"): return "Line ends too soon"
        case .unexpected(let text): return "Didn't expect \"\(text)\""
        case .reservedName(let name): return "\(name) is a unit"
        case .unknownTerm(let word): return "Unknown: \(word)"
        case .unknownSize(let name): return "Unknown size: \(name)"
        }
    }
}
