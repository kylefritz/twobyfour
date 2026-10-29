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

## Building

- `make test` runs the engine and app tests; `make ios-test` the iPhone's.
- `make testflight` uploads the next iPhone build; every green `main` does too.
