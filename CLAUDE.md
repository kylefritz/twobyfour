# twoByFour

## Spec first

`docs/SPEC.md` lists everything twoByFour understands, with examples.
**A new feature goes into the spec first**, with its examples written as
`input → answer` lines in a ```twobyfour block, then gets built until
`SpecTests` passes. Move it out of "Planned" when it ships. Never change an
example's answer to make a test pass without checking the math by hand: a
wrong answer is the worst thing this app can do.

The guide new users start with is `Sources/TwoByFourKit/GettingStarted.swift`.
When a feature is one of the main or most interesting ways to use the app,
add a line or two to it (`GettingStartedTests` checks every line works).

## Sent logs

People send logs from Help → Send Logs (More → Send Logs on iPhone).
`scripts/logs` lists them and `scripts/logs <ref>` prints one.

## Pull requests need screenshots

Every pull request includes screenshots in its description, under a
`## Screenshots` heading, so it can be reviewed from a phone without building
the app. Show the state the change is about (an answer, an error, the keypad,
a popover open), on the Mac and the iPhone, and before and after for a visual
fix. A change with nothing to see (a script, CI) says so under the heading
instead. Look at each image yourself before posting it.

The apps draw themselves with no one at the screen:

```sh
make screenshots                    # Mac sample sheet + iPhone Getting Started
make screenshots SHEET=demo.txt     # every shot shows demo.txt's lines
scripts/screenshots --mac out/      # just the Mac; --iphone for just the phone
```

That writes `mac-dark.png`, `mac-light.png`, `iphone-light.png` and
`iphone-dark.png` (to `build/screenshots/` by default). Write a few sheet lines
that show off the change and pass them as `SHEET`. For states a sheet can't
show (a popover, a menu), drive the simulator by hand with `xcrun simctl` and
`xcrun simctl io <udid> screenshot`. If `simctl` hangs after an Xcode update,
run `sudo xcodebuild -runFirstLaunch`.

Upload with `attach-screenshot --pr <N> *.png` (hidden-ref image hosting: an
orphan commit under `refs/uploads/`, never in clones, linked by SHA so it never
breaks). It prints one markdown image per file, alt text from the file name, so
rename files for what they show (`iphone-dark-rise-and-run.png`).

## Building

- `make test` runs the engine and app tests; `make ios-test` the iPhone's.
- `make testflight` uploads the next iPhone build; every green `main` does too.
