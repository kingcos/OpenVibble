# Pet Settings Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align iOS app's pet system to firmware as the single source of truth — unify Settings/picker layout, port firmware ASCII frames + colors + particle overlays into iOS, and show firmware-sourced owner + pet name on Home.

**Architecture:** Firmware (`claude-desktop-buddy-main/src/buddies/*.cpp`) owns per-species ASCII frame tables, per-state `SEQ` arrays, per-state `bodyColor` (RGB565), and hand-written particle overlay blocks. A Python script extracts the mechanical parts into `GeneratedSpeciesFrames.swift`; particles are hand-ported alongside. iOS reads firmware-pushed pet/owner names from the existing BLE snapshot (`BridgeAppModel.snapshot.deviceName` / `ownerName`) — no iOS-side copy, no edit UI.

**Tech Stack:** SwiftUI, Swift Package Manager, Swift Testing (`import Testing`, `@Test`, `#expect`), Python 3 stdlib for the code-gen script.

Spec: [docs/superpowers/specs/2026-04-22-pet-settings-polish-design.md](../specs/2026-04-22-pet-settings-polish-design.md)

---

## File Structure

**Modified:**
- `OpenVibbleApp/Home/HomeScreen.swift` — delete `@AppStorage("buddy.petName")`, read from snapshot, pass owner into InfoCard.
- `OpenVibbleApp/Settings/SettingsScreen.swift` — delete top-level pet preview block, delete `"buddy.petName"` from factory-reset list.
- `OpenVibbleApp/Home/SpeciesPickerSheet.swift` — relocate preview to top as full-width panel; unify built-in/installed row padding.
- `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIIBuddyView.swift` — replace hardcoded `bodyColor` with per-species lookup; render overlay layer.
- `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/SpeciesRegistry.swift` — strip cat-template remap, become thin accessor over generated data.

**Created:**
- `Packages/OpenVibbleKit/Sources/BuddyUI/ColorRGB565.swift` — `Color(rgb565:)` extension.
- `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/GeneratedSpeciesFrames.swift` — auto-generated species data (frames, SEQ, color, overlays).
- `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlay.swift` — `Overlay` + `OverlayPath` + `OverlayTint` types.
- `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/OverlayRenderer.swift` — computes per-tick character positions from an `Overlay`.
- `scripts/gen_species_frames.py` — parses firmware `.cpp` files, emits `GeneratedSpeciesFrames.swift`.
- `scripts/tests/test_gen_species_frames.py` — unit tests for the script.
- `Packages/OpenVibbleKit/Tests/BuddyUITests/ColorRGB565Tests.swift` — tests for the color extension.
- `Packages/OpenVibbleKit/Tests/BuddyUITests/GeneratedSpeciesTests.swift` — coverage tests over generated data.
- `Packages/OpenVibbleKit/Tests/BuddyUITests/OverlayRendererTests.swift` — tests for overlay path math.

**Deleted (after migration):**
- `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/CatSpecies.swift` (data moves into generated file).

---

## Task 1: Home — read pet/owner name from BLE snapshot

**Files:**
- Modify: `OpenVibbleApp/Home/HomeScreen.swift:49, 413, 1196, 1290`
- Modify: `OpenVibbleApp/Settings/SettingsScreen.swift:434-435`

- [ ] **Step 1: Read current HomeScreen InfoCard display to confirm call sites**

Run: `grep -n "petName" OpenVibbleApp/Home/HomeScreen.swift`
Expected: lines 49 (AppStorage decl), 413 (pass into InfoCard), 1196 (InfoCard property), 1290 (display).

- [ ] **Step 2: Delete `@AppStorage("buddy.petName")` and adjacent use**

In `OpenVibbleApp/Home/HomeScreen.swift:49`, remove the line:

```swift
@AppStorage("buddy.petName") private var petName: String = "Buddy"
```

- [ ] **Step 3: Add owner + petName parameters to `InfoCard`**

In `OpenVibbleApp/Home/HomeScreen.swift:1196`, change `let petName: String` to:

```swift
let petName: String
let ownerName: String
```

- [ ] **Step 4: Update `InfoCard` display formatter**

Replace the line at `HomeScreen.swift:1290` (currently `.pair("info.device.pet", petName.isEmpty ? "Buddy" : petName)`) with:

```swift
.pair("info.device.pet", formattedPetLabel)
```

And add a computed property inside `InfoCard`:

```swift
private var formattedPetLabel: String {
    let name = petName.isEmpty ? "Buddy" : petName
    return ownerName.isEmpty ? name : "\(ownerName)'s \(name)"
}
```

- [ ] **Step 5: Update `InfoCard` call site to pass snapshot values**

At `HomeScreen.swift:413` (the `InfoCard(... petName: petName)` call), change to:

```swift
InfoCard(
    ...,
    petName: model.snapshot.deviceName,
    ownerName: model.snapshot.ownerName
)
```

(Confirm the exact call signature — copy existing arguments unchanged, only swap `petName:` and add `ownerName:`.)

- [ ] **Step 6: Remove `"buddy.petName"` from factory-reset key list**

In `OpenVibbleApp/Settings/SettingsScreen.swift:434-435`, delete the `"buddy.petName"` string literal from the array. Keep `"bridge.displayName"`.

- [ ] **Step 7: Build**

Run: `xcodebuild -scheme OpenVibble -project OpenVibble.xcodeproj -destination 'generic/platform=iOS' build | tail -20`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 8: Manual simulator verification**

