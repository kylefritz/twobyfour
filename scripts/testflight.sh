#!/bin/bash
# Builds the iPhone app for the App Store and uploads it to TestFlight.
#
# Usage: scripts/testflight.sh VERSION BUILD [COMMIT]
#   VERSION  the marketing version, e.g. 0.0.1
#   BUILD    the build number; must go up with every upload
#
# Needs: the "Apple Distribution" certificate in a keychain, the
# "twoByFour App Store" profile installed, and an App Store Connect API key
# in ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID. See README, "iPhone app".
set -euo pipefail

VERSION=${1:?usage: scripts/testflight.sh VERSION BUILD [COMMIT]}
BUILD=${2:?usage: scripts/testflight.sh VERSION BUILD [COMMIT]}
COMMIT=${3:-$(git rev-parse --short HEAD)}
: "${ASC_KEY_PATH:?set ASC_KEY_PATH to the App Store Connect API key (.p8)}"
: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"

ARCHIVE=build/ios/twoByFour.xcarchive
rm -rf "$ARCHIVE" build/ios/export

make ios-project
xcodebuild -project iOS/twoByFour.xcodeproj -scheme twoByFour -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" TWOBYFOUR_COMMIT="$COMMIT" \
  archive -quiet

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath build/ios/export \
  -exportOptionsPlist iOS/ExportOptions.plist \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"

echo "Uploaded twoByFour $VERSION ($BUILD) from $COMMIT. It appears in TestFlight once Apple finishes processing."
