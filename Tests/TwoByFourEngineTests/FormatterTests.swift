import Testing
@testable import TwoByFourEngine

private func r(_ a: Int64, _ b: Int64 = 1) -> Rational { try! Rational(a, b) }
private func exact(_ s: String) -> FormattedValue { FormattedValue(text: s, isExact: true) }
private func approx(_ s: String) -> FormattedValue { FormattedValue(text: s, isExact: false) }

/// Formats the single line `line` the way the notepad would.
private func show(_ line: String, _ precision: Precision = .sixteenth) throws -> FormattedResult {
    guard case .value(let q) = SheetEvaluator.evaluate(line)[0] else {
        Issue.record("\(line) didn't evaluate")
        throw EngineError.overflow
    }
    return try ResultFormatter.format(q, precision: precision)
}

@Suite struct FormatterTests {
    @Test func oneHundredFiveInches() throws {
        let result = try show("105\"")
        #expect(result.primary == exact("8' 9\""))
        #expect(result.alternates.contains(exact("105\"")))
        #expect(result.alternates.contains(exact("2.667 m")))
        #expect(result.alternates.contains(exact("266.7 cm")))
        #expect(result.alternates.contains(exact("2667 mm")))
        #expect(!result.alternates.contains(result.primary))
    }

    @Test func metricRoundsToTheChosenFraction() throws {
        #expect(try show("1220 mm", .thirtySecond).primary == approx("4' 0 1/32\""))
        #expect(try show("1220 mm", .sixteenth).primary == approx("4' 0 1/16\""))
    }

    @Test func tenFeetInThreesIsExact() throws {
        #expect(try show("10' / 3").primary == exact("3' 4\""))
    }

    @Test func roundingCarriesIntoTheNextFoot() throws {
        #expect(try show("11' 11 31/32\"").primary == approx("12' 0\""))
    }

    @Test func negativesRoundAwayFromZero() throws {
        #expect(try show("-3/32\"").primary == approx("-1/8\""))
        #expect(try show("-14\"").primary == exact("-1' 2\""))
    }

    @Test func underAFootShowsInchesOnly() throws {
        #expect(try show("9.5\"").primary == exact("9 1/2\""))
        #expect(try show("3/8\"").primary == exact("3/8\""))
        #expect(try show("0'").primary == exact("0\""))
    }

    @Test func askingForAUnitShowsThatUnit() throws {
        #expect(try show("1220 mm in ft", .thirtySecond).primary == approx("4' 0 1/32\""))
        #expect(try show("4' in in").primary == exact("48\""))
        #expect(try show("105\" in m").primary == exact("2.667 m"))
        #expect(try show("1\" in mm").primary == exact("25.4 mm"))
    }

    @Test func weightsVolumesAndAreas() throws {
        let stone = try show("10 stone")
        #expect(stone.primary == exact("140 lb"))
        #expect(stone.alternates.contains(approx("63.503 kg")))
        #expect(try show("1 gal in L").primary == approx("3.785 L"))
        let area = try show("2' * 3'")
        #expect(area.primary == exact("6 sq ft"))
        #expect(area.alternates.contains(exact("864 sq in")))
    }

    @Test func plainNumbers() throws {
        #expect(try show("1/3").primary == approx("0.333"))
        #expect(try show("6 / 2").primary == exact("3"))
        #expect(try show("1/8").primary == exact("0.125"))
    }

    @Test func precisionLabels() {
        #expect(Precision.sixteenth.label == "1/16\"")
        #expect(Precision.allCases.map(\.rawValue) == [2, 4, 8, 16, 32, 64])
    }
}