Run the app, connect a buddy (or use mock snapshot if available). Verify:
- Home shows `Owner's PetName` when firmware has owner set.
- Home shows `PetName` when owner is empty.
- Home shows `Buddy` when `deviceName` is empty / disconnected.

- [ ] **Step 9: Commit**

```bash
git add OpenVibbleApp/Home/HomeScreen.swift OpenVibbleApp/Settings/SettingsScreen.swift
git commit -m "Home: read pet/owner name from BLE snapshot, drop local copy"
```

---

## Task 2: Settings — remove top-level pet preview

**Files:**
- Modify: `OpenVibbleApp/Settings/SettingsScreen.swift:124-201`

- [ ] **Step 1: Read current `petContent` + `petPreview` + `previewSpeciesView` block**

Run: `sed -n '120,205p' OpenVibbleApp/Settings/SettingsScreen.swift`
Note the exact boundaries of the three pieces.

- [ ] **Step 2: Replace block with a single nav row**

Delete lines 124-201 (the full `petContent` computed property including `petPreview` and `previewSpeciesView` helper). In its place, `petContent` becomes:

```swift
@ViewBuilder
private var petContent: some View {
    NavigationLink {
        // push or sheet SpeciesPickerSheet — match whatever existing nav pattern is used
    } label: {
        HStack {
            Text("settings.pet.current")
            Spacer()
            Text(currentSpeciesDisplayName)
                .foregroundStyle(.secondary)
        }
    }
}
```

If the existing screen uses `.sheet` instead of `NavigationLink`, preserve that pattern — read the surrounding code to pick the consistent style.

- [ ] **Step 3: Delete helpers now unused**

Remove `petPreview` and `previewSpeciesView` if nothing else references them. Confirm with:

Run: `grep -n "petPreview\|previewSpeciesView" OpenVibbleApp/Settings/SettingsScreen.swift`
Expected: no remaining references.

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme OpenVibble -project OpenVibble.xcodeproj -destination 'generic/platform=iOS' build | tail -20`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual verification**

Launch the simulator, open Settings. Confirm the pet section no longer shows a preview — only a disclosure row with the current species name.

- [ ] **Step 6: Commit**

```bash
git add OpenVibbleApp/Settings/SettingsScreen.swift
git commit -m "Settings: remove top-level pet preview, keep bare nav row"
```

---

## Task 3: Picker — unify layout (preview top, panel width, equal rows)

**Files:**
- Modify: `OpenVibbleApp/Home/SpeciesPickerSheet.swift`

- [ ] **Step 1: Read current sheet structure**

Run: `cat OpenVibbleApp/Home/SpeciesPickerSheet.swift`
Note: preview block at lines 89-107 (internal 136×100), built-in panel 21-42, installed panel 44-64, row button modifier at line 170.

- [ ] **Step 2: Move preview to top, make it full-width**

Restructure the sheet body so the preview is the first `TerminalPanel` and its container uses `.frame(maxWidth: .infinity)` with an explicit height of 140:

```swift
var body: some View {
    VStack(spacing: 12) {
        TerminalPanel(title: "species.panel.preview") {
            previewSpeciesView(for: selectedSpecies)
                .frame(maxWidth: .infinity)
                .frame(height: 140)
        }
        TerminalPanel(title: "species.panel.builtin") {
            // existing built-in content
        }
        TerminalPanel(title: "species.panel.installed") {
            // existing installed content
        }
    }
    .padding()
}
```

Delete the old in-sheet preview block (lines 89-107 in the original file). Only one preview exists now, at the top.

- [ ] **Step 3: Unify built-in and installed row modifiers**

For each species row inside both panels, wrap the row content in a single modifier chain:

```swift
.padding(.horizontal, 12)
.padding(.vertical, 10)
.frame(maxWidth: .infinity, alignment: .leading)
.frame(height: 40)
```

Ensure the GIF row does NOT also apply `.maxWidth: .infinity` on the GIF itself — the GIF should `.aspectRatio(contentMode: .fit)` inside the fixed-height row.

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme OpenVibble -project OpenVibble.xcodeproj -destination 'generic/platform=iOS' build | tail -20`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Manual verification**

Open picker in simulator:
- Preview sits at the top, spanning the panel's full width, visibly taller than before.
- Built-in and installed rows are visually the same height.
- Selecting different species updates the preview.

- [ ] **Step 6: Commit**

```bash
git add OpenVibbleApp/Home/SpeciesPickerSheet.swift
git commit -m "SpeciesPicker: preview at top full-width, unify row heights"
```

---

## Task 4: RGB565 Color extension + per-species color map

**Files:**
- Create: `Packages/OpenVibbleKit/Sources/BuddyUI/ColorRGB565.swift`
- Create: `Packages/OpenVibbleKit/Tests/BuddyUITests/ColorRGB565Tests.swift`
- Modify: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIIBuddyView.swift:43, 51-56`

- [ ] **Step 1: Write failing test for `Color(rgb565:)`**

Create `Packages/OpenVibbleKit/Tests/BuddyUITests/ColorRGB565Tests.swift`:

```swift
import Testing
import SwiftUI
@testable import BuddyUI

