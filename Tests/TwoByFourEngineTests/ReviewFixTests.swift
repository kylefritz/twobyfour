import Foundation
import Testing
@testable import TwoByFourEngine

private func r(_ a: Int64, _ b: Int64 = 1) -> Rational { try! Rational(a, b) }

private func inches(_ line: String) -> Rational? {
    guard case .value(let q) = SheetEvaluator.evaluate(line)[0] else { return nil }
    return q.value
}

/// Fixes from the whole-branch review.
@Suite struct ReviewFixTests {
    @Test func architecturalFeetDashInchesIsOneLength() {
        // Drawings write 8'-6": eight feet six inches, not eight feet minus six.
        #expect(inches("8'-6\"") == r(102))
        #expect(inches("12'-0 1/2\"") == r(289, 2))
        #expect(inches("8'-6 1/2\"") == r(205, 2))
        #expect(inches("8’-6”") == r(102))
        // With spaces it's still subtraction.
        #expect(inches("8' - 6\"") == r(90))
    }

    @Test func runawayPowersOfLengthErrorInsteadOfCrashing() {
        let line = Array(repeating: "1\"", count: 130).joined(separator: " * ")
        guard case .error(let e) = SheetEvaluator.evaluate(line)[0] else {
            Issue.record("expected an error")
            return
        }
        #expect(e == .overflow)
    }

    @Test(arguments: ["\r\n", "\r", "\u{2028}", "\u{2029}", "\u{85}"])
    func everyKindOfLineBreakStartsANewLine(_ breakText: String) {
        let text = "10'" + breakText + "6\"\n1'"
        let outcomes = SheetEvaluator.evaluate(text)
        // The same count NSTextView sees, so answers line up with their lines.
        var lines = 0
        (text as NSString).enumerateSubstrings(in: NSRange(location: 0, length: (text as NSString).length),
                                               options: .byLines) { _, _, _, _ in lines += 1 }
        #expect(outcomes.count == lines)
        #expect(outcomes.count == 3)
        #expect(outcomes[0] == .value(Quantity(value: r(120), dimension: .length)))
    }

    @Test func aRoundedLengthShowsItsExactValueToo() throws {
        guard case .value(let q) = SheetEvaluator.evaluate("1/3 m")[0] else { Issue.record("no value"); return }
        let result = try ResultFormatter.format(q, precision: .sixteenth)
        #expect(!result.primary.isExact)
        #expect(result.alternates.first == FormattedValue(text: "13 47/381\"", isExact: true))
    }

    @Test func aRoundedNumberShowsItsExactValueToo() throws {
        let third = try ResultFormatter.format(.number(r(1, 3)), precision: .sixteenth)
        #expect(third.alternates.first == FormattedValue(text: "1/3", isExact: true))
        guard case .value(let q) = SheetEvaluator.evaluate("10 stone")[0] else { Issue.record("no value"); return }
        let kg = try ResultFormatter.format(q.converted(to: Units.lookup("kg")!), precision: .sixteenth)
        #expect(!kg.primary.isExact)
        #expect(kg.alternates.first == FormattedValue(text: "63.5029318 kg", isExact: true))
    }

    @Test func anExactAnswerDoesntRepeatItself() throws {
        let result = try ResultFormatter.format(Quantity(value: r(105), dimension: .length), precision: .sixteenth)
        #expect(result.alternates.filter(\.isExact).map(\.text).contains("105\""))
        #expect(result.alternates.filter { $0.text == "105\"" }.count == 1)
    }
}
