# OpenVibble Android

Android port of the OpenVibble iOS app. Targets Android 8.0+ (API 26) with BLE 5.0 support. Implements the Claude Desktop "Hardware Buddy" BLE NUS peripheral protocol so an Android phone can stand in for the M5Stack dev board.

The Android app is part of the OpenVibble 1.0.2 release line. It includes the phone-side buddy runtime, bilingual English / Simplified Chinese resources, an e-ink friendly default terminal theme, actionable prompt notifications, GIF persona packs, and parity-focused Compose screens for onboarding, home, settings, logs, help, and species selection.

## Project layout

Each Gradle module mirrors an iOS `OpenVibbleKit` target:

| Module | iOS equivalent | Purpose |
| --- | --- | --- |
| `:buddy-protocol` | `BuddyProtocol` | NDJSON codec + bridge message models (pure JVM) |
| `:nus-peripheral` | `NUSPeripheral` | BLE GATT server advertising the Nordic UART Service |
| `:buddy-persona` | `BuddyPersona` | Persona state machine, species manifest, catalog |
| `:buddy-stats` | `BuddyStats` | Persona stats + DataStore persistence |
| `:buddy-storage` | `BuddyStorage` | Character pack transfer / filesystem store |
| `:bridge-runtime` | `BridgeRuntime` | Heartbeat → project/session digestion for UI |
| `:buddy-ui` | `BuddyUI` | Compose primitives + ASCII species renderer |
| `:app` | `OpenVibbleApp` | Activity, ViewModel, Compose screens, notifications |

## Toolchain

- JDK 17
- Android Studio Ladybug (AGP 8.7.x) or newer
- Gradle 8.9 (bootstrapped via the wrapper; run `gradle wrapper` once to drop in the jar/scripts)

## Running

```sh
cd android
./gradlew :app:assembleDebug
./gradlew test
```

The debug APK is generated at `app/build/outputs/apk/debug/app-debug.apk`. A physical Android 8+ device is required for end-to-end BLE testing — the emulator cannot advertise BLE.

Release signing is not committed to the repository. Configure your local Android Studio / Gradle signing config before distributing a release APK or AAB.

## Not ported

- Live Activity (iOS Dynamic Island) — no equivalent on Android; intentionally out of scope.
- `NUSCentral` — that lives only in OpenVibble Desktop.
- `HookBridge` — desktop-only.
