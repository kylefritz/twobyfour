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

.PHONY: build test app install clean

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
