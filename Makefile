APP_NAME := MdMonitor
PRODUCT := MdMonitor
CLI_PRODUCT := mdm
DEV_APP_NAME := MdMonitorDev
DEV_APP_BUNDLE_ID := com.y10n.mdmonitor.dev
DEV_CLI_NAME := mdmdev
BUILD_DIR := build
DIST_DIR := dist
RELEASE_BIN := .build/release/$(PRODUCT)
CLI_RELEASE_BIN := .build/release/$(CLI_PRODUCT)
DEBUG_BIN := .build/debug/$(PRODUCT)
CLI_DEBUG_BIN := .build/debug/$(CLI_PRODUCT)
SPARKLE_FRAMEWORK_SRC := .build/release/Sparkle.framework
DEBUG_SPARKLE_FRAMEWORK_SRC := .build/debug/Sparkle.framework
APP_DIR := $(DIST_DIR)/$(APP_NAME).app
DEV_APP_DIR := $(BUILD_DIR)/$(DEV_APP_NAME).app
DEV_INFO_PLIST := $(BUILD_DIR)/$(DEV_APP_NAME)-Info.plist
DEV_EXECUTABLE := $(DEV_APP_NAME)
DEV_INSTALL_DIR ?= $(HOME)/Applications
DEV_INSTALLED_APP_DIR := $(DEV_INSTALL_DIR)/$(DEV_APP_NAME).app
DEV_CODESIGN_IDENTITY ?= Goi Local Signing
DEV_SIGNING_KEYCHAIN ?= $(HOME)/Library/Keychains/goi-signing.keychain-db
DEV_SIGNING_KEYCHAIN_PASSWORD ?=
DMG_PATH := $(DIST_DIR)/$(APP_NAME).dmg
ICON_PNG := $(BUILD_DIR)/icon-1024.png
ICONSET_DIR := $(BUILD_DIR)/$(APP_NAME).iconset
ICNS_PATH := $(BUILD_DIR)/AppIcon.icns
INSTALL_DIR ?= /Applications
REMOVE_DUPLICATE_COPY ?= 1
CODESIGN_IDENTITY ?= -
DMG_MAKER_COMMIT := 9e17aec84483938d154ce159ded8ce641379d5aa

.PHONY: help test run run-raw release debug-app verify-dev-signing icon app dmg dmg-legacy install install-local install-dev-local refresh-launch-services release-tag clean

help:
	@echo "make test          # run unit tests"
	@echo "make run           # install and run isolated dev app from ~/Applications"
	@echo "make run-raw       # run raw SwiftPM executable without app bundle isolation"
	@echo "make release       # build release binaries (app + cli)"
	@echo "make debug-app     # create build/$(DEV_APP_NAME).app with a dev bundle id"
	@echo "                   # signed with $(DEV_CODESIGN_IDENTITY) for stable Accessibility permission"
	@echo "make verify-dev-signing # prove the dev signing requirement survives content changes"
	@echo "make icon          # generate AppIcon.icns"
	@echo "make app           # create dist/MdMonitor.app"
	@echo "make dmg           # create premium dist/MdMonitor.dmg via DMGMaker"
	@echo "make dmg-legacy    # create basic dist/MdMonitor.dmg via hdiutil"
	@echo "make install       # install app to /Applications (override INSTALL_DIR=...)"
	@echo "make install-local # install app to ~/Applications"
	@echo "make install-dev-local # install $(DEV_APP_NAME).app to ~/Applications"
	@echo "make refresh-launch-services APP_PATH=/Applications/MdMonitor.app"
	@echo "REMOVE_DUPLICATE_COPY=1 # move ~/Applications duplicate when installing to /Applications"
	@echo "make release-tag VERSION=x.y.z # bump plist version, commit, tag and push"
	@echo "make clean         # remove build artifacts"

test:
	swift test

run: install-dev-local
	@osascript -e 'tell application id "$(DEV_APP_BUNDLE_ID)" to quit' >/dev/null 2>&1 || true
	"$(DEV_INSTALLED_APP_DIR)/Contents/MacOS/$(DEV_EXECUTABLE)"

