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
M5Stack dev board still on the way? Start with OpenVibble first.

## Screenshots

| Claude Desktop Connected | iPhone Running |
| --- | --- |
| ![Claude Desktop connected](./docs/readme/connected.png) | _Pending screenshot (`./docs/readme/iphone-running.png`)_ |

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
make clean       # Remove build artifacts
```

## Localization

The app currently includes English (`en`) and Simplified Chinese (`zh-Hans`) resources.

## License

GNU Affero General Public License v3.0. See [LICENSE](./LICENSE).
