# Claude Buddy Bridge · iOS

iPhone app that pairs with **Claude Desktop** over Bluetooth Low Energy (Nordic UART Service) and acts as the "Hardware Buddy" — replacing the ESP32 firmware from [claude-desktop-buddy](https://github.com/claude-desktop-buddy-main). The buddy lives on your iPhone: it reacts to Claude Desktop sessions, lets you approve/deny permission prompts, and levels up as tokens accumulate.

## Requirements

- iOS 18+
- Xcode 17+ with command-line tools
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A real device — BLE peripheral advertising is **not** supported on the iOS Simulator

## Build

```sh
xcodegen generate
open ClaudeBuddyBridge.xcodeproj
# or: xcodebuild -project ClaudeBuddyBridge.xcodeproj -scheme ClaudeBuddyBridgeApp build
```

Unit tests:
```sh
swift test --package-path Packages/ClaudeBuddyKit
```

## Pairing with Claude Desktop

1. Enable Developer Mode in Claude Desktop, open **Developer → Hardware Buddy**.
2. Launch Claude Buddy Bridge on your iPhone. It starts BLE advertising on the Nordic UART Service.
3. Rename your iPhone to start with `Claude` (iOS Settings → General → About → Name, e.g. `Claude`, `Claude-iPhone`). iOS does not let apps override the GAP device name, so the scanner matches on the system name.
4. Select your device in Claude Desktop's Hardware Buddy panel.

When Claude Desktop pushes a character pack, it lands in `~/Library/Containers/com.kingcos.ClaudeBuddyBridge/.../Application Support/ClaudeBuddyBridge/characters/<name>/` and appears in the species picker (pawprint button) automatically.

## Controls

| Gesture | Effect |
|---|---|
| Shake | Dizzy animation (2s) |
| Face-down ≥ 3s | Sleep — accumulates nap time |
| Face-up | Wake back to idle/busy |
| Long-press buddy | Main menu (Stats / Species / Info) |
| Pawprint icon (top-right) | Species picker |
| Prompt → approve within 5s | Heart animation (2s) |
| Tokens cross 50K threshold | Level-up celebration (3s) |

The Terminal tab keeps the low-level debug view: connection status, event log, advertising controls, and diagnostic callbacks.

## iOS limitations vs ESP32 firmware

| Not ported | Why |
|---|---|
| BLE passkey bonding / encrypted-only | CoreBluetooth peripheral has no ACL API |
| Custom GAP device name | iOS doesn't let apps override the GAP name — use the system name |
| LCD brightness / rotation / LEDs / buzzer | No corresponding hardware on iPhone |
| 17 additional ASCII species (cat-only here) | GIF packs pushed from Claude Desktop fill this role |
| Demo / idle auto-walk modes | When BLE isn't connected, buddy stays idle |
| `heap` and millivolt/milliamp battery fields in status ack | No iOS API; reported as 0 / percent-only |

Status ack reports the real iPhone battery level (`UIDevice.batteryLevel/batteryState`) and real stats (approvals, denials, median response time, nap seconds, level).

## Architecture

- **BuddyProtocol / NUSPeripheral / BuddyStorage** — NDJSON framing, BLE peripheral, file landing
- **BuddyPersona** — `PersonaState` enum, `derivePersonaState`, manifest parsing, installed-character catalog
- **BuddyStats** — `PersonaStats` + `PersonaStatsStore` with UserDefaults persistence and first-sight token latch
- **BuddyUI** — `ASCIIBuddyView` (TimelineView), `GIFPlayer` (ImageIO + Timer frame advance)
- **BridgeRuntime** — heartbeat ingest, snapshot/prompt/transfer state, `StatusSample` cache
- **ClaudeBuddyBridgeApp** — `PersonaController` (overlay priority tree), `MotionSensor` (CMMotionManager), `HomeScreen`, `PetStatsScreen`, `InfoScreen`, `MainMenuSheet`, settings & terminal `ContentView`
