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

.PHONY: bootstrap build test run-sim testflight clean

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
	@test -n "$(APPLE_ID)" || (echo "APPLE_ID is required. Example: make testflight APPLE_ID=you@example.com APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx" && exit 1)
	@test -n "$(APP_SPECIFIC_PASSWORD)" || (echo "APP_SPECIFIC_PASSWORD is required." && exit 1)
	mkdir -p "$(BUILD_DIR)" "$(EXPORT_PATH)"
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>method</key>' \
		'  <string>app-store</string>' \
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
		archive \
		-archivePath "$(ARCHIVE_PATH)"
	xcodebuild \
		-exportArchive \
		-archivePath "$(ARCHIVE_PATH)" \
		-exportPath "$(EXPORT_PATH)" \
		-exportOptionsPlist "$(EXPORT_OPTIONS_PLIST)"
	xcrun altool \
		--upload-app \
		--type ios \
		--file "$$(find "$(EXPORT_PATH)" -name '*.ipa' -print -quit)" \
		--username "$(APPLE_ID)" \
		--password "$(APP_SPECIFIC_PASSWORD)"

clean:
	rm -rf .build
	rm -rf ~/Library/Developer/Xcode/DerivedData/OpenVibble-*
