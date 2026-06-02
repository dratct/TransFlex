.DEFAULT_GOAL := help

APP := DerivedData/Build/Products/Debug/TransFlex.app
RELEASE_APP := DerivedData/Build/Products/Release/TransFlex.app

.PHONY: build build-fast _build _build-fast release test run kill open open-debug open-release xcode log clean help welcome-reset welcome-test

build: kill _build open
	@echo "==> launched $(APP)"

build-fast: kill _build-fast open
	@echo "==> launched $(APP)"

_build:
	@scripts/build.sh

_build-fast:
	@scripts/build.sh --no-gen

release:
	@scripts/build.sh --release

test:
	@xcodebuild -scheme TransFlex -derivedDataPath DerivedData -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES test

kill:
	@pkill -x TransFlex 2>/dev/null || true

open: open-debug

open-debug:
	@if [ ! -d "$(APP)" ]; then echo "==> Debug app not found, building..."; scripts/build.sh --no-gen; fi
	@open $(APP)
	@echo "==> opened $(APP)"

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
	@defaults delete io.aiaz.transflex hasShownWelcome 2>/dev/null || true
	@defaults delete io.aiaz.transflex hasCompletedFirstRun 2>/dev/null || true
	@echo "==> welcome flags cleared (hasShownWelcome, hasCompletedFirstRun)"

welcome-test: kill welcome-reset _build-fast open
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
	@echo "make kill       — kill running TransFlex"
	@echo "make open       — alias for open-debug"
	@echo "make open-debug — open Debug .app (auto-builds if missing)"
	@echo "make open-release — open Release .app (auto-builds if missing)"
	@echo "make xcode      — generate + open in Xcode"
	@echo "make log        — stream OSLog (subsystem io.aiaz.transflex)"
	@echo "make welcome-reset — clear hasShownWelcome + hasCompletedFirstRun"
	@echo "make welcome-test  — kill + reset flags + build-fast + open (re-test wizard)"
	@echo "make clean      — remove DerivedData, .swiftpm, .xcodeproj, global Xcode DerivedData (TransFlex-*)"
