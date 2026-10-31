import Foundation

/// What the notepad shows to the right of one line.
public enum Display: Equatable, Sendable {
    case none
    case result(FormattedResult)
    case error(String)

    /// The text in the results column: the answer, `≈` first when rounded.
    public var label: String? {
        switch self {
        case .none: return nil
        case .result(let r): return r.primary.isExact ? r.primary.text : "≈ \(r.primary.text)"
        case .error(let message): return message
        }
    }

    /// A shorter `label` for a narrow column: `7' 4"` instead of `7' 4" (88")`.
    public var compactLabel: String? {
        guard case .result(let r) = self else { return label }
        return r.compact.isExact ? r.compact.text : "≈ \(r.compact.text)"
    }

    /// The answer without the `≈`, for copying and tests.
    public var primaryText: String? {
        if case .result(let r) = self { return r.primary.text }
        return nil
    }
}

public struct ResultRow: Equatable, Sendable {
    public let line: Int
    public let display: Display
}

public enum NotepadModel {
    /// One row per line of `text`, in order.
    public static func rows(for text: String, precision: Precision) -> [ResultRow] {
        SheetEvaluator.evaluate(text).enumerated().map { index, outcome in
            ResultRow(line: index, display: display(outcome, precision: precision))
        }
    }

    private static func display(_ outcome: LineOutcome, precision: Precision) -> Display {
        let quantity: Quantity
        switch outcome {
        case .blank, .comment: return .none
        case .error(let e): return .error(e.message)
        case .value(let q), .assignment(_, let q): quantity = q
        }
        do {
            return .result(try ResultFormatter.format(quantity, precision: precision))
        } catch let e as EngineError {
            return .error(e.message)
        } catch {
            return .error("\(error)")
        }
    }
}
