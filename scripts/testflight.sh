#!/bin/bash
# Builds the iPhone app for the App Store and uploads it to TestFlight.
#
# Usage: scripts/testflight.sh [VERSION] [BUILD] [COMMIT]   (or: make testflight)
#   VERSION  the marketing version; defaults to the next patch after the last
#            stable tag, the same version the Mac's next release gets
#   BUILD    the build number; defaults to one more than App Store Connect's
#            highest, so it never repeats
#
# Needs an App Store Connect API key with the Admin role in ASC_KEY_PATH,
# ASC_KEY_ID and ASC_ISSUER_ID; on a Mac set up per ~/.appstoreconnect/README.md
# they're read from there. Signing is automatic: Xcode fetches the profiles
# and Apple's cloud-managed distribution certificate with the key (an App
# Manager key can't use that certificate). See README, "iPhone app".
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${ASC_KEY_ID:-}" ] && [ -f "$HOME/.appstoreconnect/asc.env" ]; then
  # shellcheck disable=SC1091
  . "$HOME/.appstoreconnect/asc.env"
  ASC_KEY_PATH=${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}
fi
: "${ASC_KEY_PATH:?set ASC_KEY_PATH to the App Store Connect API key (.p8)}"
: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
export ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID

if [ -n "${1:-}" ]; then
  VERSION=$1
else
  last=$(git tag --list 'v[0-9]*' --sort=-v:refname | grep -v -e '-' | head -1 || true)
  IFS=. read -r major minor patch <<< "${last:-v0.0.0}"
  VERSION="${major#v}.$minor.$((patch + 1))"
fi
BUILD=${2:-$(bun scripts/asc-next-build.ts)}
COMMIT=${3:-$(git rev-parse --short HEAD)}
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
echo "Uploading twoByFour $VERSION ($BUILD) from $COMMIT"

ARCHIVE=build/ios/twoByFour.xcarchive
rm -rf "$ARCHIVE" build/ios/export

make ios-project
xcodebuild -project iOS/twoByFour.xcodeproj -scheme twoByFour -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" "${AUTH[@]}" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" TWOBYFOUR_COMMIT="$COMMIT" \
  archive -quiet

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath build/ios/export \
  -exportOptionsPlist iOS/ExportOptions.plist "${AUTH[@]}"

echo "Uploaded twoByFour $VERSION ($BUILD) from $COMMIT. It appears in TestFlight once Apple finishes processing."
