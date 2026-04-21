# OpenVibble · iOS Hardware Buddy Bridge

[English](./README.md) | [中文](./README.zh-CN.md)

<p align="center">
  <img src="./docs/readme/icon.png" alt="OpenVibble Icon" width="120" height="120" />
</p>

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-FA7343" />
  <img alt="License" src="https://img.shields.io/badge/License-AGPLv3-3DA639" />
</p>

OpenVibble is an iPhone app that pairs with Claude Desktop over BLE (Nordic UART Service) and acts as a "hardware buddy" on iOS.

<p align="center"><strong>M5Stack dev board still on the way? Start with OpenVibble first.</strong></p>

## Screenshots

| Claude Desktop Connected | iOS App | Dynamic Island |
| --- | --- | --- |
| ![Claude Desktop connected](./docs/readme/connected.png) | ![OpenVibble app main screen](./docs/readme/iphone-main.png) | ![OpenVibble Live Activity in Dynamic Island](./docs/readme/dynamic-island.jpg) |

It keeps the buddy runtime on your phone and supports:
- BLE pairing with Claude Desktop Hardware Buddy mode
- Prompt approval/deny actions from the phone UI
- Persona state transitions (idle/attention/busy/sleep/dizzy/celebrate/heart)
- Motion-based interactions (shake and face-down detection)
- Built-in and transferred GIF character packs
- Live Activity status surface

## Requirements

- macOS with Xcode 17+
- iOS deployment target: 18.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- A physical iPhone for BLE peripheral advertising (Simulator has BLE limits)

## Quick Start

```sh
make bootstrap
open OpenVibble.xcodeproj
```

Or build from command line:

```sh
make build
```

Run package tests + app tests:

```sh
make test
```

## Pair With Claude Desktop

1. In Claude Desktop, enable Developer mode and open `Developer -> Hardware Buddy`.
2. Launch OpenVibble on iPhone and grant Bluetooth permission.
3. Keep Bluetooth powered on, then select your phone in Claude Desktop.

Notes:
- iOS controls BLE/GAP behavior, so some low-level options from MCU firmware are not available.
- Character packs transferred from desktop are saved under app sandbox storage and appear in species/persona pickers automatically.

## Project Structure

- `OpenVibbleApp/`: iOS app target (UI, onboarding, settings, motion, resources)
- `OpenVibbleLiveActivity/`: Live Activity extension
- `Packages/OpenVibbleKit/`: shared Swift package modules
  - `BridgeRuntime`
  - `NUSPeripheral`
  - `BuddyProtocol`
  - `BuddyStorage`
  - `BuddyPersona`
  - `BuddyStats`
  - `BuddyUI`

## Useful Commands

```sh
make bootstrap   # Generate Xcode project from project.yml
make build       # Build app for simulator target
make test        # Swift package tests + Xcode tests
make run-sim     # Install and launch on simulator
make tf-package  # Build and export App Store IPA (no upload)
make testflight  # Build, export, and upload to TestFlight
make clean       # Remove build artifacts
```

## TestFlight Upload

Use App Store Connect API Key (recommended):

```sh
make testflight \
  ASC_KEY_ID=YOUR_KEY_ID \
  ASC_ISSUER_ID=YOUR_ISSUER_ID \
  ASC_KEY_FILEPATH=$HOME/Downloads/AuthKey_YOUR_KEY_ID.p8
```

Optional version controls:

```sh
make testflight MARKETING_VERSION=1.0.1 BUMP_BUILD=1 ...
```

Fallback with Apple ID + app-specific password:

```sh
make testflight \
  APPLE_ID=you@example.com \
  APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
```

## Localization

The app currently includes English (`en`) and Simplified Chinese (`zh-Hans`) resources.

## License

GNU Affero General Public License v3.0. See [LICENSE](./LICENSE).
