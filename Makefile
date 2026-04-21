PROJECT := OpenVibble.xcodeproj
SCHEME := OpenVibbleApp
CONFIGURATION := Debug
SIMULATOR_NAME ?= iPhone 17
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR_NAME)
GENERIC_DESTINATION := generic/platform=iOS Simulator
PACKAGE_DIR := Packages/OpenVibbleKit

.PHONY: bootstrap build test run-sim clean

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

clean:
	rm -rf .build
	rm -rf ~/Library/Developer/Xcode/DerivedData/OpenVibble-*
