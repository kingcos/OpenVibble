# Pet Settings Polish — Design

Date: 2026-04-22
Status: Approved, ready for implementation plan

## Problem

Three concrete issues in the iOS app's pet system:

1. **Settings / picker layout** — the top-level Settings screen shows a pet preview (shouldn't). The second-level picker has preview 136×100 (misaligned with list panel width), and the built-in vs installed sections have inconsistent row heights (ASCII rows and GIF rows use different padding).
2. **ASCII parity drift** — all 18 species render with a single hardcoded color `RGB(197,85,49)` and are shape-remapped from a cat template via glyph substitution. Firmware (`claude-desktop-buddy-main/src/buddies/*.cpp`) defines per-species hand-drawn 5-line ASCII frames with per-species `bodyColor` (RGB565). iOS has drifted from firmware in both shape and color.
3. **Name display** — firmware supports pet name + owner name (stored in ESP Preferences, displayed as "Owner's PetName" when owner is set). iOS has a separate `@AppStorage("buddy.petName")` local copy that duplicates state and is never synced. Home only shows pet name, not owner. BLE delivers firmware names to iOS already (`BridgeRuntime.swift:195-199` populates `snapshotStorage.deviceName` / `ownerName` when the firmware writes `name` / `owner` commands).

## Principle

**Firmware is the single source of truth.** Anywhere iOS duplicates firmware state, delete the iOS copy and read through whatever BLE already gives us.

## Goals

1. Remove top-level preview from Settings; unify second-level picker layout so built-in / installed rows and the preview all feel like one coherent component.
2. Port firmware ASCII frames (main frames + SEQ + per-species color + particle overlays) into iOS so every species visibly differs from cat and color-matches firmware.
3. Display both owner and pet name on Home, sourced from the existing BLE snapshot. No editing UI.

## Non-goals

- Any name **editing** flow (firmware has no on-device input; Desktop app handles edits; iOS stays read-only for names).
- BLE write ack UI (since iOS won't be writing names).
- Picker search / sort / grouping changes beyond layout unification.
- Firmware changes of any kind.
- Live animation timing fidelity to firmware at the millisecond level — we aim for visual parity, not clock-perfect replay.

---

## Design

### 1. Settings & picker layout

**`OpenVibbleApp/Settings/SettingsScreen.swift`**
- Lines 124–201 (`petContent` + `petPreview` + `previewSpeciesView`): **delete the entire preview block**.
- The pet section becomes a single row: title + current species name + chevron, tapping pushes/sheets the picker (existing `SpeciesPickerSheet`).

**`OpenVibbleApp/Home/SpeciesPickerSheet.swift`**
- Move the preview to the **top of the sheet** as its own `TerminalPanel`, width `.maxWidth: .infinity` (aligned with built-in / installed panels below), height ~140pt.
- Delete the in-sheet 136×100 preview block (lines 89–107). Only one preview on screen.
- Built-in (lines 21–42) and Installed (lines 44–64) sections: unify row modifier to `.padding(.horizontal, 12).padding(.vertical, 10)`. GIF rows no longer expand with `.maxWidth: .infinity`; constrain to same height as ASCII rows (~40pt).

### 2. ASCII parity with firmware

#### 2a. Script — mechanical extraction

New script `scripts/gen_species_frames.py` (Python 3, stdlib only).

For each `claude-desktop-buddy-main/src/buddies/<species>.cpp`:
- Parse each `doSleep / doIdle / doBusy / doAttention / doCelebrate / doDizzy / doHeart` function.
- Extract all `static const char* const NAME[5] = { "...", "...", "...", "...", "..." };` tables. Result per state: `{ name -> [5 strings] }`.
- Extract `const char* const* P[N] = { NAME, NAME2, ... };` to learn frame-index-to-table mapping.
- Extract `static const uint8_t SEQ[] = { ... };` as the playback sequence.
- Extract `buddyPrintSprite(..., 0xNNNN);` and take the RGB565 literal as the state's body color.

Output: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/GeneratedSpeciesFrames.swift`

Shape (pseudo-Swift):

```swift
public struct SpeciesStateData {
    public let frames: [[String]]      // N frame tables, each 5 strings
    public let seq: [Int]              // indices into frames
    public let colorRGB565: UInt16
    public let overlays: [Overlay]     // populated in 2b; [] if none
}

public enum GeneratedSpecies {
    public static let all: [String: [BuddyAnimationState: SpeciesStateData]] = [
        "cat":  [ .sleep: ..., .idle: ..., ... ],
        "duck": [ ... ],
        ...
    ]
}
```

The script is committed. When firmware frames change, re-run the script; diff is reviewable.

#### 2b. Particle overlays — hand ported

Each firmware state function typically has a trailing block of `buddySetCursor + buddySetColor + buddyPrint` calls whose arguments are arithmetic on `t`. These are not regex-safe; port by reading the C and writing a Swift spec per overlay call.

New Swift model:

```swift
public struct Overlay {
    public let char: String             // "z" / "Z" / "*" / "♥" ...
    public let tint: OverlayTint        // .dim / .white / .body / custom RGB565
    public let path: OverlayPath        // drift function of t
}

public enum OverlayPath {
    case driftUpRight(speed: Double, phase: Double, span: Double)
    case orbit(radius: Double, speed: Double, phase: Double)
    case fixed(col: Double, row: Double)
    case bobble(col: Double, row: Double, amp: Double, speed: Double)
    // Add cases as we encounter patterns in firmware source.
}
```

Overlays are added directly into `GeneratedSpeciesFrames.swift` alongside the script-generated main frame data. When the script re-runs, it preserves manually-authored overlay blocks (merge key = species + state). Mechanism: script reads existing file, parses existing `overlays: [...]` entries, re-emits them unchanged while regenerating the rest. If the script can't cleanly preserve, fall back to keeping overlays in a separate hand-authored file `OverlaySpec.swift` that the Species registry merges at runtime.

Coordinate system: firmware uses pixel offsets (`BUDDY_X_CENTER + 18`). iOS converts these to **character grid offsets** using the monospaced font's per-character advance width, not raw pixels. The conversion factor becomes one constant in the renderer.

#### 2c. iOS renderer changes

- New `Color(rgb565: UInt16)` extension (likely in `BuddyUI/ColorRGB565.swift`).
- `ASCIIBuddyView.swift`:
  - Replace `Self.bodyColor` static with per-species lookup from `GeneratedSpecies`.
  - Compose view as: base `Text` for the current main frame (indexed via SEQ at `delayMs` interval) + overlay layer that iterates `state.overlays` and positions each `Overlay` via `.offset` using grid-to-point conversion, animated by a `TimelineView(.animation)` driving `t`.
- `SpeciesRegistry.swift`: delete the cat-template + glyph-remap path. The registry becomes a thin accessor over `GeneratedSpecies.all`.
- Delete now-dead files: any per-species Swift art (e.g., `CatSpecies.swift` if it only existed to feed the old registry). Keep anything still referenced.

### 3. Home name display

**`OpenVibbleApp/Home/HomeScreen.swift`**
- Delete `@AppStorage("buddy.petName") private var petName: String = "Buddy"` (line 49).
- Read `snapshot.deviceName` and `snapshot.ownerName` from `BridgeAppModel` (add observed getters if not already exposed).
- Pass both into `InfoCard`; replace `petName: String` param on `InfoCard` (line 1196) with `petName: String` + `ownerName: String`.
- Line 1290 display becomes:
  - `owner.isEmpty ? name : "\(owner)'s \(name)"`
  - Fallback when `name` is empty: `"Buddy"` (matches firmware default at `stats.h:213`).

**`OpenVibbleApp/Settings/SettingsScreen.swift`**
- Line 435: remove `"buddy.petName"` from the factory-reset UserDefaults key list.
- Keep `"bridge.displayName"` (separate concern: the bridge's own BLE advertised name).

**No changes to** `BridgeRuntime.swift` — `snapshotStorage.deviceName` / `ownerName` already update from incoming `name` / `owner` commands.

---

## Implementation phases (for commit cadence)

Each phase is independently buildable and gets its own commit.

1. **Names on Home** — smallest, touches 2 files. Delete `@AppStorage("buddy.petName")`, wire snapshot reads into Home, update factory reset. (Phase 3 in the design; done first because it's independent of the bigger ASCII work.)
2. **Settings & picker layout** — remove top-level preview, unify picker layout. (Design section 1.)
3. **RGB565 Color extension + per-species color** — add `Color(rgb565:)`, hand-copy the 18 `bodyColor` values from firmware `.cpp` files into a small inline Swift map, replace the single hardcoded color in `ASCIIBuddyView` with species-keyed lookup. No frame or overlay changes yet. Phase 4's script supersedes this map. (Incremental subset of section 2.)
4. **Script v1 — main frames + SEQ** — write `scripts/gen_species_frames.py` emitting the full data structure with empty `overlays: []`. Wire `SpeciesRegistry` through the generated data. Delete cat-template remap path. (Section 2a + the non-overlay portion of 2c.)
5. **Overlays — hand ported** — per-species, per-state: read firmware C, author `Overlay` entries. Can be committed pet-by-pet or state-by-state if it keeps commits small. (Section 2b.)
6. **Cleanup** — delete now-dead Swift species files, tidy imports.

## Risks / open questions

- **Script robustness.** Firmware files are consistently formatted today but not schema-guaranteed. Script should fail loud on parse mismatch (not silently skip) so drift is noticed.
- **Overlay pattern catalog.** We don't know the full set of motion patterns across 18 × 7 until we read them. If some pattern is too one-off to fit a reusable `OverlayPath` case, add a `.custom(frames: [[GridChar]])` escape hatch with pre-baked frames.
- **Font advance width.** Grid-to-point conversion assumes a stable monospaced advance; test on device with the actual font to confirm. If it drifts at different Dynamic Type sizes, pin the overlay layer to the same font sizing as the base.
- **GIF rows** (installed personas) have a different rendering path than ASCII rows; the unified padding in the picker must be verified not to clip GIF content that expected `.maxWidth: .infinity`.

## Open in this repo

Spec saved to `docs/superpowers/specs/2026-04-22-pet-settings-polish-design.md`. After user review, proceed to implementation plan via `writing-plans`.
