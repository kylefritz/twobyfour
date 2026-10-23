import Testing
@testable import TwoByFourEngine

private func r(_ n: Int64, _ d: Int64 = 1) -> Rational { try! Rational(n, d) }
private func q(_ n: Int64, _ word: String) -> Quantity { try! Quantity(r(n), Units.lookup(word)!) }

@Suite struct UnitsTests {
    @Test(arguments: [
        ("ft", r(12)), ("'", r(12)), ("’", r(12)), ("′", r(12)), ("feet", r(12)),
        ("in", r(1)), ("\"", r(1)), ("”", r(1)), ("″", r(1)),
        ("yd", r(36)), ("mm", r(5, 127)), ("cm", r(50, 127)), ("m", r(5000, 127)),
        ("gal", r(231)), ("qt", r(231, 4)),
        ("lb", r(1)), ("oz", r(1, 16)), ("st", r(14)), ("stone", r(14)),
        ("kg", r(100_000_000, 45_359_237)),
        ("sq ft", r(144)), ("acre", r(43560 * 144)), ("cu yd", r(46656)),
    ])
    func unitsKnowTheirSizeInBaseUnits(word: String, base: Rational) {
        #expect(Units.lookup(word)?.toBase == base)
    }

    @Test func aLiterIsExactlyAThousandCubicCentimeters() throws {
        // 1 in³ is exactly 16.387064 cm³.
        let liter = try #require(Units.lookup("L"))
        #expect(try liter.toBase == r(1000).divided(by: Rational.parse(decimal: "16.387064")))
        #expect(liter.dimension == .volume)
    }

    @Test func unknownWordsAreNotUnits() {
        #expect(Units.lookup("cubits") == nil)
        #expect(Units.lookup("wall") == nil)
    }

    @Test func multiplyingLengthsMakesArea() throws {
        let area = try q(2, "ft").multiplied(by: q(3, "ft"))
        #expect(area.dimension == .area)
        #expect(area.value == r(864))
    }

    @Test func dividingLikeQuantitiesGivesAPlainNumber() throws {
        let ratio = try q(6, "ft").divided(by: q(2, "ft"))
        #expect(ratio.dimension == .none)
        #expect(ratio.value == r(3))
    }

    @Test func addingDifferentKindsIsRefused() {
        #expect(throws: EngineError.mismatch("add", "length", "weight")) {
            try q(5, "ft").adding(q(3, "lb"))
        }
        #expect(throws: EngineError.mismatch("subtract", "length", "weight")) {
            try q(5, "ft").subtracting(q(3, "lb"))
        }
    }

    @Test func tenStoneIsOneHundredFortyPounds() {
        let stone = q(10, "stone")
        #expect(stone.dimension == .mass)
        #expect(stone.value == r(140))
    }

    @Test func convertingKeepsTheValueAndRemembersTheUnit() throws {
        let inMeters = try q(105, "in").converted(to: Units.lookup("m")!)
        #expect(inMeters.value == r(105))
        #expect(inMeters.displayUnit?.symbol == "m")
        #expect(throws: EngineError.cannotConvert("length", "weight")) {
            try q(105, "in").converted(to: Units.lookup("lb")!)
        }
    }
}
