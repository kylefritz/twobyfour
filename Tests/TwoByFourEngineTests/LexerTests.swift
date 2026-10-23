import Testing
@testable import TwoByFourEngine

private func n(_ a: Int64, _ b: Int64 = 1) -> Token { .number(try! Rational(a, b)) }

@Suite struct LexerTests {
    @Test func feetAndAMixedNumberOfInches() throws {
        #expect(try lex("8' 9 1/2\"") == [n(8), .unit("ft"), n(19, 2), .unit("in")])
    }

    @Test func smartQuotesAndHyphenatedFractionsLexTheSame() throws {
        #expect(try lex("8’9-1/2”") == [n(8), .unit("ft"), n(19, 2), .unit("in")])
        #expect(try lex("8′ 9″") == [n(8), .unit("ft"), n(9), .unit("in")])
    }

    @Test func aSlashWithSpacesIsDivision() throws {
        #expect(try lex("10' / 3") == [n(10), .unit("ft"), .divide, n(3)])
        #expect(try lex("1/2") == [n(1, 2)])
    }

    @Test func unicodeOperators() throws {
        #expect(try lex("2 × 4") == [n(2), .times, n(4)])
        #expect(try lex("8 − 3 ÷ 2") == [n(8), .minus, n(3), .divide, n(2)])
        #expect(try lex("−3/32\"") == [.minus, n(3, 32), .unit("in")])
    }

    @Test func boardNamesAreOneToken() throws {
        #expect(try lex("2x4") == [.nominal("2x4")])
        #expect(try lex("2 x 4") == [n(2), .ident("x"), n(4)])
    }

    @Test func twoWordUnits() throws {
        #expect(try lex("12 sq ft") == [n(12), .unit("sq ft")])
        #expect(try lex("3 square feet") == [n(3), .unit("sq ft")])
        #expect(try lex("8 fl oz") == [n(8), .unit("fl oz")])
        #expect(try lex("2 ft²") == [n(2), .unit("sq ft")])
    }

    @Test func assignments() throws {
        #expect(try lex("wall = 12' 6\"") == [.ident("wall"), .equals, n(12), .unit("ft"), n(6), .unit("in")])
    }

    @Test func inIsLexedAsTheInchUnit() throws {
        #expect(try lex("1220 mm in ft") == [n(1220), .unit("mm"), .unit("in"), .unit("ft")])
        #expect(try lex("105\" to m") == [n(105), .unit("in"), .ident("to"), .unit("m")])
    }

    @Test func decimals() throws {
        #expect(try lex("2.667 m") == [n(2667, 1000), .unit("m")])
        #expect(try lex(".5") == [n(1, 2)])
        #expect(try lex("(1 + 2)") == [.lparen, n(1), .plus, n(2), .rparen])
    }

    @Test func strangeCharactersAreRefused() {
        #expect(throws: EngineError.unexpected("$")) { try lex("5 $") }
    }
}
