import Testing
@testable import TwoByFourEngine

// Fixes for what Kyle ran into in sent logs hcsn7rhqhn, k5y6wjb4qe and jpgc8ketis.

private func r(_ a: Int64, _ b: Int64 = 1) -> Rational { try! Rational(a, b) }
private func length(_ inches: Int64) -> LineOutcome { .value(Quantity(value: r(inches), dimension: .length)) }

private func last(_ sheet: String) -> LineOutcome { SheetEvaluator.evaluate(sheet).last! }

private func message(_ sheet: String) -> String? {
    guard case .error(let e) = last(sheet) else { return nil }
    return e.message
}

private func primary(_ line: String) throws -> FormattedValue {
    guard case .value(let q) = last(line) else {
        Issue.record("\(line) didn't evaluate")
        throw EngineError.overflow
    }
    return try ResultFormatter.format(q, precision: .sixteenth).primary
}

@Suite struct TrailingCommentTests {
    @Test func aHashAfterTheMathIsAComment() {
        #expect(last("deck = 12'\ndeck * deck # 144 sqft") == .value(Quantity(value: r(20736), dimension: .area)))
        #expect(last("2' #") == length(24))
        #expect(last("wall = 8' # stud wall") == .assignment("wall", Quantity(value: r(96), dimension: .length)))
    }

    @Test func aHashTouchingANumberIsNotAComment() {
        // `#10` will be a screw size, so only `#` followed by a space (or the
        // end of the line) starts a comment.
        #expect(message("3 #10") == "Didn't expect \"#\"")
    }
}

@Suite struct PowerTests {
    @Test func squaresAndCubes() {
        #expect(last("deck = 12'\ndeck^2") == .value(Quantity(value: r(20736), dimension: .area)))
        #expect(last("3'^3") == .value(Quantity(value: r(46656), dimension: .volume)))
        #expect(last("2^3") == .value(.number(r(8))))
        #expect(last("2^-1") == .value(.number(r(1, 2))))
        #expect(last("5'^0") == .value(.number(r(1))))
    }

    @Test func powersBindTighterThanMinusAndTimes() {
        #expect(last("-2^2") == .value(.number(r(-4))))
        #expect(last("3 * 2^2") == .value(.number(r(12))))
    }

    @Test func superscriptTwoAfterAVariable() {
        #expect(last("deck = 12'\ndeck²") == .value(Quantity(value: r(20736), dimension: .area)))
        #expect(last("deck = 12'\ndeck³") == .value(Quantity(value: r(144 * 144 * 144), dimension: .volume)))
    }

    @Test func onlyWholeNumberPowers() {
        #expect(message("2^0.5") == "Powers must be whole numbers")
        #expect(message("2^1'") == "Powers must be whole numbers")
        #expect(message("2^99") == "Number too large to work out exactly")
    }
}

@Suite struct VariableNameTests {
    @Test func namesCanHaveSpaces() {
        #expect(last("king stud = 8'9\"\nking stud - 2\"") == length(103))
        #expect(SheetEvaluator.evaluate("king stud = 8'9\"")[0]
            == .assignment("king stud", Quantity(value: r(105), dimension: .length)))
    }

    @Test func namesIgnoreCase() {
        #expect(last("deck = 12'\nDeck") == length(144))
        #expect(last("King Stud = 8'\nking stud") == length(96))
    }

    @Test func multiWordNamesStillMultiplyAndConvert() {
        #expect(last("top plate = 3'\ntop plate x 2") == length(72))
        #expect(last("top plate = 3'\n2 * top plate") == length(72))
        #expect(last("top plate = 3'\ntop plate * 2") == length(72))
        guard case .value(let q) = last("top plate = 1\"\ntop plate to mm") else { Issue.record("no value"); return }
        #expect(q.displayUnit?.symbol == "mm")
    }

    @Test func underscoresStillWork() {
        #expect(last("bottom_plate=88\"\nbottom_plate - 2\"") == length(86))
    }

    @Test func anUnknownMultiWordNameSaysItsWholeName() {
        #expect(message("king stud") == "Unknown: king stud")
    }
}

@Suite struct TotalInchesTests {
    @Test func feetAndInchesAlsoShowTotalInches() throws {
        #expect(try primary("88\"") == FormattedValue(text: "7' 4\" (88\")", isExact: true))
        #expect(try primary("-14\"") == FormattedValue(text: "-1' 2\" (-14\")", isExact: true))
        #expect(try primary("1220 mm") == FormattedValue(text: "4' 0 1/16\" (48 1/16\")", isExact: false))
    }

    @Test func typedInchesComeOutAsFeetAndInches() throws {
        #expect(try primary("108\"") == FormattedValue(text: "9' 0\" (108\")", isExact: true))
    }

    @Test func askingForInchesAlsoShowsFeetAndInches() throws {
        #expect(try primary("4' in in") == FormattedValue(text: "48\" (4' 0\")", isExact: true))
        #expect(try primary("6\" in in") == FormattedValue(text: "6\"", isExact: true))
    }

    @Test func underAFootIsJustInches() throws {
        #expect(try primary("9 1/2\"") == FormattedValue(text: "9 1/2\"", isExact: true))
    }

    @Test func feetInchesAloneIsStillAnAlternate() throws {
        guard case .value(let q) = last("88\"") else { Issue.record("no value"); return }
        let alternates = try ResultFormatter.format(q, precision: .sixteenth).alternates
        #expect(alternates.contains(FormattedValue(text: "7' 4\"", isExact: true)))
        #expect(alternates.contains(FormattedValue(text: "88\"", isExact: true)))
    }
}
