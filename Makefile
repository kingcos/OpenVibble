PROJECT := OpenVibble.xcodeproj
SCHEME := OpenVibbleApp
CONFIGURATION := Debug
SIMULATOR_NAME ?= iPhone 17
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR_NAME)
GENERIC_DESTINATION := generic/platform=iOS Simulator
ARCHIVE_DESTINATION := generic/platform=iOS
PACKAGE_DIR := Packages/OpenVibbleKit
BUILD_DIR := build
ARCHIVE_PATH := $(BUILD_DIR)/$(SCHEME).xcarchive
EXPORT_PATH := $(BUILD_DIR)/export
EXPORT_OPTIONS_PLIST := $(BUILD_DIR)/ExportOptions.plist

ASC_KEY_ID ?=
ASC_ISSUER_ID ?=
ASC_KEY_FILEPATH ?= $(HOME)/Downloads/AuthKey_$(ASC_KEY_ID).p8
MARKETING_VERSION ?=
BUMP_BUILD ?= 1
DEVELOPMENT_TEAM ?=

.PHONY: bootstrap build test run-sim testflight tf-package clean

bootstrap:
	xcodegen generate

build: bootstrap
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination '$(GENERIC_DESTINATION)' \
		CODE_SIGNING_ALLOWED=NO \
		build

test: bootstrap
	swift test --package-path $(PACKAGE_DIR)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination '$(DESTINATION)' \
		CODE_SIGNING_ALLOWED=NO \
		test

run-sim: build
	xcrun simctl boot "$(SIMULATOR_NAME)" || true
	xcrun simctl install booted "$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -destination '$(GENERIC_DESTINATION)' -showBuildSettings | awk '/TARGET_BUILD_DIR/ {print $$3; exit}')/$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -destination '$(GENERIC_DESTINATION)' -showBuildSettings | awk '/FULL_PRODUCT_NAME/ {print $$3; exit}')"
	xcrun simctl launch booted kingcos.me.openvibble

testflight: bootstrap
	@if [ -n "$(MARKETING_VERSION)" ]; then \
		xcrun agvtool new-marketing-version "$(MARKETING_VERSION)"; \
	fi
	@if [ "$(BUMP_BUILD)" = "1" ]; then \
		xcrun agvtool next-version -all; \
	fi
	mkdir -p "$(BUILD_DIR)" "$(EXPORT_PATH)"
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>method</key>' \
		'  <string>app-store</string>' \
		'  <key>signingStyle</key>' \
		'  <string>automatic</string>' \
		'  <key>uploadSymbols</key>' \
		'  <true/>' \
		'  <key>uploadBitcode</key>' \
		'  <false/>' \
		'</dict>' \
		'</plist>' > "$(EXPORT_OPTIONS_PLIST)"
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination '$(ARCHIVE_DESTINATION)' \
		$(if $(DEVELOPMENT_TEAM),DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM),) \
		-allowProvisioningUpdates \
		archive \
		-archivePath "$(ARCHIVE_PATH)"
	xcodebuild \
		-exportArchive \
		-archivePath "$(ARCHIVE_PATH)" \
		-exportPath "$(EXPORT_PATH)" \
		-allowProvisioningUpdates \
		-exportOptionsPlist "$(EXPORT_OPTIONS_PLIST)"
	@if [ -n "$(ASC_KEY_ID)" ] && [ -n "$(ASC_ISSUER_ID)" ]; then \
		test -f "$(ASC_KEY_FILEPATH)" || (echo "ASC_KEY_FILEPATH not found: $(ASC_KEY_FILEPATH)" && exit 1); \
		API_PRIVATE_KEYS_DIR="$$(dirname "$(ASC_KEY_FILEPATH)")" xcrun altool \
			--upload-app \
			--type ios \
			--file "$$(find "$(EXPORT_PATH)" -name '*.ipa' -print -quit)" \
			--apiKey "$(ASC_KEY_ID)" \
			--apiIssuer "$(ASC_ISSUER_ID)"; \
	elif [ -n "$(APPLE_ID)" ] && [ -n "$(APP_SPECIFIC_PASSWORD)" ]; then \
		xcrun altool \
			--upload-app \
			--type ios \
			--file "$$(find "$(EXPORT_PATH)" -name '*.ipa' -print -quit)" \
			--username "$(APPLE_ID)" \
			--password "$(APP_SPECIFIC_PASSWORD)"; \
	else \
		echo "Upload credentials are missing."; \
		echo "Use API Key: make testflight ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_FILEPATH=..."; \
		echo "Or Apple ID: make testflight APPLE_ID=you@example.com APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx"; \
		exit 1; \
	fi

tf-package: bootstrap
	@if [ -n "$(MARKETING_VERSION)" ]; then \
		xcrun agvtool new-marketing-version "$(MARKETING_VERSION)"; \
	fi
	@if [ "$(BUMP_BUILD)" = "1" ]; then \
		xcrun agvtool next-version -all; \
	fi
	mkdir -p "$(BUILD_DIR)" "$(EXPORT_PATH)"
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>method</key>' \
		'  <string>app-store</string>' \
		'  <key>signingStyle</key>' \
		'  <string>automatic</string>' \
		'  <key>uploadSymbols</key>' \
		'  <true/>' \
		'  <key>uploadBitcode</key>' \
		'  <false/>' \
		'</dict>' \
		'</plist>' > "$(EXPORT_OPTIONS_PLIST)"
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination '$(ARCHIVE_DESTINATION)' \
		$(if $(DEVELOPMENT_TEAM),DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM),) \
		-allowProvisioningUpdates \
		archive \
		-archivePath "$(ARCHIVE_PATH)"
	xcodebuild \
		-exportArchive \
		-archivePath "$(ARCHIVE_PATH)" \
		-exportPath "$(EXPORT_PATH)" \
		-allowProvisioningUpdates \
		-exportOptionsPlist "$(EXPORT_OPTIONS_PLIST)"
	@echo "Exported IPA: $$(find "$(EXPORT_PATH)" -name '*.ipa' -print -quit)"

clean:
	rm -rf .build
	rm -rf ~/Library/Developer/Xcode/DerivedData/OpenVibble-*
