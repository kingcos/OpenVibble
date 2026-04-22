# Contributing to OpenVibble

Thanks for your interest! This guide covers everything you need to build the project locally and submit a change.

## Prerequisites

- macOS with **Xcode 17+**
- **iOS 18.0+** physical device (the iOS Simulator does **not** support BLE peripheral advertising — you cannot run OpenVibble end-to-end on it)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Apple Developer account (the free personal team is enough)

## First-time setup

```sh
git clone https://github.com/kingcos/OpenVibble.git
cd OpenVibble
make bootstrap   # runs `xcodegen generate`
open OpenVibble.xcodeproj
```

### One-time configuration in your fork

The repository ships with no signing identity baked in, so you need to fill it in once:

1. **Bundle identifier** — `kingcos.me.openvibble*` is the upstream namespace and only the repo owner can sign with it. Open `project.yml` and replace the four `PRODUCT_BUNDLE_IDENTIFIER` values (app, live activity, tests, desktop) with your own reverse-DNS prefix, e.g. `com.example.openvibble`. Update the matching `CFBundleURLName` entry under `CFBundleURLTypes` too. Then re-run `make bootstrap`.
2. **Apple Developer Team ID** — supply it via the `DEVELOPMENT_TEAM` environment variable when invoking the Makefile targets that sign:

   ```sh
   make testflight DEVELOPMENT_TEAM=ABCDE12345 ...
   ```

   For local debug builds (`make build`, `make test`) signing is disabled (`CODE_SIGNING_ALLOWED=NO`) and no team is needed.

> ⚠️ Please do **not** commit your team ID to `project.yml`.

## Build and test

```sh
make build   # compiles for a generic iOS Simulator destination
make test    # runs SwiftPM tests in Packages/OpenVibbleKit + the iOS test bundle
```

Run the app on a connected device from Xcode (`⌘R`). Pair it with Claude Desktop or with **OpenVibbleDesktop** (also in this workspace) — see the README for the pairing flow.

## Code style

- Swift 6, follow the surrounding code's conventions.
- Keep comments terse — explain *why*, not *what*. The codebase deliberately avoids ceremonial doc-comments.
- Localize user-facing strings via `Localizable.xcstrings` (English + Simplified Chinese are the supported locales).
- Each new Swift file should start with the MPL-2.0 header used by existing files.

## Pull request checklist

Before opening a PR:

- [ ] `make test` passes
- [ ] No personal Team ID, hard-coded paths, or local secrets in the diff
- [ ] User-visible strings have both `en` and `zh-Hans` translations
- [ ] PR description has reproducible steps if you're fixing a bug, or a screenshot/recording if you changed UI

Issues and PRs are welcome. For larger changes, opening an issue first to discuss the approach helps avoid wasted work.

## Reporting security issues

Please do **not** file public issues for security vulnerabilities. See [SECURITY.md](./SECURITY.md) for the private reporting channel.
