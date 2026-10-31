import Foundation

/// The sheet twoByFour opens with the first time: a short tour that works
/// as it reads, so every line shows a real answer. Edit it freely.
/// docs/SPEC.md has the full list of what twoByFour understands.
public enum GettingStarted {
    public static let name = "Getting Started"

    public static let text = """
    # Welcome!
    # Math on the
    # left, answers
    # on the right.
    # Tap an answer
    # to see more.

    # Feet & inches
    8' 9 1/2" + 3'
    105"
    47 3/16" - 1/8"

    # Exact math
    10' / 3
    100" / 3

    # Name things
    wall = 12' 6"
    king stud = 92"
    wall - 3 1/2"
    king stud * 2

    # Areas & units
    wall * 8'
    3' * 4' * 6"
    1220 mm
    105" in m
    10 stone in kg

    # Notes after #
    rim = 16' # deck
    rim^2

    # Make a sheet
    # of your own
    # next.
    """
}

extension SheetStore {
    /// The sheet to start with when there are none: the guide the first
    /// time, an empty Scratch sheet after that.
    @discardableResult
    public func createFirstSheet(guide: Bool) -> Sheet {
        var sheet = create(name: guide ? GettingStarted.name : "Scratch")
        if guide {
            sheet.text = GettingStarted.text
            update(sheet)
        }
        return sheet
    }
}
