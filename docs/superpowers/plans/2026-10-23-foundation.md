# twoByFour Foundation Implementation Plan (Plan 1 of 4)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A working, self-updating Mac notepad calculator that does exact feet-inch-fraction/metric math with variables, released through fwd-style CI, betas and PR preview builds.

**Architecture:** SwiftPM package (no Xcode project). `TwoByFourEngine` (UI-free, iOS-shareable) does lexing, parsing, exact rational evaluation and formatting. `TwoByFourKit` holds Mac-only logic (sheet storage, updater) so it's testable. The `twobyfour` executable is the SwiftUI/AppKit app. `make app` bundles and ad-hoc signs it; GitHub Actions publishes betas, releases and `pr-<n>` previews; the in-app updater (ported from fwd) installs them.

**Tech Stack:** Swift 6.3 (Command Line Tools, no Xcode), Swift Testing, SwiftUI + AppKit (TextKit 1), Carbon hot keys, GitHub Actions `macos-26`, `gh`.

**Spec:** `docs/superpowers/specs/2026-10-23-twobyfour-design.md`

**Later plans (not this one):** 2 — fake-size library (lumber, sheet goods, fasteners, plumbing, `2x4` in arithmetic, trust levels); 3 — rules of thumb (adds approximate numbers); 4 — Claude fallback Worker + D1 + client.

## Global Constraints

