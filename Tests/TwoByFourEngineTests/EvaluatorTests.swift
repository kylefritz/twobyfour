import Testing
@testable import TwoByFourEngine

private func r(_ a: Int64, _ b: Int64 = 1) -> Rational { try! Rational(a, b) }

/// Evaluates one line on its own and returns the value in base units.
private func value(_ line: String) throws -> Quantity {
    guard case .expression(let e) = try parse(lex(line)) else { Issue.record("not an expression"); throw EngineError.overflow }
    return try evaluate(e, in: Scope())
}

private func message(_ line: String) -> String? {
    guard case .error(let e) = SheetEvaluator.evaluate(line).first else { return nil }
    return e.message
}

@Suite struct EvaluatorTests {
    @Test func tenFeetSplitThreeWaysIsExact() throws {
        #expect(try value("10' / 3").value == r(40))
    }

    @Test func areaFromTwoLengths() throws {
        let area = try value("2' * 3'")
        #expect(area.value == r(864))
        #expect(area.dimension == .area)
    }

    @Test func tenStone() throws {
        let q = try value("10 stone")
        #expect(q.value == r(140))
        #expect(q.dimension == .mass)
    }

    @Test func conversionsKeepTheTargetUnit() throws {
        let q = try value("1220 mm in ft")
        #expect(q.displayUnit?.symbol == "ft")
        #expect(try q.value == r(1220).multiplied(by: r(5, 127)))
    }

    @Test func errorsReadLikeSentences() {
        #expect(message("5' + 3 lb") == "Can't add length and weight")
        #expect(message("5' - 3 lb") == "Can't subtract length and weight")
        #expect(message("1' / 0") == "Can't divide by zero")
        #expect(message("5' in lb") == "Can't convert length to weight")
        #expect(message("3 cubits") == "Unknown: cubits")
        #expect(message("2x4") == "Unknown size: 2x4")
        #expect(message("m = 3") == "m is a unit")
        #expect(message("3 +") == "Line ends too soon")
        #expect(message("5 $") == "Didn't expect \"$\"")
    }

    @Test func hugeExactNumbersErrorInsteadOfCrashing() {
        #expect(message("0.0001 mm * 999999999 * 999999999 * 999999999") == "Number too large to work out exactly")
    }
}

@Suite struct SheetEvaluatorTests {
    @Test func variablesOnlyReachLinesBelowThem() throws {
        let outcomes = SheetEvaluator.evaluate("a + 1\"\na = 2\"\na\na = 3\"\na")
        #expect(outcomes.count == 5)
        #expect(outcomes[0] == .error(.unknownTerm("a")))
        #expect(outcomes[1] == .assignment("a", Quantity(value: r(2), dimension: .length)))
        #expect(outcomes[2] == .value(Quantity(value: r(2), dimension: .length)))
        #expect(outcomes[3] == .assignment("a", Quantity(value: r(3), dimension: .length)))
        #expect(outcomes[4] == .value(Quantity(value: r(3), dimension: .length)))
    }

    @Test func wallMinusTwoInches() throws {
        let outcomes = SheetEvaluator.evaluate("wall = 12' 6\"\nwall - 3\"")
        #expect(outcomes[1] == .value(Quantity(value: r(147), dimension: .length)))
    }

    @Test func commentsAndBlanks() {
        let outcomes = SheetEvaluator.evaluate("// note\n# note\n\n   \n#")
        #expect(outcomes == [.comment, .comment, .blank, .blank, .comment])
    }

    @Test func aHashBeforeANumberIsNotAComment() {
        // `#9 screw` is a fastener (Plan 2), not a comment.
        if case .comment = SheetEvaluator.evaluate("#9 screw")[0] { Issue.record("#9 was treated as a comment") }
    }

    @Test func anErrorDoesntStopLaterLines() {
        let outcomes = SheetEvaluator.evaluate("1' / 0\n2'")
        #expect(outcomes[1] == .value(Quantity(value: r(24), dimension: .length)))
    }
}
