APP_NAME := MdMonitor
PRODUCT := MdMonitor
CLI_PRODUCT := mdm
BUILD_DIR := build
DIST_DIR := dist
RELEASE_BIN := .build/release/$(PRODUCT)
CLI_RELEASE_BIN := .build/release/$(CLI_PRODUCT)
SPARKLE_FRAMEWORK_SRC := .build/release/Sparkle.framework
APP_DIR := $(DIST_DIR)/$(APP_NAME).app
DMG_PATH := $(DIST_DIR)/$(APP_NAME).dmg
ICON_PNG := $(BUILD_DIR)/icon-1024.png
ICONSET_DIR := $(BUILD_DIR)/$(APP_NAME).iconset
ICNS_PATH := $(BUILD_DIR)/AppIcon.icns
INSTALL_DIR ?= /Applications
REMOVE_DUPLICATE_COPY ?= 1

.PHONY: help test run release icon app dmg install install-local refresh-launch-services release-tag clean

help:
	@echo "make test          # run unit tests"
	@echo "make run           # run menu bar app (debug)"
	@echo "make release       # build release binaries (app + cli)"
	@echo "make icon          # generate AppIcon.icns"
	@echo "make app           # create dist/MdMonitor.app"
	@echo "make dmg           # create dist/MdMonitor.dmg"
	@echo "make install       # install app to /Applications (override INSTALL_DIR=...)"
	@echo "make install-local # install app to ~/Applications"
	@echo "make refresh-launch-services APP_PATH=/Applications/MdMonitor.app"
	@echo "REMOVE_DUPLICATE_COPY=1 # move ~/Applications duplicate when installing to /Applications"
	@echo "make release-tag VERSION=x.y.z # bump plist version, commit, tag and push"
	@echo "make clean         # remove build artifacts"

test:
	swift test

run:
	swift run $(PRODUCT)

release:
	swift build --disable-sandbox -c release --product $(PRODUCT)
	swift build --disable-sandbox -c release --product $(CLI_PRODUCT)

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
	codesign --force --deep --sign - $(APP_DIR)

dmg: app
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
