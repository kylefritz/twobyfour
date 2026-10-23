# twoByFour

A Mac notepad calculator for construction. Type `8' 9 1/2" - 2 × 3/4"` and get a
tape-measure answer; type `105"` and click the result for inches, feet and
metric. It does exact feet-inch-fraction math, so `10' / 3` is exactly `3' 4"`,
and it says `≈` whenever it had to round.

Coming next: the real sizes behind names like `2x4`, `3/4 ply`, `16d` and
`1/2" NPT`, carpenter rules of thumb, and lookups for units it doesn't know.

## Install

Download `twoByFour.zip` from [Releases](https://github.com/kylefritz/twobyfour/releases),
drag `twoByFour.app` into `/Applications`, then run
`xattr -dr com.apple.quarantine /Applications/twoByFour.app` (it isn't
notarized). It updates itself. **Settings → Every beta** follows each build of
`main`; **twoByFour → Try a Build…** switches to a pull request's preview build
(enter its number) or back (`beta`, `stable`). Press **⌃⌥Space** anywhere to
bring the notepad forward.

## Build

Needs macOS 26 and the Xcode Command Line Tools.

```sh
make test   # run the tests
make app    # build build/twoByFour.app
make install
scripts/release.sh 0.1.0   # tag a release; GitHub Actions builds it
```

See `docs/superpowers/specs/` for the design.
