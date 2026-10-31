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

## Releases and version numbers

twoByFour uses semantic versioning, one number for the Mac and iPhone apps.

- Every green push to `main` publishes a Mac beta, `v<next patch>-beta.<run>`, and uploads a
  TestFlight build with that next patch as its version. The beta number is only a guess at the
  next patch, so don't copy it.
- A release is a tag `vX.Y.Z` on a commit whose CI passed: `scripts/release.sh X.Y.Z`.
- Pick the number by what changed since the last release (`git log <last tag>..main`). While
  twoByFour is below 1.0:
  - a new feature or a change in behavior (something new it understands, a different answer
    format, a new screen) bumps the minor: 0.2.1 → 0.3.0;
  - only fixes bump the patch: 0.3.0 → 0.3.1.
- 1.0.0 is the first App Store release. After that a major bump means something people rely on
  breaks: saved sheets that won't load, a sheet line that now means something else.
- Say which number you'd use and why, and ask Kyle before tagging. Once the release run
  starts, a wrong number means releasing again rather than taking it back.
- TestFlight's version follows the tags (`scripts/testflight.sh`); its build number comes from
  App Store Connect and only goes up.

## Building

- `make test` runs the engine and app tests; `make ios-test` the iPhone's.
- `make testflight` uploads the next iPhone build; every green `main` does too.
