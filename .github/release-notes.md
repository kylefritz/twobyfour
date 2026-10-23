## Install

Download `twoByFour.zip`, unzip it, drag `twoByFour.app` into `/Applications`, then run:

```sh
xattr -dr com.apple.quarantine /Applications/twoByFour.app
```

twoByFour isn't notarized by Apple, so without that line macOS says it "could not verify twoByFour is free of malware" the first time you open it. After that, it updates itself.
