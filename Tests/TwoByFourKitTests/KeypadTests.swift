import Foundation
import Testing
@testable import TwoByFourKit

/// Keys go through `Keypad.apply` and then the engine, so these check what
/// the iPhone keypad types and the answer that text gets.
@Suite struct KeypadTests {
    /// Presses `keys` into an empty line, cursor always at the end.
    func type(_ keys: [KeypadKey]) -> String {
        var text = ""
        var selection = NSRange(location: 0, length: 0)
        for key in keys {
            (text, selection) = Keypad.apply(key, to: text, selection: selection)
        }
        return text
    }

    func answer(_ text: String) -> String? {
        NotepadModel.rows(for: text, precision: .sixteenth).first?.display.label
    }

    @Test func subtractingAFractionIsNotAMixedNumber() {
        let text = type([.digit(4), .digit(7), .space, .digit(3), .slash, .digit(1), .digit(6), .inches,
                         .minus, .digit(1), .slash, .digit(8), .inches])
        #expect(text == "47 3/16\" − 1/8\"")
        #expect(answer(text) == answer("47 3/16\" - 1/8\""))
        #expect(answer(text) != answer("47 3/16\""))
    }

    @Test func feetMinusMixedInches() {
        let text = type([.digit(1), .digit(6), .feet, .minus, .digit(3), .space, .digit(1), .slash, .digit(2), .inches])
        #expect(text == "16' − 3 1/2\"")
        #expect(answer(text) == answer("16' - 3 1/2\""))
    }

    @Test func boardKeyMakesABoardNameAndTimesMultiplies() {
        #expect(type([.digit(2), .board, .digit(1), .digit(0)]) == "2x10")
        let times = type([.digit(2), .times, .digit(1), .digit(0)])
        #expect(times == "2 × 10")
        #expect(answer(times) == answer("20"))
    }

    @Test func unaryMinusHasNoSpaces() {
        #expect(type([.minus, .digit(5)]) == "−5")
        #expect(type([.openParen, .minus, .digit(5)]) == "(−5")
    }

    @Test func spaceIsNeverDoubled() {
        #expect(type([.digit(9), .space, .space]) == "9 ")
        #expect(type([.digit(9), .space, .plus]) == "9 + ")
    }

    @Test func keysInsertAtTheCursorAndReplaceTheSelection() {
        let r = Keypad.apply(.digit(5), to: "12 + 34", selection: NSRange(location: 1, length: 0))
        #expect(r.text == "152 + 34" && r.selection == NSRange(location: 2, length: 0))
        let s = Keypad.apply(.digit(9), to: "12 + 34", selection: NSRange(location: 5, length: 2))
        #expect(s.text == "12 + 9" && s.selection == NSRange(location: 6, length: 0))
    }

    @Test func deleteRemovesOneCharacterOrTheSelection() {
        #expect(Keypad.apply(.delete, to: "12", selection: NSRange(location: 2, length: 0)).text == "1")
        #expect(Keypad.apply(.delete, to: "12", selection: NSRange(location: 0, length: 0)).text == "12")
        #expect(Keypad.apply(.delete, to: "1234", selection: NSRange(location: 1, length: 2)).text == "14")
        #expect(Keypad.apply(.delete, to: "a👍", selection: NSRange(location: 3, length: 0)).text == "a")
    }

    @Test func operatorAfterNewlineIsAtLineStart() {
        #expect(type([.digit(1), .newline, .minus, .digit(2)]) == "1\n−2")
    }

    @Test func smartQuotesFromTheSystemKeyboardAnswerTheSame() {
        #expect(answer("8’ 9”") == answer("8' 9\""))
    }
}
