# twoByFour spec

Everything twoByFour understands, with examples. **New features go here
first, then get built.** Each example block is a sheet: lines run top to
bottom, so a variable set in one line works in the lines below it. A line
written `input → answer` must show exactly that answer on the right; the
test `SpecTests` checks every one, so this page can't drift from the app.
Answers round to 1/16" unless a block says otherwise.

Features not built yet are listed under [Planned](#planned).

## Numbers

Whole numbers, decimals, fractions and mixed numbers, all kept exact.

```twobyfour
12            → 12
2.5           → 2.5
3/8           → 0.375
9 1/2         → 9.5
9-1/2         → 9.5
1/3           → ≈ 0.333
```

A mixed number is a whole number, one space (or a dash) and a fraction:
`47 3/16`. To subtract, put spaces around the minus: `47 - 3/16`.

## Lengths

Feet and inches, written the way a carpenter does. `'` is feet, `"` is
inches; `ft`, `feet`, `in`, `inch` and `inches` work too.

```twobyfour
105"          → 8' 9" (105")
8' 9"         → 8' 9" (105")
8'9"          → 8' 9" (105")
8' 9          → 8' 9" (105")
8'-6"         → 8' 6" (102")
8' 9 1/2"     → 8' 9 1/2" (105 1/2")
9 1/2"        → 9 1/2"
```

A length a foot or longer shows feet and inches with the total inches after
it. Under a foot it's just inches. When the column is too narrow for both,
it shows only the feet and inches.

Metric and other lengths: `mm`, `cm`, `m`, `km`, `yd`, `mi`.

```twobyfour
1220 mm       → ≈ 4' 0 1/16" (48 1/16")
2 m           → ≈ 6' 6 3/4" (78 3/4")
3 yd          → 9' 0" (108")
```

## Rounding and `≈`

Lengths round to the nearest mark on a tape: 1/2", 1/4", 1/8", 1/16"
(the default), 1/32" or 1/64", chosen per sheet. A rounded answer starts
with `≈`; an answer without one is exact. Rounding happens once, at the
end, so `10' / 3` is exactly 3' 4".

```twobyfour
10' / 3       → 3' 4" (40")
100" / 3      → ≈ 2' 9 5/16" (33 5/16")
11' 11 31/32" → ≈ 12' 0" (144")
```

## Math

`+`, `-`, `*` (or `×`, or `x` with spaces), `/` (or `÷`), parentheses, and
`^` for whole-number powers. Lengths multiply into areas and volumes.

```twobyfour
8' 9" + 3' 4 1/2"        → 12' 1 1/2" (145 1/2")
12' - 3 1/2"             → 11' 8 1/2" (140 1/2")
3' 6" * 2                → 7' 0" (84")
3' 6" x 2                → 7' 0" (84")
16' / 4                  → 4' 0" (48")
(8' + 4') / 2            → 6' 0" (72")
12' * 10'                → 120 sq ft
12'^2                    → 144 sq ft
2' * 3' * 4'             → 24 cu ft
2^3                      → 8
-2^2                     → -4
```

Mixing kinds that don't add up is an error, never a guess:

```twobyfour
5' + 3 lb                → Can't add length and weight
2^0.5                    → Powers must be whole numbers
1' / 0                   → Can't divide by zero
```

## Converting

`in`, `to` or `as` and a unit shows the answer in that unit. Asking for
inches also shows feet and inches.

```twobyfour
105" in m                → 2.667 m
105" to mm               → 2667 mm
4' in in                 → 48" (4' 0")
1 gal in L               → ≈ 3.785 L
10 stone in kg           → ≈ 63.503 kg
```

Tapping (or clicking) an answer lists it in the other units: inches,
feet-inches, meters, centimeters and millimeters for a length. Tap one to
copy it.

## Areas, volumes, weights and angles

| Kind | Units |
|---|---|
| Area | `sq in`, `sq ft`, `sq yd`, `m²`, `acre` (also `ft²`, `sqft`, `square feet`, …) |
| Volume | `cu in`, `cu ft`, `cu yd`, `m³`, `L`, `mL`, `gal`, `qt`, `cup`, `fl oz` |
| Weight | `lb`, `oz`, `kg`, `g`, `st` (stone), `ton` |
| Angle | `°`, `deg`, `degrees` |

```twobyfour
120 sq ft in m²          → ≈ 11.148 m²
27 cu ft in cu yd        → 1 cu yd
10 stone                 → 140 lb
45°                      → 45°
```

## Variables

Name a value with `=` and use it in the lines below. Names can be several
words and ignore case.

```twobyfour
deck = 12'               → 12' 0" (144")
deck * deck              → 144 sq ft
deck^2                   → 144 sq ft
deck²                    → 144 sq ft
Deck - 3 1/2"            → 11' 8 1/2" (140 1/2")
king stud = 8' 9"        → 8' 9" (105")
king stud - 1 1/2"       → 8' 7 1/2" (103 1/2")
bottom_plate = 88"       → 7' 4" (88")
```

A variable only reaches the lines below it, and changing it updates every
line that uses it. A unit's name can't be a variable (`m = 3` → "m is a
unit").

## Comments

A line starting with `#` or `//` is a note. A `#` after a space ends the
math on that line, and the rest is a note.

```twobyfour
# The back deck
joist = 12'              → 12' 0" (144")
joist * 2 # both sides   → 24' 0" (288")
```

`#` touching a number (`#10`) isn't a comment: it's saved for screw sizes.

## Sheets

Each sheet is a named notepad with its own rounding. Sheets save as you
type. On the Mac, sheets are listed in the sidebar; on iPhone, under the
list button. Rename and delete from there.

## Mac

- A normal window, brought forward from anywhere with **⌃⌥Space**.
- Updates itself. **Settings → Every beta** follows every build of `main`;
  **twoByFour → Try a Build…** runs a pull request's preview build.
- **Help → Send Logs…** sends the open sheet, its answers and the recent log
  to the developer; **Help → Copy Debug Report** copies the same text.

## iPhone

- A carpenter keypad instead of the keyboard: digits, `'` and `"`, fraction
  slash, space, the operators (which bring their own spaces, so
  `47 3/16" − 1/8"` subtracts), parentheses, `=`, an `x` key for board
  names, and delete that repeats when held. `abc` switches to letters for
  variable names; Return or `123` comes back.
- Builds arrive through TestFlight.
- **More → Send Logs…** and **Copy Debug Report**, as on the Mac.

## Planned

Not built yet. Each gets its section above, with examples, when it's next.

- **Real board sizes.** `2x4` is 1 1/2" × 3 1/2". On its own in math it means
  its thickness: `30" - 2x4` → 28 1/2", `16x 2x4` → 24". The answer says
  which dimension it used. Also plywood (`3/4 ply` is 23/32"), nails (`16d`)
  and pipe (`1/2" NPT`).
- **Rise and run.** `15 rise 12 run`: the angle, the pitch and the diagonal.
- **Carpenter rules of thumb** for spans and spacing.
- **Fasteners**: `#9 x 2 1/2"` screws and the like.
- **Lookups** for units twoByFour doesn't know, flagged until confirmed.
- **Images** attached to sheets.
- **Agents** reading sheets and their variables.
- **Sync** between the Mac and iPhone.
