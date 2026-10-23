# twoByFour

A Mac notepad calculator for construction. Type `8' 9 1/2" - 2 × 3/4"` and get a
tape-measure answer; type `105"` and click the result for inches, feet and
metric. It does exact feet-inch-fraction math, so `10' / 3` is exactly `3' 4"`,
and it says `≈` whenever it had to round.

Coming next: the real sizes behind names like `2x4`, `3/4 ply`, `16d` and
`1/2" NPT`, carpenter rules of thumb, and lookups for units it doesn't know.

## Build

Needs macOS 26 and the Xcode Command Line Tools.

```sh
make test   # run the tests
make app    # build build/twoByFour.app
make install
```

See `docs/superpowers/specs/` for the design.