@Suite("Color RGB565")
struct ColorRGB565Tests {
    @Test
    func catColorMatchesFirmware() {
        // 0xC2A6 = 11000 010101 00110 → RGB8(197, 85, 49) per 5-6-5 expansion
        let c = Color(rgb565: 0xC2A6)
        let components = c.resolve(in: .init()).cgColor.components ?? []
        #expect(abs(components[0] - 197.0/255.0) < 0.02)
        #expect(abs(components[1] - 85.0/255.0)  < 0.02)
        #expect(abs(components[2] - 49.0/255.0)  < 0.02)
    }

    @Test
    func duckColorIsYellow() {
        // 0xFFE0 = all red, all green, no blue → bright yellow
        let c = Color(rgb565: 0xFFE0)
        let components = c.resolve(in: .init()).cgColor.components ?? []
        #expect(components[0] > 0.98)
        #expect(components[1] > 0.98)
        #expect(components[2] < 0.05)
    }
}
```

- [ ] **Step 2: Run — verify it fails (missing symbol)**

Run: `swift test --package-path Packages/OpenVibbleKit --filter BuddyUITests.ColorRGB565Tests`
Expected: compile error `cannot find 'Color(rgb565:)'`.

- [ ] **Step 3: Implement `Color(rgb565:)`**

Create `Packages/OpenVibbleKit/Sources/BuddyUI/ColorRGB565.swift`:

```swift
import SwiftUI