- macOS 26.0 minimum (`platforms: [.macOS("26.0")]`, `LSMinimumSystemVersion` 26.0).
- Display name `twoByFour`; bundle `twoByFour.app`; executable `twobyfour`; bundle ID `io.github.kylefritz.twobyfour`; release asset `twoByFour.zip`; repo `kylefritz/twobyfour` (public, MIT).
- Engine target imports only Foundation. No AppKit/SwiftUI in `TwoByFourEngine`.
- All engine math is exact `Rational` (Int64 numerator/denominator). Overflow throws, never traps.
- `=` only when the displayed value is exact; otherwise `≈`. Default precision 1/16"; per-sheet choices 1/2, 1/4, 1/8, 1/16, 1/32, 1/64.
- Rounding: nearest, ties away from zero, for both fractions and decimals.
- Decimal displays: at most 3 decimals, trailing zeros trimmed.
- Comment lines start with `//` or `# ` (hash + space). `#9` is not a comment (Plan 2 fastener).
- Tests: Swift Testing; `make test` must pass with Command Line Tools only (copy fwd's `CLT_FW` flags).
- Base units in the engine: inch, pound, degree (all SI factors exact: 1 in = 25.4 mm, 1 lb = 0.45359237 kg).

## Review Focus

1. **Smart quotes and Unicode operators** — macOS turns `'`/`"` into `’`/`”`, and people type `×`, `−`, `÷`, `′`, `″`. Expect identical results. (Task 4 lexer test; Task 9 disables substitution.)
2. **Rounding carry and negatives** — `11' 11 31/32"` at 1/16 must show `≈ 12' 0"`, never `11' 12"`; `-3/32"` shows `≈ -1/8"`. (Task 7.)
3. **Overflow** — long chains of tiny metric decimals (`0.0001 mm * 999999999 * 999999999`) must give an error line, not crash. (Task 2, Task 6.)
4. **Dimension mismatch and divide by zero** — `5' + 3 lb` → "Can't add length and weight"; `1' / 0` → "Can't divide by zero". (Task 6.)
5. **Variable order** — a variable used above its definition is unknown there; reassignment affects only lines below; `m = 3` is rejected ("m is a unit"). (Task 6.)

---

### Task 1: Package scaffold

**Files:**
- Create: `Package.swift`, `Makefile`, `LICENSE` (MIT, Kyle Fritz, 2026), `README.md` (short: what it is, `make test`, `make app`, install note), `Sources/TwoByFourEngine/Engine.swift` (placeholder `public enum Engine { public static let name = "twoByFour" }`), `Sources/TwoByFourKit/Kit.swift` (placeholder), `Sources/twobyfour/main.swift` (prints name), `Tests/TwoByFourEngineTests/SmokeTests.swift`, `Tests/TwoByFourKitTests/SmokeTests.swift`
- Modify: `.gitignore` (add `.build/`, `build/`)

**Interfaces:** Produces targets `TwoByFourEngine`, `TwoByFourKit` (depends on engine), executable `twobyfour` (depends on both), test targets for engine and kit. `swiftLanguageModes: [.v5]` as fwd.

- [ ] Step 1: Write `Package.swift`, Makefile (copy fwd's: `build`, `test` with CLT flags, `app` → `scripts/bundle.sh`, `install` to `/Applications/twoByFour.app`, `clean`) and smoke tests asserting `Engine.name == "twoByFour"`.
- [ ] Step 2: Run `make test` → PASS. Run `make build` → succeeds.
- [ ] Step 3: Commit `Scaffold the Swift package`.

### Task 2: Rational

**Files:** Create `Sources/TwoByFourEngine/Rational.swift`; Test `Tests/TwoByFourEngineTests/RationalTests.swift`

**Interfaces:**
- Produces: `public struct Rational: Hashable, Comparable, Sendable { public let numerator: Int64; public let denominator: Int64 }` always reduced, denominator > 0. `init(_ n: Int64, _ d: Int64 = 1) throws`; `static func parse(decimal: String) throws -> Rational` (`"2.667"` → 2667/1000); `+ - * /` as `throws` functions `adding(_:)`, `subtracting(_:)`, `multiplied(by:)`, `divided(by:)`; `negated`; `isZero`; `isNegative`; `doubleValue`; `func rounded(toMultipleOf step: Rational) throws -> Rational` (nearest, ties away from zero); `wholePart: Int64` (truncating).
- `public enum EngineError: Error, Equatable` — start with `.overflow`, `.divideByZero`; later tasks add cases.

- [ ] Step 1: Tests: `1/2 + 1/3 == 5/6`; `Rational(6, -4) == Rational(-3, 2)`; `parse(decimal: "2.667") == 2667/1000`; `parse(decimal: "-0.5") == -1/2`; divide by zero throws `.divideByZero`; `Rational(Int64.max).multiplied(by: 2)` throws `.overflow`; `(31/32).rounded(toMultipleOf: 1/16) == 1` (tie away); `(-3/32).rounded(toMultipleOf: 1/16) == -1/8`; `(1/3).rounded(toMultipleOf: 1/16) == 5/16`.
- [ ] Step 2: Run `make test` → new tests FAIL.
- [ ] Step 3: Implement with `multipliedReportingOverflow`/`addingReportingOverflow`, gcd-reducing before multiplying (cross-cancel) to delay overflow.
- [ ] Step 4: `make test` → PASS. Commit `Exact rational numbers`.

### Task 3: Units, dimensions, quantities

**Files:** Create `Sources/TwoByFourEngine/Units.swift`, `Sources/TwoByFourEngine/Quantity.swift`; Test `Tests/TwoByFourEngineTests/UnitsTests.swift`

**Interfaces:**
- `public struct Dimension: Hashable, Sendable { public var length: Int8; public var mass: Int8; public var angle: Int8 }` with statics `.none, .length, .area, .volume, .mass, .angle`, `multiplied(by:)`, `divided(by:)`, and `name` (`"length"`, `"area"`, `"volume"`, `"weight"`, `"angle"`, `"number"`, else `"length^3·weight"`-style).
- `public struct Unit: Hashable, Sendable { public let symbol: String; public let dimension: Dimension; public let toBase: Rational }` (base: inch / pound / degree, area in², volume in³).
- `public enum Units { public static func lookup(_ word: String) -> Unit?; public static let all: [Unit] }` — words (case-insensitive except `m`/`M` not needed; treat lowercase): length `in inch inches " ″ ”`, `ft foot feet ' ′ ’`, `yd yard yards`, `mi mile miles`, `mm`, `cm`, `m meter meters metre metres`, `km`; area `sqin sq in in² in2`, `sqft sq ft ft² ft2 square feet`, `sqyd yd² sq yd`, `m² m2 sqm`, `acre acres` (43560 ft²); volume `cuin in³ in3 cu in`, `cuft ft³ ft3 cu ft`, `cuyd yd³ yd3 cu yd yards³`, `m³ m3`, `l L liter liters litre litres` (1 L = 1000/16.387064 in³), `ml mL`, `gal gallon gallons` (231 in³), `qt quart quarts` (231/4), `cup cups` (231/16), `floz fl oz` (231/128); mass `lb lbs pound pounds`, `oz ounce ounces` (1/16), `kg` (1/0.45359237), `g gram grams`, `st stone stones` (14), `ton tons` (2000); angle `° deg degree degrees`. Multi-word forms (`sq ft`, `cu yd`, `fl oz`, `square feet`) are matched by the lexer (Task 4) and passed here joined by one space.
- `public struct Quantity: Equatable, Sendable { public var value: Rational /* in base units */; public var dimension: Dimension; public var displayUnit: Unit? /* unit the user asked to see, from `in`/`to` */ }` with throwing `adding`, `subtracting` (require equal dimension, else `EngineError.mismatch(String, String)` using `Dimension.name`), `multiplied`, `divided`, `negated`, and `converted(to: Unit) throws -> Quantity` (dimension must match, else `.cannotConvert(String, String)`).

- [ ] Step 1: Tests: `1 ft` base = 12; `1 m` base = 5000/127; `1 gal` base = 231; `1 L` in in³ = 1000/16.387064 exactly; `10 st` base = 140; `1 kg` base = 100000000/45359237; `2 ft × 3 ft` dimension `.area`, value 864; `5 ft + 3 lb` throws `.mismatch("length", "weight")`; `ft / ft` dimension `.none`; `Units.lookup("’")` == foot; `Units.lookup("”")` == inch.
- [ ] Step 2: Run → FAIL. Step 3: Implement. Step 4: `make test` → PASS. Commit `Units and quantities`.

### Task 4: Lexer

**Files:** Create `Sources/TwoByFourEngine/Lexer.swift`; Test `Tests/TwoByFourEngineTests/LexerTests.swift`

**Interfaces:** `public enum Token: Equatable { case number(Rational), unit(String) /* canonical lookup key */, ident(String), nominal(String) /* "2x4" */, plus, minus, times, divide, lparen, rparen, equals, end }`; `public func lex(_ line: String) throws -> [Token]` (throws `EngineError.unexpected(String)`).

Rules (the part the tests don't fully determine):
- Normalize first: `’ ′` → `'`, `” ″ “` → `"`, `−` → `-`, `×` → `*`, `÷` → `/`.
- Numeric literals, longest match: mixed `9 1/2` (one space) and `9-1/2` (hyphen, no spaces) → one `.number(19/2)`; fraction `1/2` (no spaces around `/`) → `.number`; decimal `2.667`, `.5`; integer. `10' / 3` keeps `/` as `.divide` because of the spaces.
- `\d+x\d+` with no spaces → `.nominal("2x4")` (Plan 2 resolves it; Plan 1 evaluator errors).
- `x` surrounded by spaces between operands → `.times` (lexer emits `.ident("x")`; parser decides by position).
- Words: try two-word unit phrases first (`sq ft`, `cu yd`, `fl oz`, `square feet`, …) via `Units.lookup`, then single words; unit symbols `' "` `°` `²` `³` attach to the preceding token as units.

- [ ] Step 1: Tests: `8' 9 1/2"` → `[number 8, unit ', number 19/2, unit "]`; `8’9-1/2”` same tokens; `10' / 3` → `[number 10, unit ', divide, number 3]`; `2 × 4` → `[number 2, times, number 4]`; `2x4` → `[nominal "2x4"]`; `12 sq ft` → `[number 12, unit "sq ft"]`; `wall = 12' 6"` starts `[ident wall, equals, …]`; `1220 mm in ft` → `[number 1220, unit mm, unit in, unit ft]` — **the lexer emits `in` as `.unit("in")`; the parser reinterprets it as a conversion keyword by position**; `5 $` throws `.unexpected("$")`.
- [ ] Step 2: FAIL. Step 3: Implement. Step 4: PASS. Commit `Lexer`.

### Task 5: Parser

**Files:** Create `Sources/TwoByFourEngine/Parser.swift`; Test `Tests/TwoByFourEngineTests/ParserTests.swift`

**Interfaces:** `public indirect enum Expr: Equatable { case number(Rational), quantity(Rational, String /* unit key */), variable(String), nominal(String), negate(Expr), binary(Op, Expr, Expr), convert(Expr, String /* unit key */) }`, `public enum Op { case add, subtract, multiply, divide }`; `public enum Statement: Equatable { case expression(Expr), assignment(String, Expr) }`; `public func parse(_ tokens: [Token]) throws -> Statement`.

Grammar (Pratt), lowest to highest: conversion (`in`/`to`/`as` followed by a unit, postfix on the whole expression) < `+ -` < `* /` (and `x` ident in infix position) < unary `-` < primary. Primary: number optionally followed by a unit; **juxtaposed length quantities in descending size are summed** (`8' 9"`, `8ft 9in`, `1m 20cm`) into one `binary(.add, …)`; `( expr )`; ident; nominal.
- `in` after a bare number is the inch unit unless the following token is a unit (then: `9.5 in mm` = 9.5 inches converted to mm).
- Assignment: `ident = expr` only at line start; a unit word as the name throws `.reservedName(name)`.

- [ ] Step 1: Tests: `8' 9"` → `binary(.add, quantity(8,"ft"), quantity(9,"in"))`; `wall - 2 * 3"` precedence; `105" in m` → `convert(quantity(105,"in"), "m")`; `9.5 in mm` → `convert(quantity(19/2,"in"),"mm")`; `9.5 in` → `quantity(19/2,"in")`; `2 x 4` → multiply; `x = 3` → assignment `x`; `m = 3` throws `.reservedName("m")`; `(1 + 2` throws `.unexpected("end of line")`; `-3/32"` → `negate(quantity(3/32,"in"))`.
- [ ] Step 2: FAIL. Step 3: Implement. Step 4: PASS. Commit `Parser`.

### Task 6: Evaluator and sheets

**Files:** Create `Sources/TwoByFourEngine/Evaluator.swift`, `Sources/TwoByFourEngine/SheetEvaluator.swift`; Test `Tests/TwoByFourEngineTests/EvaluatorTests.swift`, `Tests/TwoByFourEngineTests/SheetEvaluatorTests.swift`

**Interfaces:**
- `public struct Environment { public var variables: [String: Quantity] }`; `public func evaluate(_ expr: Expr, in env: Environment) throws -> Quantity`.
- New `EngineError` cases: `.unknownTerm(String)` (unknown identifier — Plan 4's hook), `.unknownSize(String)` (nominal in Plan 1), `.mismatch`, `.cannotConvert`, `.reservedName`, `.unexpected`. `EngineError.message: String`: mismatch → `"Can't add length and weight"` (subtract → "subtract"), divideByZero → `"Can't divide by zero"`, overflow → `"Number too large to compute exactly"`, unknownTerm → `"Unknown: cubits"`, unknownSize → `"Unknown size: 2x4"`, cannotConvert → `"Can't convert length to weight"`, reservedName → `"m is a unit"`.
- `public enum LineOutcome: Equatable { case blank, comment, value(Quantity), assignment(String, Quantity), error(EngineError) }`; `public enum SheetEvaluator { public static func evaluate(_ text: String) -> [LineOutcome] }` — one outcome per `\n`-separated line, top to bottom, assignments visible only to later lines, errors never stop later lines.

- [ ] Step 1: Tests (values in base inches unless noted): `10' / 3` = 40; `wall = 12' 6"` then `wall - 3"` = 147; `2' * 3'` area 864; `5' + 3 lb` error message `"Can't add length and weight"`; `1' / 0` → `"Can't divide by zero"`; `0.0001 mm * 999999999 * 999999999` → overflow message (no crash); sheet `"a + 1\"\na = 2\"\na\na = 3\"\na"` → `[error unknownTerm a, assignment, value 2, assignment, value 3]`; `// note` and `# note` → comment; `#9` → not comment (error unknownTerm/unexpected is fine in Plan 1); `""` → blank; `10 stone` → value 140 lb-dimension.
- [ ] Step 2: FAIL. Step 3: Implement. Step 4: PASS. Commit `Evaluate lines and sheets`.

### Task 7: Formatter

**Files:** Create `Sources/TwoByFourEngine/Formatter.swift`; Test `Tests/TwoByFourEngineTests/FormatterTests.swift`

**Interfaces:**
- `public enum Precision: Int, CaseIterable, Codable, Sendable { case half = 2, quarter = 4, eighth = 8, sixteenth = 16, thirtySecond = 32, sixtyFourth = 64 }` with `label` (`"1/16\""`).
- `public struct FormattedValue: Equatable, Sendable { public let text: String; public let isExact: Bool }`; `public struct FormattedResult: Equatable, Sendable { public let primary: FormattedValue; public let alternates: [FormattedValue] }`.
- `public enum ResultFormatter { public static func format(_ q: Quantity, precision: Precision) throws -> FormattedResult; public static func feetInches(_ inches: Rational, precision: Precision) throws -> FormattedValue; public static func inches(_ inches: Rational, precision: Precision) throws -> FormattedValue; public static func decimal(_ value: Rational, unit: String) throws -> FormattedValue }`.

Display rules:
- Length primary: ft-in (`8' 9"`, `12' 3 1/2"`, `4' 0 1/32"`); under 12" in magnitude → inches only (`9 1/2"`, `0"`); negative → leading `-`. Round to precision **before** splitting feet so `11' 11 31/32"`@1/16 → `12' 0"`. Fractions reduced, ASCII (`1/2`). If `displayUnit` is set: `ft` → ft-in; `in` → inches; anything else → decimal in that unit. Alternates (excluding the primary's form): `in` (inches fraction), `m`, `cm`, `mm`, and ft-in.
- Area primary `sq ft`, alternates `sq in`, `m²`. Volume primary `cu ft`, alternates `cu yd`, `gal`, `L`. Weight primary `lb`, alternates `kg`, `oz`. Angle `°`. Dimensionless: decimal, no unit.
- Decimal: ≤3 decimals, ties away from zero, trailing zeros trimmed, `isExact` false if rounding changed the value; text is `"<n> <unit>"`.

- [ ] Step 1: Tests: `105"` → primary `8' 9"` exact, alternates contain `105"`, `2.667 m` exact, `266.7 cm` exact, `2667 mm` exact; `1220 mm` @1/32 → `4' 0 1/32"` inexact, @1/16 → `4' 0 1/16"` inexact; `40"` (10'/3) → `3' 4"` exact; `11' 11 31/32"` @1/16 → `12' 0"` inexact; `-3/32"` @1/16 → `-1/8"` inexact; `9.5"` → `9 1/2"`; `1220 mm in ft` (displayUnit ft) → ft-in; `10 stone` → `140 lb`, alt `63.503 kg` inexact; `1 gal` in L → `3.785 L` inexact; dimensionless `1/3` → `0.333` inexact.
- [ ] Step 2: FAIL. Step 3: Implement. Step 4: PASS. Commit `Format results for a tape measure`.

### Task 8: App shell — bundle, window, sheets

**Files:**
- Create: `scripts/bundle.sh` (from fwd: binary `.build/release/twobyfour`; no CLI; Info.plist with names/IDs from Global Constraints, `TwoByFourCommit`, `TwoByFourPreview`, no `LSUIElement`; icon via `twobyfour --write-iconset`; ad-hoc sign; zip `build/twoByFour.zip`), `Sources/TwoByFourKit/SheetStore.swift`, `Sources/twobyfour/App.swift` (replace `main.swift`), `Sources/twobyfour/SheetListView.swift`, `Sources/twobyfour/Icon.swift`
- Test: `Tests/TwoByFourKitTests/SheetStoreTests.swift`

**Interfaces:**
- `public struct Sheet: Codable, Identifiable, Equatable { public let id: UUID; public var name: String; public var text: String; public var precision: Precision; public var modified: Date }`.
- `@MainActor public final class SheetStore: ObservableObject { public init(directory: URL); @Published public private(set) var sheets: [Sheet] /* newest-modified first */; public func create(name: String = "Untitled") -> Sheet; public func update(_ sheet: Sheet); public func delete(id: UUID); }` — one JSON file per sheet `<id>.json`, atomic writes, unreadable files skipped (not deleted). App uses `~/Library/Application Support/twoByFour/Sheets`. First launch creates a "Scratch" sheet.
- App: `NavigationSplitView` — sidebar list (new via ⌘N and +, rename inline, delete via context menu), detail = `NotepadView` (Task 9; placeholder `TextEditor` until then); toolbar precision picker bound to `sheet.precision`.
- Icon: drawn in code (end grain of a board with "2×4" stamped), `--write-iconset <dir>` writes the iconset and exits.

- [ ] Step 1: Tests: create → file exists and reloads equal; update changes order; delete removes file; a corrupt `bad.json` in the folder is skipped and still present.
- [ ] Step 2: FAIL. Step 3: Implement store, then app + bundle script.
- [ ] Step 4: `make test` PASS; `make app` builds `build/twoByFour.app`; `codesign --verify --deep --strict build/twoByFour.app` passes; `open build/twoByFour.app` shows the window with a Scratch sheet.
- [ ] Step 5: Commit `App window with saved sheets`.

### Task 9: Notepad editor with aligned results and popover

**Files:** Create `Sources/TwoByFourKit/NotepadModel.swift`, `Sources/twobyfour/NotepadView.swift`, `Sources/twobyfour/NotepadTextView.swift`, `Sources/twobyfour/ResultPopover.swift`; Test `Tests/TwoByFourKitTests/NotepadModelTests.swift`; Create `docs/manual-checklist.md`

**Interfaces:**
- `public struct ResultRow: Equatable { public let line: Int; public let display: Display }` where `public enum Display: Equatable { case none, result(FormattedResult), error(String) }`; `public enum NotepadModel { public static func rows(for text: String, precision: Precision) -> [ResultRow] }` (wraps `SheetEvaluator` + `ResultFormatter`; assignments show their value; comments/blanks → `.none`).
- Editor: `NSViewRepresentable` around an `NSScrollView` + `NSTextView` (TextKit 1), monospaced 14pt, **automatic quote/dash/text substitution and spelling correction off**. Results are drawn in a right-aligned column: after each text change or resize, for each paragraph take the line fragment rect of its first glyph (`layoutManager.lineFragmentRect(forGlyphAt:effectiveRange:)`) and place that row's label at the same y; reserve a right text-container inset so text never runs under results. Primary shown as `text` when exact, `≈ text` otherwise; errors in secondary color.
- Clicking a result opens an `NSPopover` listing primary + alternates (each with `≈` when inexact); clicking an entry copies its text (without `≈`) to the pasteboard.
- Text changes save through `SheetStore.update` (debounced 0.5 s).

- [ ] Step 1: Tests: `rows(for: "105\"\n\n// hi\nwall = 12' 6\"\nwall - 3\"", precision: .sixteenth)` → `[result 8' 9", none, none, result 12' 6", result 12' 3"]`; `"5' + 3 lb"` → `error("Can't add length and weight")`.
- [ ] Step 2: FAIL. Step 3: Implement model, then views.
- [ ] Step 4: `make test` PASS. `make app && open build/twoByFour.app`; walk `docs/manual-checklist.md` (type each Review Focus input incl. smart quotes, long wrapped line keeps alignment, popover copies, precision change re-renders, quit/relaunch keeps text). Write the checklist as part of this step.
- [ ] Step 5: Commit `Live notepad with results and conversions popover`.

### Task 10: Global shortcut

**Files:** Create `Sources/twobyfour/HotKey.swift`; Modify `Sources/twobyfour/App.swift`

**Interfaces:** `final class HotKey { init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) }` using Carbon `RegisterEventHotKey` (no Accessibility permission needed). Default **⌃⌥Space**; action activates the app and brings the main window to the front (creating it if closed). Shown in the app menu as "Bring to Front: ⌃⌥Space" (informational).

- [ ] Step 1: Implement. Step 2: `make app`, open, switch to another app, press ⌃⌥Space → window in front; add to manual checklist. Step 3: Commit `Global shortcut brings the notepad forward`.

### Task 11: Updater and "Try a Build…"

**Files:** Create `Sources/TwoByFourKit/Updater.swift`, `Sources/TwoByFourKit/Shell.swift`, `Sources/TwoByFourKit/Log.swift`, `Sources/TwoByFourKit/AppInfo.swift`; `Sources/twobyfour/UpdateViews.swift`; Modify `App.swift`; Test `Tests/TwoByFourKitTests/UpdaterTests.swift`

**Interfaces / port rules:** Port `~/code/fwd/Sources/FwdCore/Updater.swift` (branch `pr-previews`, including `switchTo` and generation/`switchPending` logic) and its tests, with these changes:
- `AppInfo.repository = "kylefritz/twobyfour"`, `AppInfo.bundleIdentifier = "io.github.kylefritz.twobyfour"`, `Updater.assetName = "twoByFour.zip"`, user agent `twoByFour/<version>`.
- Drop Homebrew (`InstallKind` = `.release`, `.source`) and the stats ping.
- Channel from `UserDefaults` key `updateChannel` (`stable` default / `beta`), read at every check.
- `Shell.run` and `Log` (file `~/Library/Logs/twoByFour/twoByFour.log`) ported minimally from fwd.
- UI: banner at the bottom of the window for `.ready` ("Restart to update to X" + dismiss) and `.manual`; app menu "Check for Updates…"; **"Try a Build…"** sheet with a text field accepting `42`, `#42`, `pr-42`, `beta`, `stable` → `switchTo` → relaunch (fwd's `relaunch`); Settings scene with the channel picker; window footer shows version, and `PR #<n>` from `TwoByFourPreview` when set. Checks on launch and every 6 h.

- [ ] Step 1: Port tests (drop Homebrew/stats ones) → FAIL. Step 2: Port code → PASS. Step 3: `make app` and open: footer shows `dev`; "Try a Build…" with `999999` shows the "has no preview build" message. Step 4: Commit `Self-updater with beta channel and PR builds`.

### Task 12: Releases on GitHub

**Files:** Create `.github/workflows/ci.yml`, `beta.yml`, `release.yml`, `preview.yml`, `.github/release-notes.md`, `scripts/release.sh`

**Port rules:** Copy fwd's four workflows and `release.sh`, replacing `fwd` names with Global Constraints names. Bundle check becomes `test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' build/twoByFour.app/Contents/Info.plist)" = "$VERSION"` plus `codesign --verify --deep --strict`. Drop the Linux scan job, the stats Worker job, and the Homebrew tap step. Preview comment text: "**Try this build:** in twoByFour choose *Try a Build…* and enter `<n>` (<sha>, <version>). Enter `beta` to go back." Release notes: download/unzip/drag to Applications + `xattr -dr com.apple.quarantine /Applications/twoByFour.app`.

- [ ] Step 1: Write files; `actionlint` if installed, else `ruby -ryaml -e 'YAML.load_file ARGV[0]'` per file → no errors.
- [ ] Step 2: `gh repo create kylefritz/twobyfour --public --source . --remote origin --push` (Kyle approved public).
- [ ] Step 3: Watch `gh run watch` → CI green on main; Beta workflow publishes `v0.0.1-beta.<n>`.
- [ ] Step 4: Open a small PR (README tweak) → Preview publishes `pr-<n>` and comments. Close it after verifying the release exists.
- [ ] Step 5: Commit any fixes `Releases, betas and PR previews`.
