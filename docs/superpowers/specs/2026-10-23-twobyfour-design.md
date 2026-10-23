# twoByFour — Design

*2026-10-23 · Kyle Fritz (owner) · drafted with Claude*

Items marked **(Claude's call)** were decided by Claude during the design conversation, not by Kyle. Everything else is Kyle's stated intent.

---

## 1. What this is, and why

twoByFour is a **native macOS notepad calculator for construction**, in the spirit of Soulver, built around one idea:

> **The trades are full of fake sizes.** A 2x4 is 1½" × 3½". ¾" plywood is 23/32". ½" NPT is 0.840" across. ¾" garden hose thread looks like ¾" pipe thread and isn't. twoByFour does feet-inch-fraction math fluently **and** decodes every misleading name — telling you what's really there and what actually fits together.

Kyle does **framing, decks, and finish carpentry** around the house. Today, nothing on the market combines native-Mac quality, fluent ft/in/fraction + metric math, nominal-size knowledge, and carpenter rules of thumb (see prior-art research: Construction Master Pro is iOS-only and keypad-based; Soulver/Numi know units but nothing about construction; the rest are single-purpose iOS fraction calculators).

**Audience:** Kyle first. Possibly sold later, so avoid choices that would block the App Store, but optimize every decision for one expert user now.

**The anti-goal (Kyle, verbatim intent): a wrong answer.** Correctness outranks speed, breadth, and polish. Every design choice below that touches accuracy should be read in that light.

## 2. Goals

1. **Notepad calculator.** A running, scrollable sheet: type expressions on the left, results appear live on the right (Soulver-style). Earlier lines stay; you can scroll back and build on them.
2. **Named variables.** `wall = 12' 6"` then `wall - 2 × 2x4` on a later line.
3. **Fluent units.** Feet-inch-fraction ↔ decimal inches ↔ metric. Also weight, area, volume, angle (e.g. `10 stone` is valid input).
4. **Fake-size library.** Nominal → actual for lumber, sheet goods, fasteners, plumbing threads/pipe/tube, with "what fits what" warnings.
5. **Carpenter rules of thumb** for framing, decks, and finish carpentry, always labeled as rules of thumb (not code).
6. **Unknown-input fallback via Claude.** Anything the app doesn't recognize is sent to a small server that asks Claude, returns a *structured* answer usable in math, and the app remembers it locally. The server logs every unknown so Kyle can grow the built-in library.

## 3. Non-goals (v1)

- **iOS app.** Planned next. v1 must keep the engine in a shared package so the iOS app reuses it, but no iOS UI is built now. (The engine is a UI-free Swift package so the iOS app can reuse it later.)
- **History sync between Mac and iPhone** (planned with the iOS app, via iCloud — requires paid Apple Developer membership).
- **LiDAR scanning** (explicitly deferred by Kyle).
- **Building-code-grade span tables.** Kyle wants *quick carpenter rules of thumb*, not inspector-defensible numbers.
- **Knowing Kyle's personal fastener inventory** ("suggest from what's on my shelf"). Raised but not confirmed; deferred. Fastener suggestions in v1 are generic.
- Electrical (wire gauge, conduit), drill/tap charts beyond what plumbing needs, payments/licensing, localization.

## 4. Look and feel

- **A normal Mac window plus a global keyboard shortcut** that brings it to the front from anywhere, like Soulver. Not a menu-bar app.
- **Layout "A — Soulver-style, quiet"** (chosen by Kyle from mockups): input on the left, **one** primary result right-aligned per line. **Clicking the result** reveals the other conversions (e.g. for `105"`: `8' 9"`, `105"`, `2.667 m`, `266.7 cm`) in a popover, with copy-on-click for each. Secondary info is *not* shown inline by default.
- Rules-of-thumb results show a short primary answer; clicking reveals the rule used and its assumptions.
- **Sheets (Claude's call):** multiple named sheets ("Back deck", "Kitchen trim") in a sidebar, persisted locally. These become the shared history when the iOS app arrives.
- Dark and light mode; monospaced input.

Mockup reference (approximate):

```
105"                         8' 9"        ← click → 105" · 2.667 m · 266.7 cm
wall = 12' 6"               12' 6"
wall − 2 × 2x4              12' 3"
1220 mm in ft          ≈ 4' 0 1/32"
2x4 joist               1½" × 3½"        ← click → ≈ 5' 3" max span (rule of thumb: depth × 1.5)
3 cubits             🔎 4' 6"            ← looked up via Claude, flagged
```

## 5. Correctness model (the most important section)

Because a wrong answer is the failure mode Kyle cares about most:

1. **Exact arithmetic (Claude's call).** The engine computes with exact rationals, not floating point. `10' / 3` is exactly 3' 4". Conversions are exact where the definition is exact (1 in = 25.4 mm exactly; 1 lb = 0.45359237 kg exactly; 1 stone = 14 lb). Only operations that are inherently irrational (square roots for diagonals/rafter lengths, trig for angles, π) fall back to floating point, and their results are marked approximate.
2. **Rounding is never silent (Claude's call).** Results display as `=` only when exact. When rounded to a tape mark (default nearest **1/16"**, configurable per sheet from 1/2" to 1/64") the result shows `≈`, and the exact value is in the popover.
3. **Three visible trust levels:**
   - **Known** — built-in, sourced, tested. No badge.
   - **Rule of thumb** — carpenter approximation. Distinct badge; popover states the rule and its assumptions.
   - **Looked up** — came from Claude. Distinct badge (e.g. 🔎). **Usable immediately in math** (Kyle's decision), and the flag **propagates**: any result depending on a looked-up value is also flagged.
4. **When the real size varies** (Claude's call): a Known entry is one canonical value **for a named standard** ("S4S dry, PS 20"; "PS 1 sheathing"), and the popover names that standard. Common variants are separate names (`3/4 ply` = 23/32" sheathing; `3/4 birch ply` ≈ 0.70"/18 mm), and known spread (wet pressure-treated lumber runs oversize) is noted in the popover. Anything with no defensible canonical value is labeled Rule of thumb, not Known.
5. **Every built-in table entry cites a source** (lumber grading rules / ALSC PS 20, ASME B1.20.1 for NPT, ASME B1.20.7 for GHT, ISO 228 for BSPP, ASTM B88 for copper tube, manufacturer data for fasteners, etc.) in the data file.
6. **Exhaustive tests** with known-answer fixtures for every table entry, conversion, rounding rule, and rule of thumb. Example: `1220 mm` → `4' 0 1/32"` at 1/32 precision.

## 6. Input language

Soulver-like free text, one expression per line. The builder designs the grammar; these are the behaviors it must support.

**Lengths**
- `105"`, `8'`, `8' 9"`, `8' 9 1/2"`, `8'9-1/2"`, `8ft 9in`, `9.5 in`, `2.667 m`, `266.7 cm`, `1220 mm`
- `X in ft`, `X in mm`, `X to m` — explicit conversion
- Arithmetic: `+ − × ÷` (and `* /`), parentheses; length × length = area, × length again = volume.

**Variables:** `name = expression`; usable on any later line. Reassignment allowed; later lines use the latest value above them.

**Nominal sizes**
- `2x4` (no spaces, matches a known nominal) → a **board**, not 8. Displays actual dimensions.
- `2 x 4`, `2 × 4`, `2*4` → multiplication.
- **When a board appears in length arithmetic, it contributes its thickness** (the face-to-face stacking dimension: 1½" for a 2x4). So `wall − 2 × 2x4` subtracts 3". Explicit forms `2x4 width` / `2x4 depth` (or similar) select the other dimension. **(Claude's call;** the popover must show which dimension was assumed so it's never a hidden guess.)
- Other nominal names are recognized too: `3/4 ply`, `5/4 deck`, `1/2 drywall`, `#9 screw`, `16d`, `18 ga brad`, `1/2" NPT`, `3/4 GHT`, `1/2" G`, `1/2 PEX`, `3/4 copper L` (see the arithmetic rule below).
- Compatibility queries: `3/4 GHT to 1/2 NPT` → whether they mate, and the adapter you'd buy.

**Rules of thumb** — keyword commands (exact phrasing is the builder's to design; these are illustrative):
- `studs 14' @ 16"`, `layout 14' @ 16"` (mark positions)
- `joist 2x10`, `beam 2-2x10`, `rafter 6/12 run 12'`
- `stairs 8' 9"` (total rise → riser count/height, tread, stringer length)
- `sheets 12' x 8' wall` (sheathing/drywall count with waste)
- `deck boards 12' x 16' 5/4x6`, `footing 12" x 42"` (concrete bags)
- `space 7 in 6' 2"` (equal spacing), `miter 6 sides`, `crown 38°` (saw settings)
- `fasten 3/4" ply to 2x4` (nail/screw length suggestion)

**Unknown input** → Claude fallback (Section 8). Lines that are clearly prose/comments (starting with `//` or `# ` — hash then space, so `#9 screw` still works) are never sent.

**Which dimension a nominal item contributes in arithmetic (Claude's call, chosen for correctness):** boards and sheet goods contribute their **thickness** (the stacking dimension). Every other nominal item (nails, screws, brads, pipe, tube, threads) is **refused in arithmetic unless a dimension is named**, e.g. `16d length`, `#9 dia`, `1/2 PEX od`, `1/2" NPT od`. The error says which dimensions are available. Display-only use (`16d` alone on a line) is always fine.

## 7. Built-in knowledge (v1 content)

| Area | v1 coverage |
|---|---|
| Dimensional lumber (S4S, dry) | 1x2–1x12, 2x2–2x12, 4x4, 4x6, 6x6, 5/4x4, 5/4x6 decking |
| Sheet goods | Plywood (¼–1⅛"), OSB, MDF, drywall (¼, ⅜, ½, ⅝) — nominal vs actual |
| Board feet | `board feet` for rough/surfaced stock |
| Screws | Gauge #4–#14 (and combined like #12/14) → major diameter; pilot hole sizes for hardwood/softwood |
| Nails | Pennyweight 2d–60d → length and common/box/sinker diameters; collated framing nail angles |
| Brads/finish/staples | 15, 16, 18, 23 ga → wire diameter; narrow-crown staples |
| Pipe threads | NPT ⅛"–2" (OD, TPI, taper, tap drill), BSPP "G" ⅛"–2", GHT ¾" — with mismatch warnings (GHT≠NPT, G≈NPT but leaks) |
| Tube | Copper K/L/M nominal → OD/ID, PEX (CTS), PVC Sch 40 (OD = NPS OD) |
| Units | Length, area, volume (incl. cubic yards, board feet), weight (incl. stone), angle (incl. pitch x/12) |

**Rules of thumb (v1):**
- *Framing:* stud count at 16"/24" OC (+ corners/openings), layout marks, joist/rafter span ≈ actual depth (in) × 1.5 → feet, stairs (riser 7–7¾", tread 10–11", 2R+T ≈ 25"), rafter length/angle from pitch, sheet counts + waste.
- *Decks:* joist/beam span, post spacing, joist cantilever ≈ ¼ of backspan, deck board count with gap, concrete bags per footing (80 lb ≈ 0.6 ft³), guard height and 4" baluster-gap check.
- *Finish:* equal spacing, miter angle for N-sided shapes, crown molding compound miter settings for common spring angles, casing reveal.

Each rule ships with its formula, assumptions, and a source note, and is tested.

**Data review (Kyle):** cited sources are enough — each value cites the specific standard table or manufacturer page. No per-table sign-off gate.

## 8. Claude fallback + improvement server

**Flow:**
1. Engine can't resolve a **term** (e.g. `cubits` in `3 cubits + 2'`) → app POSTs that term, with the full line for context only, plus app version and anonymous install ID. **Claude defines the unknown term; the engine always does the math** (Claude's call). So a cached definition never goes stale when variables change, and ✓/✗ verdicts apply to the term.
   - **When it fires (Claude's call):** only after the line has been still for about 1.5 seconds or the cursor leaves the line, never mid-keystroke, so half-typed input (`10 sto`) isn't looked up or cached.
2. Server calls Claude and requires a **structured response** (JSON schema / tool use): either a *quantity* (`value`, `unit`, dimension, conversion to SI as an exact or decimal factor), a *nominal item* (name, actual dimensions, category), or `unknown` with a short explanation. Never free text into the math.
3. App validates the response against its own unit system (dimension must be one it understands), shows it flagged **Looked up**, and **caches it locally** keyed by the normalized term so it works offline next time.
4. Server **logs every request and response** to the database.
5. In the result popover, Kyle can mark a looked-up answer **✓ correct** or **✗ wrong (+ correct value)**. The verdict is sent to the server and also updates the local cache.

The log is the backlog: frequent or corrected unknowns become built-in, sourced, tested entries in a later release.

**Server stack (Kyle):** Cloudflare Worker, TypeScript, **Bun** for local tooling (install/test). Code must stick to Web-standard APIs (the deployed runtime is workerd, not Bun). **Database: Cloudflare D1.**
- Claude API key lives in Worker secrets; never in the app.
- **Model (Claude's call):** `claude-sonnet-5-5` — accuracy over cost; make it a config value.
- Auth: for v1 a shared app token header plus per-install rate limiting is sufficient (single user). Before any public release: opt-in toggle for sending unknowns, privacy note, per-user caps.
- Endpoints (shape is the builder's): resolve unknown, submit verdict.

## 9. Architecture (Claude's call, approved in principle by Kyle)

- **Swift + SwiftUI**, macOS 26+.
- **`TwoByFourEngine`** — a Swift package with zero UI dependencies: parser, exact rational number type, unit/dimension system, nominal-size tables, rules of thumb, formatter (ft/in/fraction with rounding and `≈`), trust-level propagation. This is shared with the future iOS app and is where nearly all tests live.
- **Mac app** — sheets sidebar, editor with live per-line evaluation, result popover, settings, global hotkey, persistence, network client for the fallback.
- **Data tables** as versioned data files in the engine package (with source citations), compiled/validated at test time.
- **Persistence (Claude's call):** sheets and the looked-up cache are plain files (JSON) in Application Support. CloudKit/iCloud need a paid-account provisioning profile that an ad-hoc-signed SwiftPM build doesn't have, so sync is designed with the iOS app; plain files keep every option open.
- **Built with SwiftPM, not an Xcode project**, following `~/code/fwd` (Kyle): `Package.swift` with a `TwoByFourEngine` library target, a `twobyfour` executable target for the app, and test targets; `make app` assembles `build/twoByFour.app` with a generated `Info.plist` and ad-hoc signs it. macOS 26 minimum, like fwd. The future iOS app will need an Xcode project that depends on the engine package; that's fine and out of scope now.
- **Distribution: GitHub releases with a self-updater, not the App Store (for now)** — see Section 10. App Store submission is a later concern; keep the engine and app free of anything that would block sandboxing later (no private APIs; shelling out only in the updater, which an App Store build would drop), but don't sandbox v1.
- **Server** — separate directory in the same repo (`worker/`, as in fwd), deployed with Wrangler.

## 10. Releases (Kyle: "use the tricks from ~/code/fwd")

Copy fwd's release machinery, adapted for an app with no command-line tool:

- **CI** (`.github/workflows/ci.yml`) on every push to `main` and every PR: `make test`, `make app`, and the Worker's check + tests.
- **Betas on every green `main` commit** (`beta.yml`): published as a GitHub prerelease `vX.Y.(Z+1)-beta.<run>`, keeping the newest ten.
- **Stable releases** (`release.yml` + `scripts/release.sh X.Y.Z`): tag on `main` → test, build, publish `twoByFour.zip` with install notes. No Homebrew tap for v1 (Claude's call; fwd's is for its CLI).
- **PR preview builds — the "beta PR trick" (still in development in fwd's `pr-previews` branch):** every push to a PR publishes prerelease `pr-<n>`, replaced on each push, deleted when the PR closes, and the bot edits one PR comment saying how to try it. twoByFour has no CLI, so the switch lives in the app: **a "Try a build…" item (Settings or the app menu) accepts `42`, `#42`, `pr-42`, `beta`, or `stable`**, then downloads, verifies, swaps, and relaunches. A footer/badge shows `PR #42` while a preview runs. Carry over the fixes already made on that branch (an update check can't replace a build being tried; preview builds carry the newest beta's version so the beta channel replaces them at the next beta).
- **In-app updater** ported from fwd's `Updater.swift`: stable vs beta channel (a setting), only downloads from this repo's release URLs, checks bundle ID + version + code signature, swaps the bundle with rollback, "Restart to update" banner that can be dismissed, never offers updates to `dev` builds.
- **Public, open-source repo** (Kyle): `kylefritz/twobyfour` on GitHub, MIT license like fwd (Claude's call). Kyle may later charge for the App Store download; the source stays open.
- **Not notarized:** release notes include fwd's `xattr -dr com.apple.quarantine` line.
- **Install-count ping** like fwd's stats Worker is optional; fold it into the same Worker as the Claude fallback if added (Claude's call: skip for v1, Kyle is the only user).

## 11. Testing

- **Engine:** Swift Testing (Claude's call; Kyle's Minitest preference applies to Rails). Known-answer fixture tests for every table entry, conversion, rounding mode, parse case (especially `2x4` vs `2 x 4`), and rule of thumb. Property tests for round-tripping (ft/in → mm → ft/in) at each precision.
- **Server:** Vitest with the Cloudflare Workers pool, run via Bun. Claude calls mocked; schema validation tested with malformed responses.
- **App:** light UI tests for the core loop (type → result → popover → copy).

## 12. Build order

1. Engine: rationals, units, ft/in/fraction parse + format, arithmetic, variables, rounding/`≈`.
2. Mac app shell: sheets, live notepad, layout A, popover, global hotkey.
3. Fake-size library: lumber & sheet goods → fasteners → plumbing.
4. Rules of thumb: framing → decks → finish.
5. Claude fallback: Worker + D1 + app client + cache + ✓/✗ verdicts.

Later (separate designs): iOS app + iCloud history sync; LiDAR scanning; personal fastener inventory; App Store release.

## 13. Left to the builder

- Exact grammar and keyword phrasing for rules of thumb (within the behaviors above).
- Persistence technology (subject to the sync constraint).
- Global-hotkey implementation and default shortcut.
- Worker endpoint shapes, D1 schema, and the Claude prompt/schema.
- Visual polish details within layout A.

## 14. Open items for Kyle (not blocking v1)

- **Apple Developer membership** may be lapsed; local Xcode runs work without it, but iCloud sync and TestFlight later require it. GitHub-release distribution does not.
- **Name** — `twoByFour` as typed by Kyle; display capitalization (`twoByFour` vs `TwoByFour`) and an App Store/trademark check before any sale.
