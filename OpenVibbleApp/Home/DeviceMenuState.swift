import Foundation
import SwiftUI
import BuddyPersona
import BridgeRuntime
import BuddyStorage

/// Mirrors the firmware / h5-demo in-device menu state machine.
///
/// MENU → SETTINGS → RESET. The iOS native Settings sheet is a separate
/// concern and untouched; this overlay is the handheld-feel menu.
///
/// All settings values are persisted to @AppStorage and purely local —
/// firmware doesn't expose a BLE protocol for them.
@MainActor
final class DeviceMenuState: ObservableObject {
    // Navigation.
    @Published var menuOpen: Bool = false
    @Published var settingsOpen: Bool = false
    @Published var resetOpen: Bool = false
    @Published var screenOff: Bool = false

    @Published var menuIndex: Int = 0
    @Published var settingsIndex: Int = 0
    @Published var resetIndex: Int = 0

    // Persisted settings (mirrors h5 `sim.settings` defaults — h5-demo.html:665).
    @AppStorage("device.menu.brightness") var brightness: Int = 4
    @AppStorage("device.menu.sound") var sound: Bool = true
    @AppStorage("device.menu.bt") var bt: Bool = true
    @AppStorage("device.menu.wifi") var wifi: Bool = false
    @AppStorage("device.menu.led") var led: Bool = true
    @AppStorage("device.menu.hud") var hud: Bool = true
    @AppStorage("device.menu.clockRot") var clockRot: Int = 0

    // Menu labels — order matches h5 MENU_ITEMS / SETTINGS_ITEMS
    // (h5-demo.html:672-673).
    static let menuItems: [String] = [
        "settings", "turn off", "help", "about", "demo", "close"
    ]
    static let settingsItems: [String] = [
        "brightness", "sound", "bluetooth", "wifi", "led",
        "transcript", "clock rot", "ascii pet", "reset", "back"
    ]
    static let resetItems: [String] = ["confirm", "cancel"]

    // MARK: - Navigation

    func toggleMenu() {
        if resetOpen { resetOpen = false; resetIndex = 0; return }
        if settingsOpen { settingsOpen = false; settingsIndex = 0; return }
        menuOpen.toggle()
        if menuOpen { menuIndex = 0 }
    }

    func toggleScreen() {
        screenOff.toggle()
    }

    func wakeScreen() {
        screenOff = false
    }

    func advanceCursor() {
        if resetOpen {
            resetIndex = (resetIndex + 1) % Self.resetItems.count
        } else if settingsOpen {
            settingsIndex = (settingsIndex + 1) % Self.settingsItems.count
        } else if menuOpen {
            menuIndex = (menuIndex + 1) % Self.menuItems.count
        }
    }

    // MARK: - Apply (B short-press)

    /// Returns a short human description of what happened, for event logging.
    func applyCurrentSelection(
        cycleAsciiSpecies: () -> Void,
        onReset: () -> Void,
        onTurnOff: () -> Void,
        onDemo: () -> Void,
        onHelp: () -> Void,
        onAbout: () -> Void,
        onBluetoothChanged: (Bool) -> Void
    ) -> String? {
        if resetOpen {
            return applyReset(onReset: onReset)
        }
        if settingsOpen {
            return applySettings(
                cycleAsciiSpecies: cycleAsciiSpecies,
                onBluetoothChanged: onBluetoothChanged
            )
        }
        if menuOpen {
            return applyMenu(
                onTurnOff: onTurnOff,
                onDemo: onDemo,
                onHelp: onHelp,
                onAbout: onAbout
            )
        }
        return nil
    }

    private func applyMenu(
        onTurnOff: () -> Void,
        onDemo: () -> Void,
        onHelp: () -> Void,
        onAbout: () -> Void
    ) -> String? {
        let item = Self.menuItems[menuIndex]
        switch item {
        case "settings":
            settingsOpen = true
            settingsIndex = 0
        case "turn off":
            onTurnOff()
            screenOff = true
            menuOpen = false
        case "close":
            menuOpen = false
        case "demo":
            onDemo()
        case "help":
            onHelp()
        case "about":
            onAbout()
        default:
            break
        }
        return "menu → \(item)"
    }

