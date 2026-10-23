import Testing
@testable import TwoByFourEngine

private func r(_ n: Int64, _ d: Int64 = 1) -> Rational { try! Rational(n, d) }

@Suite struct RationalTests {
    @Test func addsFractionsExactly() throws {
        #expect(try r(1, 2).adding(r(1, 3)) == r(5, 6))
    }

    @Test func keepsTheSignOnTheNumeratorAndReduces() {
        let x = r(6, -4)
        #expect(x == r(-3, 2))
        #expect(x.numerator == -3 && x.denominator == 2)
    }

    @Test func parsesDecimalsExactly() throws {
        #expect(try Rational.parse(decimal: "2.667") == r(2667, 1000))
        #expect(try Rational.parse(decimal: "-0.5") == r(-1, 2))
        #expect(try Rational.parse(decimal: ".25") == r(1, 4))
        #expect(try Rational.parse(decimal: "12") == r(12))
    }

    @Test func dividingByZeroThrows() {
        #expect(throws: EngineError.divideByZero) { try r(1).divided(by: r(0)) }
        #expect(throws: EngineError.divideByZero) { try Rational(1, 0) }
    }

    @Test func overflowThrowsInsteadOfTrapping() {
        #expect(throws: EngineError.overflow) { try r(Int64.max).multiplied(by: r(2)) }
        #expect(throws: EngineError.overflow) { try r(Int64.max).adding(r(1)) }
    }

    @Test func crossCancelsBeforeMultiplying() throws {
        // (big/3) × (3/big) is 1 even though big × 3 would overflow.
        let big = Int64.max / 2
        #expect(try r(big, 3).multiplied(by: r(3, big)) == r(1))
    }

    @Test func roundsToTheNearestStepWithTiesAwayFromZero() throws {
        #expect(try r(31, 32).rounded(toMultipleOf: r(1, 16)) == r(1))
        #expect(try r(-3, 32).rounded(toMultipleOf: r(1, 16)) == r(-1, 8))
        #expect(try r(1, 3).rounded(toMultipleOf: r(1, 16)) == r(5, 16))
        #expect(try r(1, 32).rounded(toMultipleOf: r(1, 16)) == r(1, 16))
        #expect(try r(1, 33).rounded(toMultipleOf: r(1, 16)) == r(0))
    }

    @Test func wholePartTruncatesTowardZero() {
        #expect(r(7, 2).wholePart == 3)
        #expect(r(-7, 2).wholePart == -3)
    }
}
