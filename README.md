# OpenVibble · iOS Hardware Buddy App

English | [中文](./README.zh-CN.md)

<p align="center"><strong>M5Stack dev board still on the way? Start with OpenVibble first.</strong></p>

<p align="center">
  <img src="./docs/readme/icon.png" alt="OpenVibble Icon" width="120" height="120" />
</p>

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-FA7343" />
  <img alt="License" src="https://img.shields.io/badge/License-AGPLv3-3DA639" />
</p>

OpenVibble is an iOS app that pairs with Claude Desktop over BLE (Nordic UART Service) and acts as a "hardware buddy" on iOS.

It is designed as a companion app for [Claude Desktop Buddy](https://github.com/anthropics/claude-desktop-buddy), with iOS-native UX and runtime support.

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

1. In Claude Desktop, enable Developer mode from `Help -> Troubleshooting -> Enable Developer Mode`.
2. Open `Developer -> Open Hardware Buddy...`, click `Connect`, then pick your iOS device.
3. Launch OpenVibble on your iOS device and grant Bluetooth permission when prompted.

Notes:
- iOS controls BLE/GAP behavior, so some low-level options from MCU firmware are not available.
- Character packs transferred from desktop are saved under app sandbox storage and appear in species/persona pickers automatically.

## Contributing

Issues and pull requests are welcome. Please include reproducible steps and environment details when reporting bugs.

## Localization

The app currently includes English (`en`) and Simplified Chinese (`zh-Hans`) resources.

## License

GNU Affero General Public License v3.0. See [LICENSE](./LICENSE).