    private func applySettings(
        cycleAsciiSpecies: () -> Void,
        onBluetoothChanged: (Bool) -> Void
    ) -> String? {
        let item = Self.settingsItems[settingsIndex]
        switch item {
        case "brightness":
            brightness = (brightness + 1) % 5
        case "sound":
            sound.toggle()
        case "bluetooth":
            bt.toggle()
            onBluetoothChanged(bt)
        case "wifi":
            wifi.toggle()
        case "led":
            led.toggle()
        case "transcript":
            hud.toggle()
        case "clock rot":
            clockRot = (clockRot + 1) % 3
        case "ascii pet":
            cycleAsciiSpecies()
        case "reset":
            resetOpen = true
            resetIndex = 1 // default highlight "cancel" for safety
        case "back":
            settingsOpen = false
            settingsIndex = 0
        default:
            break
        }
        return "settings → \(item)"
    }

    private func applyReset(onReset: () -> Void) -> String? {
        let item = Self.resetItems[resetIndex]
        switch item {
        case "confirm":
            onReset()
            resetOpen = false
            settingsOpen = false
            menuOpen = false
        case "cancel":
            resetOpen = false
        default:
            break
        }
        return "reset → \(item)"
    }

    // MARK: - Helpers

    var isAnyMenuVisible: Bool {
        menuOpen || settingsOpen || resetOpen
    }

    /// Visual brightness multiplier [0.3 ... 1.0] applied to the LCD body.
    /// Firmware dims the backlight; iOS simulates with an opacity overlay.
    var brightnessMultiplier: Double {
        let t = Double(max(0, min(4, brightness))) / 4.0
        return 0.3 + t * 0.7
    }

    // MARK: - Localization

    /// Internal item IDs stay in English (see `applyMenu` / `applySettings`
    /// switches) — this maps each ID to a `LocalizedStringKey` for display.
    static func menuItemKey(_ id: String) -> LocalizedStringKey {
        switch id {
        case "settings": return "device.menu.item.settings"
        case "turn off": return "device.menu.item.turnOff"
        case "help":     return "device.menu.item.help"
        case "about":    return "device.menu.item.about"
        case "demo":     return "device.menu.item.demo"
        case "close":    return "device.menu.item.close"
        default:         return LocalizedStringKey(id)
        }
    }

    static func settingsItemKey(_ id: String) -> LocalizedStringKey {
        switch id {
        case "brightness": return "device.menu.item.brightness"
        case "sound":      return "device.menu.item.sound"
        case "bluetooth":  return "device.menu.item.bluetooth"
        case "wifi":       return "device.menu.item.wifi"
        case "led":        return "device.menu.item.led"
        case "transcript": return "device.menu.item.transcript"
        case "clock rot":  return "device.menu.item.clockRot"
        case "ascii pet":  return "device.menu.item.asciiPet"
        case "reset":      return "device.menu.item.reset"
        case "back":       return "device.menu.item.back"
        default:           return LocalizedStringKey(id)
        }
    }

    static func resetItemKey(_ id: String) -> LocalizedStringKey {
        id == "confirm" ? "device.menu.item.confirm" : "device.menu.item.cancel"
    }
}

// MARK: - Persona species cycling

enum AsciiPetCycler {
    /// Cycle the local PersonaSelection to the next ascii species idx in
    /// firmware order. Only affects the ascii track; keeps GIF selection
    /// intact if current selection is builtin/installed (sets idx 4=cat
    /// as entry-point into ascii mode to match h5).
    static func next() {
        let current = PersonaSelection.load()
        let nextIdx: Int
        switch current {
        case .asciiSpecies(let idx):
            nextIdx = (idx + 1) % PersonaSpeciesCatalog.count
        case .asciiCat:
            nextIdx = 5 // after cat (4)
        case .builtin, .installed:
            nextIdx = 4 // enter ascii at cat
        }
        PersonaSelection.save(.asciiSpecies(idx: nextIdx))
    }
}