run-raw:
	swift run $(PRODUCT)

release:
	swift build --disable-sandbox -c release --product $(PRODUCT)
	swift build --disable-sandbox -c release --product $(CLI_PRODUCT)

$(DEV_INFO_PLIST): packaging/Info.plist
	mkdir -p $(BUILD_DIR)
	cp packaging/Info.plist "$(DEV_INFO_PLIST)"
	/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $(DEV_APP_NAME)" "$(DEV_INFO_PLIST)"
	/usr/libexec/PlistBuddy -c "Set :CFBundleName $(DEV_APP_NAME)" "$(DEV_INFO_PLIST)"
	/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $(DEV_APP_BUNDLE_ID)" "$(DEV_INFO_PLIST)"
	/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $(DEV_EXECUTABLE)" "$(DEV_INFO_PLIST)"

debug-app: icon $(DEV_INFO_PLIST)
	swift build --product $(PRODUCT)
	swift build --product $(CLI_PRODUCT)
	mkdir -p "$(DEV_APP_DIR)/Contents/MacOS" "$(DEV_APP_DIR)/Contents/Resources" "$(DEV_APP_DIR)/Contents/Frameworks"
	cp "$(DEBUG_BIN)" "$(DEV_APP_DIR)/Contents/MacOS/$(DEV_EXECUTABLE)"
	cp "$(CLI_DEBUG_BIN)" "$(DEV_APP_DIR)/Contents/Resources/$(DEV_CLI_NAME)"
	@for bundle in .build/debug/*.bundle; do \
		if [ -d "$$bundle" ]; then \
			cp -R "$$bundle" "$(DEV_APP_DIR)/Contents/Resources/"; \
		fi; \
	done
	chmod +x "$(DEV_APP_DIR)/Contents/MacOS/$(DEV_EXECUTABLE)"
	chmod +x "$(DEV_APP_DIR)/Contents/Resources/$(DEV_CLI_NAME)"
	cp "$(DEV_INFO_PLIST)" "$(DEV_APP_DIR)/Contents/Info.plist"
	@if [ -f $(ICNS_PATH) ]; then cp "$(ICNS_PATH)" "$(DEV_APP_DIR)/Contents/Resources/AppIcon.icns"; fi
	@if [ -d "$(DEBUG_SPARKLE_FRAMEWORK_SRC)" ]; then \
		rm -rf "$(DEV_APP_DIR)/Contents/Frameworks/Sparkle.framework"; \
		cp -R "$(DEBUG_SPARKLE_FRAMEWORK_SRC)" "$(DEV_APP_DIR)/Contents/Frameworks/Sparkle.framework"; \
	else \
		echo "ERROR: Sparkle.framework missing at $(DEBUG_SPARKLE_FRAMEWORK_SRC)"; \
		exit 1; \
	fi
	@install_name_tool -delete_rpath /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-6.2/macosx "$(DEV_APP_DIR)/Contents/MacOS/$(DEV_EXECUTABLE)" 2>/dev/null || true
	@otool -l "$(DEV_APP_DIR)/Contents/MacOS/$(DEV_EXECUTABLE)" | grep -q '@executable_path/../Frameworks' || \
	install_name_tool -add_rpath @executable_path/../Frameworks "$(DEV_APP_DIR)/Contents/MacOS/$(DEV_EXECUTABLE)"
	@test -f "$(DEV_SIGNING_KEYCHAIN)" || { \
		echo "ERROR: local signing keychain not found: $(DEV_SIGNING_KEYCHAIN)"; \
		exit 1; \
	}
	@if [ -n "$(DEV_SIGNING_KEYCHAIN_PASSWORD)" ]; then \
		security unlock-keychain -p "$(DEV_SIGNING_KEYCHAIN_PASSWORD)" "$(DEV_SIGNING_KEYCHAIN)"; \
	fi
	@security find-identity -p codesigning "$(DEV_SIGNING_KEYCHAIN)" 2>/dev/null | \
		grep -Fq '"$(DEV_CODESIGN_IDENTITY)"' || { \
		echo "ERROR: code signing identity not found: $(DEV_CODESIGN_IDENTITY)"; \
		exit 1; \
	}
	CODESIGN_IDENTITY="$(DEV_CODESIGN_IDENTITY)" \
		CODESIGN_KEYCHAIN="$(DEV_SIGNING_KEYCHAIN)" \
		CODESIGN_HARDENED_RUNTIME=0 \
		CODESIGN_TIMESTAMP=0 \
		bash scripts/codesign_app.sh "$(DEV_APP_DIR)"

verify-dev-signing: debug-app
	bash scripts/verify_dev_signing.sh "$(DEV_APP_DIR)"

icon:
	rm -rf $(ICONSET_DIR)
	mkdir -p $(BUILD_DIR) $(ICONSET_DIR)
	swift packaging/render_icon.swift --output $(ICON_PNG) --size 1024
	sips -z 16 16 $(ICON_PNG) --out $(ICONSET_DIR)/icon_16x16.png >/dev/null
	sips -z 32 32 $(ICON_PNG) --out $(ICONSET_DIR)/icon_16x16@2x.png >/dev/null
	sips -z 32 32 $(ICON_PNG) --out $(ICONSET_DIR)/icon_32x32.png >/dev/null
	sips -z 64 64 $(ICON_PNG) --out $(ICONSET_DIR)/icon_32x32@2x.png >/dev/null
	sips -z 128 128 $(ICON_PNG) --out $(ICONSET_DIR)/icon_128x128.png >/dev/null
	sips -z 256 256 $(ICON_PNG) --out $(ICONSET_DIR)/icon_128x128@2x.png >/dev/null
	sips -z 256 256 $(ICON_PNG) --out $(ICONSET_DIR)/icon_256x256.png >/dev/null
	sips -z 512 512 $(ICON_PNG) --out $(ICONSET_DIR)/icon_256x256@2x.png >/dev/null
	sips -z 512 512 $(ICON_PNG) --out $(ICONSET_DIR)/icon_512x512.png >/dev/null
	cp $(ICON_PNG) $(ICONSET_DIR)/icon_512x512@2x.png
	@if iconutil -c icns $(ICONSET_DIR) -o $(ICNS_PATH); then \
		echo "Generated $(ICNS_PATH)"; \
	else \
		echo "WARN: iconutil failed, continue without bundled icns (runtime icon still applied)."; \
		rm -f $(ICNS_PATH); \
	fi

app: release icon
	mkdir -p $(APP_DIR)/Contents/MacOS $(APP_DIR)/Contents/Resources $(APP_DIR)/Contents/Frameworks
	cp $(RELEASE_BIN) $(APP_DIR)/Contents/MacOS/$(APP_NAME)
	cp $(CLI_RELEASE_BIN) $(APP_DIR)/Contents/Resources/$(CLI_PRODUCT)
	@for bundle in .build/release/*.bundle; do \
		if [ -d "$$bundle" ]; then \
			cp -R "$$bundle" $(APP_DIR)/Contents/Resources/; \
		fi; \
	done
	chmod +x $(APP_DIR)/Contents/MacOS/$(APP_NAME)
	chmod +x $(APP_DIR)/Contents/Resources/$(CLI_PRODUCT)
	cp packaging/Info.plist $(APP_DIR)/Contents/Info.plist
	@if [ -f $(ICNS_PATH) ]; then cp $(ICNS_PATH) $(APP_DIR)/Contents/Resources/AppIcon.icns; fi
	@if [ -d $(SPARKLE_FRAMEWORK_SRC) ]; then \
		rm -rf $(APP_DIR)/Contents/Frameworks/Sparkle.framework; \
		cp -R $(SPARKLE_FRAMEWORK_SRC) $(APP_DIR)/Contents/Frameworks/Sparkle.framework; \
	else \
		echo "ERROR: Sparkle.framework missing at $(SPARKLE_FRAMEWORK_SRC)"; \
		exit 1; \
	fi
	@install_name_tool -delete_rpath /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-6.2/macosx $(APP_DIR)/Contents/MacOS/$(APP_NAME) 2>/dev/null || true
	@otool -l $(APP_DIR)/Contents/MacOS/$(APP_NAME) | grep -q '@executable_path/../Frameworks' || \
	install_name_tool -add_rpath @executable_path/../Frameworks $(APP_DIR)/Contents/MacOS/$(APP_NAME)
	bash scripts/codesign_app.sh $(APP_DIR)

dmg: app
	bash scripts/create_dmg.sh "$(APP_DIR)" "$(APP_NAME)" "$(DMG_PATH)" "$(DMG_MAKER_COMMIT)"

dmg-legacy: app
	mkdir -p $(BUILD_DIR)/dmg-root $(DIST_DIR)
	rm -rf $(BUILD_DIR)/dmg-root/$(APP_NAME).app $(BUILD_DIR)/dmg-root/Applications $(DMG_PATH)
	cp -R $(APP_DIR) $(BUILD_DIR)/dmg-root/$(APP_NAME).app
	ln -s /Applications $(BUILD_DIR)/dmg-root/Applications
	@if hdiutil create -volname "$(APP_NAME)" -srcfolder $(BUILD_DIR)/dmg-root -ov -format UDZO $(DMG_PATH); then \
		echo "Generated $(DMG_PATH)"; \
	else \
		echo "WARN: hdiutil failed, fallback to zip package."; \
		rm -f $(DIST_DIR)/$(APP_NAME).zip; \
		ditto -c -k --sequesterRsrc --keepParent $(APP_DIR) $(DIST_DIR)/$(APP_NAME).zip; \
	fi

install: app
	mkdir -p "$(INSTALL_DIR)"
	ditto $(APP_DIR) "$(INSTALL_DIR)/$(APP_NAME).app"
	@if [ "$(INSTALL_DIR)" = "/Applications" ] && [ "$(REMOVE_DUPLICATE_COPY)" = "1" ] && [ -d "$$HOME/Applications/$(APP_NAME).app" ]; then \
		BACKUP_PATH="$$HOME/Applications/$(APP_NAME).app.backup_$$(date +%Y%m%d_%H%M%S)"; \
		mv "$$HOME/Applications/$(APP_NAME).app" "$$BACKUP_PATH"; \
		echo "Moved duplicate user-local app to $$BACKUP_PATH"; \
	fi
	@$(MAKE) refresh-launch-services APP_PATH="$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

install-local: app
	mkdir -p "$$HOME/Applications"
	ditto $(APP_DIR) "$$HOME/Applications/$(APP_NAME).app"
	@$(MAKE) refresh-launch-services APP_PATH="$$HOME/Applications/$(APP_NAME).app"
	@if [ -d "/Applications/$(APP_NAME).app" ] && [ "$(REMOVE_DUPLICATE_COPY)" = "1" ]; then \
		echo "WARN: /Applications/$(APP_NAME).app also exists. Spotlight may open the wrong copy."; \
		echo "      Keep only one install location to avoid LaunchServices conflict."; \
	fi
	@echo "Installed to $$HOME/Applications/$(APP_NAME).app"

install-dev-local: debug-app
	mkdir -p "$(DEV_INSTALL_DIR)"
	ditto "$(DEV_APP_DIR)" "$(DEV_INSTALLED_APP_DIR)"
	@$(MAKE) refresh-launch-services APP_PATH="$(DEV_INSTALLED_APP_DIR)"
	@echo "Installed dev app to $(DEV_INSTALLED_APP_DIR)"

refresh-launch-services:
	@LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"; \
	if [ -x "$$LSREGISTER" ] && [ -d "$(APP_PATH)" ]; then \
		"$$LSREGISTER" -f "$(APP_PATH)" >/dev/null 2>&1 || true; \
		echo "Refreshed LaunchServices: $(APP_PATH)"; \
	else \
		echo "Skipped LaunchServices refresh: $(APP_PATH)"; \
	fi

release-tag:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make release-tag VERSION=x.y.z"; \
		exit 1; \
	fi
	@bash scripts/release_tag.sh "$(VERSION)"

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)
