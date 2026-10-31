# Command Line Tools ship Swift Testing outside the default search path.
# With full Xcode selected these flags are unnecessary and skipped.
CLT_FW := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_LIB := /Library/Developer/CommandLineTools/Library/Developer/usr/lib
ifeq ($(shell xcode-select -p 2>/dev/null),/Library/Developer/CommandLineTools)
TEST_FLAGS := -Xswiftc -F$(CLT_FW) -Xlinker -F$(CLT_FW) \
	-Xlinker -rpath -Xlinker $(CLT_FW) -Xlinker -rpath -Xlinker $(CLT_LIB)
endif

VERSION ?= dev
PREFIX ?= /Applications

IOS_SIM ?= iPhone 17
IOS_DEST ?= platform=iOS Simulator,name=$(IOS_SIM)
IOS_XCODEBUILD := xcodebuild -project iOS/twoByFour.xcodeproj -scheme twoByFour -derivedDataPath build/ios
# Simulator builds need no signing, so CI needs no Apple account for them.
IOS_UNSIGNED := CODE_SIGNING_ALLOWED=NO

.PHONY: build test app install clean ios-project ios-icon ios-build ios-test screenshots testflight

build:
	swift build -c release

test:
	swift test $(TEST_FLAGS) $(TEST_ARGS)

app: build
	VERSION=$(VERSION) PREVIEW="$(PREVIEW)" scripts/bundle.sh

install: app
	rm -rf "$(PREFIX)/twoByFour.app"
	cp -R build/twoByFour.app "$(PREFIX)/twoByFour.app"

clean:
	rm -rf .build build

# The iPhone app (iOS/). Needs Xcode and XcodeGen (brew install xcodegen).
ios-project:
	xcodegen --spec iOS/project.yml --quiet

# Redraws the iPhone icon from the Mac app's drawing; the PNG is committed.
ios-icon: build
	.build/release/twobyfour --write-ios-icon iOS/twoByFour/Assets.xcassets/AppIcon.appiconset/AppIcon.png

ios-build: ios-project
	$(IOS_XCODEBUILD) -destination 'generic/platform=iOS Simulator' $(IOS_UNSIGNED) build -quiet

ios-test: ios-project
	$(IOS_XCODEBUILD) -destination '$(IOS_DEST)' $(IOS_UNSIGNED) test

# Pull request screenshots, light and dark, Mac and iPhone (scripts/screenshots).
# `make screenshots SHEET=some.txt` shows that text instead of the defaults.
screenshots:
	scripts/screenshots $(if $(SHEET),--sheet $(SHEET))

# Uploads to TestFlight with the next version and build number (scripts/testflight.sh).
testflight:
	scripts/testflight.sh
