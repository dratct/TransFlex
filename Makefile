.DEFAULT_GOAL := help

DEBUG_APP := DerivedData/Build/Products/Debug/TransFlexDev.app
RELEASE_APP := DerivedData/Build/Products/Release/TransFlex.app
DEBUG_PROCESS := TransFlexDev
RELEASE_PROCESS := TransFlex
DEBUG_BUNDLE_ID := io.aiaz.transflex.dev
DEBUG_SUPPORT_DIR := $(HOME)/Library/Application Support/TransFlexDev
RELEASE_BUNDLE_ID := io.aiaz.transflex
# Ad-hoc unless Config/Local.xcconfig opts this machine into team signing.
TEST_SIGNING := $(if $(wildcard Config/Local.xcconfig),,CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES)
# Team-signed builds keep their designated requirement, so macOS keeps honouring the
# privacy grants across rebuilds; only ad-hoc builds need them reset.
BUILD_PERMISSIONS_RESET := $(if $(wildcard Config/Local.xcconfig),,permissions-reset)
# An App Store Connect team API key for provisioning without an Xcode account.
ASC_AUTH := $(if $(ASC_KEY_PATH),-authenticationKeyPath "$(ASC_KEY_PATH)" -authenticationKeyID "$(ASC_KEY_ID)" -authenticationKeyIssuerID "$(ASC_ISSUER_ID)")

.PHONY: permissions-reset fresh-reset build build-fresh build-fast _build _build-fast release test provision run kill kill-debug kill-release kill-all open open-debug open-release xcode log clean help welcome-reset welcome-reset-release welcome-reset-all welcome-test

build: kill-debug _build $(BUILD_PERMISSIONS_RESET) open-debug
	@echo "==> launched $(DEBUG_APP)"

build-fast: kill-debug _build-fast $(BUILD_PERMISSIONS_RESET) open-debug
	@echo "==> launched $(DEBUG_APP)"

build-fresh: kill-debug _build fresh-reset open-debug
	@echo "==> launched $(DEBUG_APP) as a fresh install (API keys kept)"

# Debug data back to first-launch state. Keychain API keys are kept so a fresh
# run does not need them pasted again.
fresh-reset: kill-debug permissions-reset
	@defaults delete $(DEBUG_BUNDLE_ID) >/dev/null 2>&1 || true
	@rm -rf "$(DEBUG_SUPPORT_DIR)"
	@echo "==> Debug defaults, presets, history and caches cleared (Keychain kept)"

# Ad-hoc signing changes the code signature on every build, so macOS keeps the
# old grants listed but no longer honours them. Start each Debug run clean.
permissions-reset:
	@tccutil reset All $(DEBUG_BUNDLE_ID) >/dev/null 2>&1 || true
	@echo "==> Debug privacy grants reset (Accessibility, Paste, ...)"

_build:
	@scripts/build.sh

_build-fast:
	@scripts/build.sh --no-gen

release:
	@scripts/build.sh --release

test:
	@xcodebuild -scheme TransFlex -derivedDataPath DerivedData -destination 'platform=macOS' $(TEST_SIGNING) test

# Once per machine after creating Config/Local.xcconfig: creates the development certificate,
# registers this Mac and fetches the team profile. Later builds reuse the cached profile.
provision:
	@test -f Config/Local.xcconfig || { echo "error: create Config/Local.xcconfig first (see Config/Local.xcconfig.example)" >&2; exit 1; }
	@xcodebuild -scheme TransFlex -configuration Debug -derivedDataPath DerivedData -destination 'platform=macOS' -allowProvisioningUpdates -allowProvisioningDeviceRegistration $(ASC_AUTH) build

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
	@rm -f "$(HOME)/Library/Application Support/TransFlexDev/presets.json" 2>/dev/null || true
	@echo "==> debug welcome flags and presets cleared (hasShownWelcome, hasCompletedFirstRun, presets.json)"

welcome-reset-release:
	@defaults delete $(RELEASE_BUNDLE_ID) hasShownWelcome 2>/dev/null || true
	@defaults delete $(RELEASE_BUNDLE_ID) hasCompletedFirstRun 2>/dev/null || true
	@rm -f "$(HOME)/Library/Application Support/TransFlex/presets.json" 2>/dev/null || true
	@echo "==> release welcome flags and presets cleared (hasShownWelcome, hasCompletedFirstRun, presets.json)"

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
	@echo "make build      — kill + full build (regenerates .xcodeproj) + reset Debug privacy grants + open"
	@echo "make build-fast — kill + build (skip xcodegen) + reset Debug privacy grants + open"
	@echo "make build-fresh — kill + full build + reset Debug to first-launch state (keeps API keys) + open"
	@echo "make permissions-reset — reset Debug privacy grants (Accessibility, Paste, ...)"
	@echo "make fresh-reset — clear Debug grants, defaults, presets, history, caches (keeps API keys)"
	@echo "make release    — Release build only (no kill/open)"
	@echo "make test       — run unit tests"
	@echo "make provision  — once per machine with Config/Local.xcconfig: certificate, device, profile"
	@echo "                  (Xcode account, or ASC_KEY_PATH/ASC_KEY_ID/ASC_ISSUER_ID team API key)"
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
