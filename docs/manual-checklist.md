# Manual checklist

Things the tests can't see. `make app && open build/twoByFour.app`, then:

`build/twoByFour.app/Contents/MacOS/twobyfour --snapshot-notepad /tmp/n.png [--light]`
draws a sample sheet without a screen, for a quick layout check.

## Notepad
- [ ] Type `105"` → `8' 9"` appears on the right of that line as you type.
- [ ] Click `8' 9"` → popover lists `105"`, `2.667 m`, `266.7 cm`, `2667 mm`; clicking one copies it (paste somewhere to check) and the popover closes.
- [ ] Type `8’ 9”` (smart quotes, e.g. pasted from Notes) → `8' 9"`. Typing `'` and `"` in the notepad stays straight.
- [ ] `11' 11 31/32"` → `≈ 12' 0"`; `-3/32"` → `≈ -1/8"`.
- [ ] `5' + 3 lb` → grey "Can't add length and weight"; `1' / 0` → "Can't divide by zero".
- [ ] `0.0001 mm * 999999999 * 999999999 * 999999999` → "Number too large…", no crash.
- [ ] `wall = 12' 6"` then `wall - 3"` → `12' 3"`; move the assignment below → first line says "Unknown: wall".
- [ ] A long line that wraps keeps its answer level with its first row; resizing the window re-wraps and answers follow.
- [ ] Change "Round to" to 1/32 → `1220 mm` shows `≈ 4' 0 1/32"`.

## Sheets
- [ ] ⌘N makes a new sheet; rename and delete from the sidebar's right-click menu.
- [ ] Quit and reopen → sheets, text and rounding are all still there.

## Shortcut
- [ ] In another app, press ⌃⌥Space → twoByFour comes to the front with the notepad focused.

## Debug report
- [ ] Type a few lines, then Help → Copy Debug Report and paste into a chat → it shows the build, macOS, each line with its answer, and the recent log.
- [ ] Help → Show Log in Finder selects `~/Library/Logs/twoByFour/twoByFour.log`.
