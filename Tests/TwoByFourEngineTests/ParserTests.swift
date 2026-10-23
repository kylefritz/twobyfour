import Testing
@testable import TwoByFourEngine

private func r(_ a: Int64, _ b: Int64 = 1) -> Rational { try! Rational(a, b) }
private func q(_ a: Int64, _ b: Int64, _ unit: String) -> Expr { .quantity(r(a, b), unit) }
private func q(_ a: Int64, _ unit: String) -> Expr { .quantity(r(a), unit) }
private func p(_ line: String) throws -> Statement { try parse(lex(line)) }

@Suite struct ParserTests {
    @Test func feetAndInchesSideBySideAreAdded() throws {
        #expect(try p("8' 9\"") == .expression(.binary(.add, q(8, "ft"), q(9, "in"))))
        #expect(try p("8ft 9in") == .expression(.binary(.add, q(8, "ft"), q(9, "in"))))
        #expect(try p("1m 20cm") == .expression(.binary(.add, q(1, "m"), q(20, "cm"))))
    }

    @Test func aBareNumberAfterFeetIsInches() throws {
        #expect(try p("8' 9") == .expression(.binary(.add, q(8, "ft"), q(9, "in"))))
    }

    @Test func multiplicationBindsTighterThanSubtraction() throws {
        #expect(try p("wall - 2 * 3\"") ==
                .expression(.binary(.subtract, .variable("wall"), .binary(.multiply, .number(r(2)), q(3, "in")))))
    }

    @Test func spacedXMultiplies() throws {
        #expect(try p("2 x 4") == .expression(.binary(.multiply, .number(r(2)), .number(r(4)))))
    }

    @Test func conversions() throws {
        #expect(try p("105\" in m") == .expression(.convert(q(105, "in"), "m")))
        #expect(try p("105\" to mm") == .expression(.convert(q(105, "in"), "mm")))
        #expect(try p("9.5 in mm") == .expression(.convert(q(19, 2, "in"), "mm")))
        #expect(try p("9.5 in") == .expression(q(19, 2, "in")))
        #expect(try p("9.5 in in mm") == .expression(.convert(q(19, 2, "in"), "mm")))
        #expect(try p("(1' + 2') in in") == .expression(.convert(.binary(.add, q(1, "ft"), q(2, "ft")), "in")))
    }

    @Test func assignment() throws {
        #expect(try p("x = 3") == .assignment("x", .number(r(3))))
        #expect(try p("wall = 12' 6\"") == .assignment("wall", .binary(.add, q(12, "ft"), q(6, "in"))))
    }

    @Test func unitNamesCantBeVariables() {
        #expect(throws: EngineError.reservedName("m")) { try p("m = 3") }
    }

    @Test func negation() throws {
        #expect(try p("-3/32\"") == .expression(.negate(q(3, 32, "in"))))
    }

    @Test func boardNamesParse() throws {
        #expect(try p("2x4") == .expression(.nominal("2x4")))
    }

    @Test func incompleteLinesSaySo() {
        #expect(throws: EngineError.unexpected("end of line")) { try p("(1 + 2") }
        #expect(throws: EngineError.unexpected("end of line")) { try p("3 +") }
        #expect(throws: EngineError.unexpected(")")) { try p("3 )") }
    }
}
