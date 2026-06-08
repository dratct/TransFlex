.DEFAULT_GOAL := help

DEBUG_APP := DerivedData/Build/Products/Debug/TransFlexDev.app
RELEASE_APP := DerivedData/Build/Products/Release/TransFlex.app
DEBUG_PROCESS := TransFlexDev
RELEASE_PROCESS := TransFlex
DEBUG_BUNDLE_ID := io.aiaz.transflex.dev
RELEASE_BUNDLE_ID := io.aiaz.transflex

.PHONY: build build-fast _build _build-fast release test run kill kill-debug kill-release kill-all open open-debug open-release xcode log clean help welcome-reset welcome-reset-release welcome-reset-all welcome-test

build: kill-debug _build open-debug
	@echo "==> launched $(DEBUG_APP)"

build-fast: kill-debug _build-fast open-debug
	@echo "==> launched $(DEBUG_APP)"

_build:
	@scripts/build.sh

_build-fast:
	@scripts/build.sh --no-gen

release:
	@scripts/build.sh --release

test:
	@xcodebuild -scheme TransFlex -derivedDataPath DerivedData -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES test

kill: kill-debug

kill-debug:
	@pkill -x $(DEBUG_PROCESS) 2>/dev/null || true

kill-release:
	@pkill -x $(RELEASE_PROCESS) 2>/dev/null || true

kill-all: kill-debug kill-release

open: open-debug

open-debug:
	@if [ ! -d "$(DEBUG_APP)" ]; then echo "==> Debug app not found, building..."; scripts/build.sh --no-gen; fi
	@open $(DEBUG_APP)
	@echo "==> opened $(DEBUG_APP)"

open-release:
	@if [ ! -d "$(RELEASE_APP)" ]; then echo "==> Release app not found, building..."; scripts/build.sh --release; fi
	@open $(RELEASE_APP)
	@echo "==> opened $(RELEASE_APP)"

run: build-fast

xcode:
	@xcodegen generate && open TransFlex.xcodeproj

log:
	@log stream --predicate 'subsystem == "io.aiaz.transflex"' --level=debug

welcome-reset:
	@defaults delete $(DEBUG_BUNDLE_ID) hasShownWelcome 2>/dev/null || true
	@defaults delete $(DEBUG_BUNDLE_ID) hasCompletedFirstRun 2>/dev/null || true
	@echo "==> debug welcome flags cleared (hasShownWelcome, hasCompletedFirstRun)"

welcome-reset-release:
	@defaults delete $(RELEASE_BUNDLE_ID) hasShownWelcome 2>/dev/null || true
	@defaults delete $(RELEASE_BUNDLE_ID) hasCompletedFirstRun 2>/dev/null || true
	@echo "==> release welcome flags cleared (hasShownWelcome, hasCompletedFirstRun)"

welcome-reset-all: welcome-reset welcome-reset-release

welcome-test: kill-debug welcome-reset _build-fast open-debug
	@echo "==> welcome flow ready — wizard should appear"

clean:
	@rm -rf DerivedData .swiftpm TransFlex.xcodeproj
	@rm -rf "$(HOME)/Library/Developer/Xcode/DerivedData/"TransFlex-*
	@echo "==> cleaned: DerivedData, .swiftpm, TransFlex.xcodeproj, global Xcode DerivedData (TransFlex-*)"

help:
	@echo "make            — print this help (default)"
	@echo "make run        — kill + build-fast + open"
	@echo "make build      — kill + full build (regenerates .xcodeproj) + open"
	@echo "make build-fast — kill + build (skip xcodegen) + open"
	@echo "make release    — Release build only (no kill/open)"
	@echo "make test       — run unit tests"
	@echo "make kill       — alias for kill-debug"
	@echo "make kill-debug — kill running TransFlexDev"
	@echo "make kill-release — kill running TransFlex"
	@echo "make kill-all   — kill TransFlexDev and TransFlex"
	@echo "make open       — alias for open-debug"
	@echo "make open-debug — open Debug .app (auto-builds if missing)"
	@echo "make open-release — open Release .app (auto-builds if missing)"
	@echo "make xcode      — generate + open in Xcode"
	@echo "make log        — stream OSLog (subsystem io.aiaz.transflex)"
	@echo "make welcome-reset — clear Debug hasShownWelcome + hasCompletedFirstRun"
	@echo "make welcome-reset-release — clear Release welcome flags"
	@echo "make welcome-reset-all — clear Debug and Release welcome flags"
	@echo "make welcome-test  — kill + reset flags + build-fast + open (re-test wizard)"
	@echo "make clean      — remove DerivedData, .swiftpm, .xcodeproj, global Xcode DerivedData (TransFlex-*)"