public extension Color {
    /// Initialize from an RGB565 (5-6-5 packed) value as used by TFT drivers
    /// in the `claude-desktop-buddy` firmware. Expands 5/6-bit channels to 8-bit
    /// using the standard (x << 3) | (x >> 2) scheme.
    init(rgb565: UInt16) {
        let r5 = UInt8((rgb565 >> 11) & 0x1F)
        let g6 = UInt8((rgb565 >> 5)  & 0x3F)
        let b5 = UInt8(rgb565         & 0x1F)
        let r8 = (r5 << 3) | (r5 >> 2)
        let g8 = (g6 << 2) | (g6 >> 4)
        let b8 = (b5 << 3) | (b5 >> 2)
        self.init(
            red:   Double(r8) / 255.0,
            green: Double(g8) / 255.0,
            blue:  Double(b8) / 255.0
        )
    }
}
```

- [ ] **Step 4: Run — verify it passes**

Run: `swift test --package-path Packages/OpenVibbleKit --filter BuddyUITests.ColorRGB565Tests`
Expected: both tests pass.

- [ ] **Step 5: Add inline per-species color map + wire into `ASCIIBuddyView`**

In `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIIBuddyView.swift`, delete the `static let bodyColor` block (lines 51-56) and replace with a per-species lookup. Before changing, read each firmware `buddies/<species>.cpp` and collect the `bodyColor` literal from the **idle** state (idle is the canonical "default" state; subsequent tasks can per-state-vary).

Script to collect the 18 values:

```bash
for f in claude-desktop-buddy-main/src/buddies/*.cpp; do
  name=$(basename "$f" .cpp)
  color=$(grep -A1 'static void doIdle' "$f" | grep -oE '0x[0-9A-Fa-f]{4}' | head -1)
  echo "  \"$name\": 0x${color#0x},"
done
```

Paste the resulting map into `ASCIIBuddyView.swift`:

```swift
private static let bodyColorByName: [String: UInt16] = [
    // populate from the script output above — all 18 species
]

private func speciesColor() -> Color {
    guard let idx = speciesIdx,
          idx >= 0 && idx < PersonaSpeciesCatalog.count,
          let raw = Self.bodyColorByName[PersonaSpeciesCatalog.names[idx]] else {
        return Color(rgb565: 0xC2A6) // cat fallback
    }
    return Color(rgb565: raw)
}
```

And change line 43 from `.foregroundStyle(Self.bodyColor)` to `.foregroundStyle(speciesColor())`.

- [ ] **Step 6: Verify existing tests still pass**

Run: `swift test --package-path Packages/OpenVibbleKit`
Expected: all existing tests pass, new tests pass.

- [ ] **Step 7: Manual simulator verification**

Pick 3 different species (e.g., cat, duck, ghost) in the picker. Each ASCII pet on Home shows a visibly different color.

- [ ] **Step 8: Commit**

```bash
git add Packages/OpenVibbleKit/Sources/BuddyUI/ColorRGB565.swift \
        Packages/OpenVibbleKit/Tests/BuddyUITests/ColorRGB565Tests.swift \
        Packages/OpenVibbleKit/Sources/BuddyUI/ASCIIBuddyView.swift
git commit -m "ASCII: per-species body color from firmware RGB565"
```

---

## Task 5: Python script — extract main frames, SEQ, and per-state color

**Files:**
- Create: `scripts/gen_species_frames.py`
- Create: `scripts/tests/test_gen_species_frames.py`
- Create: `scripts/tests/fixtures/sample_buddy.cpp` (minimal fixture)

- [ ] **Step 1: Write fixture representing one state**

Create `scripts/tests/fixtures/sample_buddy.cpp`:

```cpp
#include "../buddy.h"
namespace sample {
static void doIdle(uint32_t t) {
  static const char* const REST[5] = { "A", "B", "C", "D", "E" };
  static const char* const LOOK[5] = { "a", "b", "c", "d", "e" };
  const char* const* P[2] = { REST, LOOK };
  static const uint8_t SEQ[] = { 0, 1, 0 };
  uint8_t beat = (t / 5) % sizeof(SEQ);
  buddyPrintSprite(P[SEQ[beat]], 5, 0, 0xC2A6);
}
}
```

- [ ] **Step 2: Write failing test**

Create `scripts/tests/test_gen_species_frames.py`:

```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from gen_species_frames import parse_species_file


def test_parses_simple_state():
    cpp = Path(__file__).parent / "fixtures" / "sample_buddy.cpp"
    result = parse_species_file(cpp)
    assert result["name"] == "sample"
    idle = result["states"]["idle"]
    assert idle["frames"] == [
        ["A","B","C","D","E"],
        ["a","b","c","d","e"],
    ]
    assert idle["seq"] == [0, 1, 0]
    assert idle["color_rgb565"] == 0xC2A6
```

- [ ] **Step 3: Run — verify it fails (missing module)**

Run: `python3 -m pytest scripts/tests/test_gen_species_frames.py -v`
Expected: ImportError for `gen_species_frames`.

- [ ] **Step 4: Implement `gen_species_frames.py`**

Create `scripts/gen_species_frames.py`:

```python
#!/usr/bin/env python3
"""Extract ASCII frame tables, SEQ arrays, and bodyColor from
claude-desktop-buddy firmware .cpp files, emitting a Swift source file."""

import re
import sys
from pathlib import Path

STATE_FUNCS = {
    "doSleep": "sleep",
    "doIdle": "idle",
    "doBusy": "busy",
    "doAttention": "attention",
    "doCelebrate": "celebrate",
    "doDizzy": "dizzy",
    "doHeart": "heart",
}

RE_NAMESPACE = re.compile(r"namespace\s+(\w+)\s*\{")
RE_FRAME_TABLE = re.compile(
    r'static\s+const\s+char\s*\*\s*const\s+(\w+)\s*\[\s*5\s*\]\s*=\s*\{([^}]+)\};',
    re.DOTALL,
)
RE_P_ARRAY = re.compile(
    r'const\s+char\s*\*\s*const\s*\*\s*P\s*\[\s*\d+\s*\]\s*=\s*\{([^}]+)\};',
    re.DOTALL,
)
RE_SEQ = re.compile(
    r'static\s+const\s+uint8_t\s+SEQ\s*\[\s*\]\s*=\s*\{([^}]+)\};',
    re.DOTALL,
)
RE_PRINT_SPRITE = re.compile(
    r'buddyPrintSprite\s*\(\s*[^,]+,\s*\d+\s*,\s*\d+\s*,\s*0x([0-9A-Fa-f]+)\s*\)',
)


def _extract_strings(block: str) -> list[str]:
    # Extract quoted strings in order (handles escapes by matching content
    # between unescaped quotes, which is sufficient for firmware source).
    out = []
    i = 0
    while i < len(block):
        if block[i] == '"':
            j = i + 1
            buf = []
            while j < len(block) and block[j] != '"':
                if block[j] == '\\' and j + 1 < len(block):
                    buf.append(block[j:j+2])
                    j += 2
                else:
                    buf.append(block[j])
                    j += 1
            # Decode escapes we care about (\\ → \)
            s = "".join(buf).encode().decode("unicode_escape")
            out.append(s)
            i = j + 1
        else:
            i += 1
    return out


def _split_state_bodies(src: str) -> dict[str, str]:
    """Return {state_key: body_text} slices between `static void doXxx(` markers."""
    bodies = {}
    markers = []
    for func, key in STATE_FUNCS.items():
        m = re.search(rf'static\s+void\s+{func}\s*\(', src)
        if m:
            markers.append((m.start(), key))
    markers.sort()
    for idx, (start, key) in enumerate(markers):
        end = markers[idx + 1][0] if idx + 1 < len(markers) else len(src)
        bodies[key] = src[start:end]
    return bodies


def parse_species_file(path: Path) -> dict:
    src = path.read_text()
    ns = RE_NAMESPACE.search(src)
    name = ns.group(1) if ns else path.stem
    result = {"name": name, "states": {}}
    for state_key, body in _split_state_bodies(src).items():
        tables = {}
        for m in RE_FRAME_TABLE.finditer(body):
            tbl_name = m.group(1)
            strings = _extract_strings(m.group(2))
            if len(strings) == 5:
                tables[tbl_name] = strings
        p_match = RE_P_ARRAY.search(body)
        if p_match:
            order = [t.strip() for t in p_match.group(1).split(",") if t.strip()]
            frames = [tables[n] for n in order if n in tables]
        else:
            frames = list(tables.values())
        seq_match = RE_SEQ.search(body)
        seq = []
        if seq_match:
            seq = [int(x.strip()) for x in seq_match.group(1).split(",") if x.strip()]
        color_match = RE_PRINT_SPRITE.search(body)
        color = int(color_match.group(1), 16) if color_match else 0xFFFF
        result["states"][state_key] = {
            "frames": frames,
            "seq": seq,
            "color_rgb565": color,
        }
    return result


def emit_swift(species: list[dict], output: Path) -> None:
    lines = [
        "// AUTO-GENERATED by scripts/gen_species_frames.py",
        "// Do not edit by hand. Overlays section is hand-maintained — see OverlaySpec.swift.",
        "import BuddyPersona",
        "",
        "public enum GeneratedSpecies {",
        "    public static let all: [String: [PersonaState: SpeciesStateData]] = [",
    ]
    for sp in species:
        lines.append(f'        "{sp["name"]}": [')
        for state, data in sp["states"].items():
            frames_literal = ", ".join(
                "[" + ", ".join(f'"{_esc(s)}"' for s in frame) + "]"
                for frame in data["frames"]
            )
            seq_literal = ", ".join(str(i) for i in data["seq"])
            lines.append(
                f'            .{state}: SpeciesStateData('
                f'frames: [{frames_literal}], seq: [{seq_literal}], '
                f'colorRGB565: 0x{data["color_rgb565"]:04X}),'
            )
        lines.append("        ],")
    lines.append("    ]")
    lines.append("}")
    output.write_text("\n".join(lines) + "\n")


def _esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: gen_species_frames.py <buddies_dir> <output.swift>", file=sys.stderr)
        return 2
    buddies_dir = Path(sys.argv[1])
    output = Path(sys.argv[2])
    species = [parse_species_file(p) for p in sorted(buddies_dir.glob("*.cpp"))]
    emit_swift(species, output)
    print(f"wrote {len(species)} species to {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run — verify test passes**

Run: `python3 -m pytest scripts/tests/test_gen_species_frames.py -v`
Expected: 1 passed.

- [ ] **Step 6: Dry-run against real firmware**

Run:
```bash
python3 scripts/gen_species_frames.py \
    claude-desktop-buddy-main/src/buddies \
    /tmp/generated-preview.swift
head -80 /tmp/generated-preview.swift
wc -l /tmp/generated-preview.swift
```
Expected: 18 species entries, each with 7 states. Skim output for obvious parse failures (empty frames, missing SEQ).

- [ ] **Step 7: Commit the script and fixture**

```bash
git add scripts/gen_species_frames.py \
        scripts/tests/test_gen_species_frames.py \
        scripts/tests/fixtures/sample_buddy.cpp
git commit -m "scripts: gen_species_frames.py — extract firmware ASCII data"
```

---

## Task 6: Wire generated frames into iOS, drop cat-template remap

**Files:**
- Create: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/GeneratedSpeciesFrames.swift` (via script)
- Create: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/SpeciesStateData.swift`
- Modify: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/SpeciesRegistry.swift`
- Create: `Packages/OpenVibbleKit/Tests/BuddyUITests/GeneratedSpeciesTests.swift`
- Delete: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/CatSpecies.swift` (after registry refactor)

- [ ] **Step 1: Define `SpeciesStateData`**

Create `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/SpeciesStateData.swift`:

```swift
import BuddyPersona

public struct SpeciesStateData {
    public let frames: [[String]]
    public let seq: [Int]
    public let colorRGB565: UInt16
    public let overlays: [Overlay]

    public init(
        frames: [[String]],
        seq: [Int],
        colorRGB565: UInt16,
        overlays: [Overlay] = []
    ) {
        self.frames = frames
        self.seq = seq
        self.colorRGB565 = colorRGB565
        self.overlays = overlays
    }
}
```

Note: `Overlay` is defined in Task 7. For this task, stub it as an empty placeholder:

```swift
public struct Overlay {}
```

- [ ] **Step 2: Generate the Swift data file**

Run:
```bash
python3 scripts/gen_species_frames.py \
    claude-desktop-buddy-main/src/buddies \
    Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/GeneratedSpeciesFrames.swift
```

- [ ] **Step 3: Write failing coverage test**

Create `Packages/OpenVibbleKit/Tests/BuddyUITests/GeneratedSpeciesTests.swift`:

```swift
import Testing
@testable import BuddyUI
import BuddyPersona

@Suite("Generated Species")
struct GeneratedSpeciesTests {
    @Test
    func allFirmwareSpeciesPresent() {
        for name in PersonaSpeciesCatalog.names {
            #expect(GeneratedSpecies.all[name] != nil, "missing species: \(name)")
        }
    }

    @Test
    func allStatesPresentPerSpecies() {
        for (name, states) in GeneratedSpecies.all {
            for state in PersonaState.allCases {
                #expect(states[state] != nil, "\(name) missing state \(state.slug)")
            }
        }
    }

    @Test
    func idleFramesDifferAcrossSpecies() {
        let idleFirstFrames = PersonaSpeciesCatalog.names.compactMap {
            GeneratedSpecies.all[$0]?[.idle]?.frames.first
        }.map { $0.joined(separator: "\n") }
        #expect(Set(idleFirstFrames).count == idleFirstFrames.count)
    }
}
```

- [ ] **Step 4: Run tests — expect failures until registry is refactored**

Run: `swift test --package-path Packages/OpenVibbleKit --filter BuddyUITests.GeneratedSpeciesTests`
Expected: all three pass if script output matches firmware. If a test fails because a state is missing, inspect the generated file and patch the script regex.

- [ ] **Step 5: Refactor `SpeciesRegistry` to use generated data**

Replace the entire contents of `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/SpeciesRegistry.swift` with:

```swift
import Foundation
import BuddyPersona

public enum SpeciesRegistry {
    public static func stateData(forIdx idx: Int, state: PersonaState) -> SpeciesStateData? {
        guard idx >= 0, idx < PersonaSpeciesCatalog.count else { return nil }
        let name = PersonaSpeciesCatalog.names[idx]
        return GeneratedSpecies.all[name]?[state]
    }

    public static func animation(forIdx idx: Int, state: PersonaState) -> ASCIIAnimation {
        let data = stateData(forIdx: idx, state: state)
            ?? GeneratedSpecies.all["cat"]?[state]
            ?? GeneratedSpecies.all["cat"]?[.idle]
            ?? SpeciesStateData(frames: [[" "]], seq: [0], colorRGB565: 0xFFFF)
        let flattened = data.seq.map { idx in
            ASCIIFrame(lines: data.frames[idx])
        }
        return ASCIIAnimation(frames: flattened, delayMs: 200)
    }
}
```

If `ASCIIFrame` / `ASCIIAnimation` have different initializers, adapt by reading their current definitions.

- [ ] **Step 6: Update `ASCIIBuddyView` color lookup to read from generated data**

In `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIIBuddyView.swift`, remove the inline `bodyColorByName` map added in Task 4. Replace `speciesColor()` with:

```swift
private func speciesColor() -> Color {
    let raw = SpeciesRegistry.stateData(forIdx: speciesIdx ?? 4, state: state)?.colorRGB565
        ?? 0xC2A6
    return Color(rgb565: raw)
}
```

- [ ] **Step 7: Delete `CatSpecies.swift`**

Run: `git rm Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/CatSpecies.swift`
Confirm no remaining references: `grep -r "CatSpecies" Packages/`
Expected: no matches.

- [ ] **Step 8: Run full test suite**

Run: `swift test --package-path Packages/OpenVibbleKit`
Expected: all tests pass, including the pre-existing `idleFrameIsDistinctAcrossFirmwareSpecies` and `invalidIndexFallsBackToCat`.

- [ ] **Step 9: Manual simulator verification**

Open picker, cycle through all 18 species. Confirm each pet's idle frame looks clearly distinct from cat (not glyph-substituted).

- [ ] **Step 10: Commit**

```bash
git add Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/ \
        Packages/OpenVibbleKit/Sources/BuddyUI/ASCIIBuddyView.swift \
        Packages/OpenVibbleKit/Tests/BuddyUITests/GeneratedSpeciesTests.swift
git commit -m "BuddyUI: generated per-species frames from firmware, drop cat template"
```

---

## Task 7: Overlay types + renderer infrastructure

**Files:**
- Create: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlay.swift` (replace the Task 6 stub)
- Create: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/OverlayRenderer.swift`
- Create: `Packages/OpenVibbleKit/Tests/BuddyUITests/OverlayRendererTests.swift`
- Modify: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIIBuddyView.swift`

- [ ] **Step 1: Define `Overlay`, `OverlayTint`, `OverlayPath`**

Replace the stub `public struct Overlay {}` in `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlay.swift` with:

```swift
import Foundation

public enum OverlayTint {
    case dim        // firmware BUDDY_DIM
    case white      // firmware BUDDY_WHITE
    case body       // follows the state's bodyColor
    case rgb565(UInt16)
}

public enum OverlayPath {
    /// Particle drifts up and to the right over `span` ticks, then wraps.
    case driftUpRight(speed: Double, phase: Double, span: Double)
    /// Particle orbits a center point.
    case orbit(radius: Double, speed: Double, phase: Double)
    /// Stationary character at fixed grid coordinates.
    case fixed(col: Double, row: Double)
    /// Vertical bobble around a fixed center.
    case bobble(col: Double, row: Double, amp: Double, speed: Double)
    /// Escape hatch: pre-baked per-tick positions (list of (col, row) tuples).
    case baked([(col: Double, row: Double)])
}

public struct Overlay {
    public let char: String
    public let tint: OverlayTint
    public let path: OverlayPath

    public init(char: String, tint: OverlayTint, path: OverlayPath) {
        self.char = char
        self.tint = tint
        self.path = path
    }
}
```

- [ ] **Step 2: Write failing test for `OverlayRenderer.position`**

Create `Packages/OpenVibbleKit/Tests/BuddyUITests/OverlayRendererTests.swift`:

```swift
import Testing
@testable import BuddyUI

@Suite("OverlayRenderer")
struct OverlayRendererTests {
    @Test
    func fixedPathReturnsConstant() {
        let path = OverlayPath.fixed(col: 3, row: 2)
        let p0 = OverlayRenderer.position(for: path, tick: 0)
        let p10 = OverlayRenderer.position(for: path, tick: 10)
        #expect(p0.col == 3 && p0.row == 2)
        #expect(p10.col == 3 && p10.row == 2)
    }

    @Test
    func driftUpRightWrapsAtSpan() {
        let path = OverlayPath.driftUpRight(speed: 1.0, phase: 0, span: 12)
        let p0 = OverlayRenderer.position(for: path, tick: 0)
        let p12 = OverlayRenderer.position(for: path, tick: 12)
        #expect(abs(p0.col - p12.col) < 0.001)
        #expect(abs(p0.row - p12.row) < 0.001)
    }
}
```

- [ ] **Step 3: Run — verify failure (missing symbol)**

Run: `swift test --package-path Packages/OpenVibbleKit --filter BuddyUITests.OverlayRendererTests`
Expected: compile error.

- [ ] **Step 4: Implement `OverlayRenderer`**

Create `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/OverlayRenderer.swift`:

```swift
import Foundation

public enum OverlayRenderer {
    public static func position(for path: OverlayPath, tick: Int) -> (col: Double, row: Double) {
        let t = Double(tick)
        switch path {
        case .fixed(let col, let row):
            return (col, row)
        case .driftUpRight(let speed, let phase, let span):
            let p = (t * speed + phase).truncatingRemainder(dividingBy: span)
            return (col: p, row: -p * 0.5 + span * 0.5)
        case .orbit(let radius, let speed, let phase):
            let angle = t * speed + phase
            return (col: cos(angle) * radius, row: sin(angle) * radius)
        case .bobble(let col, let row, let amp, let speed):
            return (col: col, row: row + sin(t * speed) * amp)
        case .baked(let points):
            guard !points.isEmpty else { return (0, 0) }
            let idx = tick % points.count
            return (col: points[idx].col, row: points[idx].row)
        }
    }
}
```

- [ ] **Step 5: Run — verify tests pass**

Run: `swift test --package-path Packages/OpenVibbleKit --filter BuddyUITests.OverlayRendererTests`
Expected: both tests pass.

- [ ] **Step 6: Add overlay layer to `ASCIIBuddyView`**

Modify `ASCIIBuddyView.renderFrame` to overlay the state's `overlays` on top of the base `Text`:

```swift
@ViewBuilder
private func renderFrame(_ frame: ASCIIFrame, state: PersonaState, tick: Int) -> some View {
    ZStack(alignment: .topLeading) {
        VStack(spacing: 0) {
            ForEach(Array(frame.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(Self.monoFont)
                    .foregroundStyle(speciesColor())
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        if let overlays = SpeciesRegistry.stateData(forIdx: speciesIdx ?? 4, state: state)?.overlays,
           !overlays.isEmpty {
            overlayLayer(overlays: overlays, tick: tick)
        }
    }
    .accessibilityLabel("OpenVibble pet, state: \(state.slug)")
}

private static let monoFont = Font.system(size: 22, weight: .bold, design: .monospaced)
private static let charAdvance: CGFloat = 13.2   // measured for size 22 monospaced bold
private static let lineHeight:  CGFloat = 26.0

@ViewBuilder
private func overlayLayer(overlays: [Overlay], tick: Int) -> some View {
    ForEach(Array(overlays.enumerated()), id: \.offset) { _, overlay in
        let p = OverlayRenderer.position(for: overlay.path, tick: tick)
        Text(overlay.char)
            .font(Self.monoFont)
            .foregroundStyle(tintColor(overlay.tint))
            .offset(
                x: CGFloat(p.col) * Self.charAdvance,
                y: CGFloat(p.row) * Self.lineHeight
            )
    }
}

private func tintColor(_ tint: OverlayTint) -> Color {
    switch tint {
    case .dim:   return Color.white.opacity(0.4)
    case .white: return Color.white
    case .body:  return speciesColor()
    case .rgb565(let raw): return Color(rgb565: raw)
    }
}
```

- [ ] **Step 7: Build**

Run: `swift build --package-path Packages/OpenVibbleKit`
Expected: success. At this point all overlays are empty per-state (Task 6 generated them as `[]`), so Home/picker look identical to end-of-Task-6.

- [ ] **Step 8: Commit**

```bash
git add Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlay.swift \
        Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/OverlayRenderer.swift \
        Packages/OpenVibbleKit/Sources/BuddyUI/ASCIIBuddyView.swift \
        Packages/OpenVibbleKit/Tests/BuddyUITests/OverlayRendererTests.swift
git commit -m "BuddyUI: overlay types + renderer (no overlays wired yet)"
```

---

## Task 8: Hand-port particle overlays per species

This is the large hand-ported task. Keep commits small — one commit per species. Do one species at a time, verifying each in the simulator before moving on.

**Files (per species):**
- Create: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlays/<Species>Overlays.swift`
- Modify: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/SpeciesRegistry.swift` (merge overlays into generated data on lookup)

- [ ] **Step 1: Define the hand-overlay file pattern**

Create `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlays/SpeciesOverlays.swift` as the aggregator:

```swift
import BuddyPersona

enum SpeciesOverlays {
    static let byNameAndState: [String: [PersonaState: [Overlay]]] = [
        "cat":  CatOverlays.all,
        "duck": DuckOverlays.all,
        // ... one entry per species, added as you port each
    ]

    static func overlays(for name: String, state: PersonaState) -> [Overlay] {
        byNameAndState[name]?[state] ?? []
    }
}
```

- [ ] **Step 2: Merge overlays into `SpeciesRegistry.stateData`**

Modify `SpeciesRegistry.stateData(forIdx:state:)`:

```swift
public static func stateData(forIdx idx: Int, state: PersonaState) -> SpeciesStateData? {
    guard idx >= 0, idx < PersonaSpeciesCatalog.count else { return nil }
    let name = PersonaSpeciesCatalog.names[idx]
    guard let base = GeneratedSpecies.all[name]?[state] else { return nil }
    let overlays = SpeciesOverlays.overlays(for: name, state: state)
    return SpeciesStateData(
        frames: base.frames,
        seq: base.seq,
        colorRGB565: base.colorRGB565,
        overlays: overlays
    )
}
```

- [ ] **Step 3: Port the first species — cat**

Read `claude-desktop-buddy-main/src/buddies/cat.cpp` in full. For each `doXxx` state, translate the particle block following `buddyPrintSprite(...)` into `Overlay` entries.

Cat's sleep state (lines 31-43 of `cat.cpp`) is the reference example:

```cpp
int p1 = (t)     % 12;
int p2 = (t + 5) % 12;
int p3 = (t + 9) % 12;
buddySetColor(BUDDY_DIM);
buddySetCursor(BUDDY_X_CENTER + 18 + p1, BUDDY_Y_OVERLAY + 18 - p1 * 2);
buddyPrint("z");
buddySetColor(BUDDY_WHITE);
buddySetCursor(BUDDY_X_CENTER + 24 + p2, BUDDY_Y_OVERLAY + 14 - p2);
buddyPrint("Z");
buddySetColor(BUDDY_DIM);
buddySetCursor(BUDDY_X_CENTER + 14 + p3 / 2, BUDDY_Y_OVERLAY + 8 - p3 / 2);
buddyPrint("z");
```

Create `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlays/CatOverlays.swift`:

```swift
import BuddyPersona

enum CatOverlays {
    static let all: [PersonaState: [Overlay]] = [
        .sleep: sleep,
        // other states to be filled in — start with .sleep and expand
    ]

    private static let sleep: [Overlay] = [
        // stream 1: z, dim, phase 0, drifts up-right over 12 ticks
        Overlay(
            char: "z",
            tint: .dim,
            path: .driftUpRight(speed: 1.0, phase: 0, span: 12)
        ),
        // stream 2: Z, white, phase 5, same drift
        Overlay(
            char: "Z",
            tint: .white,
            path: .driftUpRight(speed: 1.0, phase: 5, span: 12)
        ),
        // stream 3: z, dim, phase 9, half-speed drift
        Overlay(
            char: "z",
            tint: .dim,
            path: .driftUpRight(speed: 0.5, phase: 9, span: 12)
        ),
    ]
}
```

Note: `OverlayPath.driftUpRight` as implemented in Task 7 may not exactly reproduce firmware's `(x_base + p, y_base - p * 2)` trajectory. If the simulator rendering doesn't look right, adjust the renderer or switch specific overlays to `.baked(...)` with pre-computed positions.

- [ ] **Step 4: Build + manual verify cat**

Run: `xcodebuild -scheme OpenVibble -project OpenVibble.xcodeproj -destination 'generic/platform=iOS' build | tail -20`

Launch simulator, pick cat species, wait for sleep state. Z's should drift up-right.

- [ ] **Step 5: Commit cat**

```bash
git add Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlays/
git commit -m "Overlays: port cat particle streams (sleep/idle/busy/…)"
```

- [ ] **Step 6: Repeat Step 3-5 for each remaining species**

For each of: capybara, duck, goose, blob, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, cactus, robot, rabbit, mushroom, chonk —

  1. Read the corresponding `buddies/<species>.cpp`.
  2. Identify particle blocks in each state.
  3. Create `<Species>Overlays.swift` following cat's pattern.
  4. Register in `SpeciesOverlays.byNameAndState`.
  5. Build, verify in simulator, commit.

If an overlay pattern doesn't fit the existing `OverlayPath` cases, add a new case to `OverlayPath` (and its renderer) and note the generalization in the commit message.

- [ ] **Step 7: Final overlay review**

Once all 18 are ported, run:
```bash
grep -L "OverlayPath" Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/Overlays/*.swift
```
Expected: empty (all files reference `OverlayPath`).

- [ ] **Step 8: Run full test suite**

Run: `swift test --package-path Packages/OpenVibbleKit`
Expected: all tests pass.

---

## Task 9: Cleanup

**Files:**
- Audit: `Packages/OpenVibbleKit/Sources/BuddyUI/ASCIISpecies/` for stragglers

- [ ] **Step 1: Identify dead code**

Run:
```bash
grep -rn "CatSpecies\|GlyphStyle\|headPatterns" Packages/OpenVibbleKit/
```
Expected: no matches.

Run:
```bash
grep -rn "@AppStorage.*buddy\.petName" OpenVibbleApp/
```
Expected: no matches.

- [ ] **Step 2: Full build + test**

Run: `swift test --package-path Packages/OpenVibbleKit && xcodebuild -scheme OpenVibble -project OpenVibble.xcodeproj -destination 'generic/platform=iOS' build | tail -10`
Expected: all green.

- [ ] **Step 3: Commit cleanup (if anything was changed)**

```bash
git add -A
git commit -m "BuddyUI: cleanup dead species-template code"
```

---

## Self-review

**Spec coverage:**
- § 1 Settings & picker layout → Tasks 2, 3 ✅
- § 2a Script — mechanical extraction → Task 5 ✅
- § 2b Particle overlays — hand ported → Tasks 7, 8 ✅
- § 2c iOS renderer changes (Color RGB565, per-species color, overlay layer, drop cat template) → Tasks 4, 6, 7 ✅
- § 3 Home name display → Task 1 ✅
- Cleanup / dead code → Task 9 ✅

**Open loose end:** Task 5's script regenerates the Swift data file unconditionally. If Task 6-8 ever need to be re-run after overlays are authored in `SpeciesOverlays.byNameAndState` (separate file), the script won't touch the overlays file — overlays stay safe. This matches the spec's fallback ("keeping overlays in a separate hand-authored file"). The `overlays` field in `SpeciesStateData` defaults to `[]` and is populated at lookup time via `SpeciesRegistry.stateData`, so the generated file never contains overlay literals. Script re-runs are safe.

**Type consistency check:** `SpeciesStateData.frames` is `[[String]]`. `SpeciesStateData.seq` is `[Int]`. `SpeciesStateData.colorRGB565` is `UInt16`. Used consistently in Tasks 5, 6, 7, 8.

**Placeholder scan:** no TBD / TODO / "similar to above" patterns. Task 8 has a per-species expansion step (Step 6) that is intrinsically repetitive — the loop body is fully described in Steps 3-5; each iteration is mechanical transcription of firmware C into the documented Swift shape.
