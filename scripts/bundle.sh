#!/bin/sh
# Assembles build/twoByFour.app from the release build and ad-hoc signs it.
# Usage: VERSION=1.2.3 scripts/bundle.sh   (VERSION defaults to "dev")
# PREVIEW="PR #42" marks a pull request's preview build in the window footer.
set -eu

cd "$(dirname "$0")/.."
VERSION="${VERSION:-dev}"
PREVIEW="${PREVIEW:-}"
# Not `swift build --show-bin-path`: that starts SwiftPM's sandbox, which
# fails inside other build sandboxes.
BINARY=".build/release/twobyfour"
[ -x "$BINARY" ] || { echo "No release binary; run 'swift build -c release' first." >&2; exit 1; }

APP="build/twoByFour.app"
rm -rf "$APP" build/twoByFour.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/twobyfour"

# The icon is drawn by the app itself (Sources/twobyfour/Icon.swift).
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
"$BINARY" --write-iconset "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

# The commit it was built from, to tell dev builds apart; "-dirty" means
# uncommitted changes went in too.
COMMIT=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  COMMIT=$(git rev-parse --short HEAD)
  git diff --quiet HEAD -- || COMMIT="$COMMIT-dirty"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>twoByFour</string>
  <key>CFBundleDisplayName</key><string>twoByFour</string>
  <key>CFBundleExecutable</key><string>twobyfour</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIdentifier</key><string>io.github.kylefritz.twobyfour</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>TwoByFourCommit</key><string>${COMMIT}</string>
  <key>TwoByFourPreview</key><string>${PREVIEW}</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMultipleInstancesProhibited</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
/usr/bin/ditto -c -k --keepParent "$APP" build/twoByFour.zip
echo "Built $APP (version $VERSION) and build/twoByFour.zip"
