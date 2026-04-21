import SwiftUI

/// Terminal-style overlay mirroring the firmware's in-device menu tree
/// (h5-demo MENU / SETTINGS / RESET). Purely local — no BLE traffic.
struct DeviceMenuOverlay: View {
    @ObservedObject var state: DeviceMenuState

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                header
                Divider().background(TerminalStyle.lcdDivider)
                if state.resetOpen {
                    list(title: "[RESET]", items: resetRows, selected: state.resetIndex)
                } else if state.settingsOpen {
                    list(title: "[SETTINGS]", items: settingsRows, selected: state.settingsIndex)
                } else if state.menuOpen {
                    list(title: "[MENU]", items: DeviceMenuState.menuItems, selected: state.menuIndex)
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack {
            Text("DEVICE MENU")
                .font(TerminalStyle.display(18))
                .tracking(2)
                .foregroundStyle(TerminalStyle.ink)
                .shadow(color: TerminalStyle.accent.opacity(0.45), radius: 0, x: 1, y: 1)
            Spacer()
            Text(currentCrumb)
                .font(TerminalStyle.mono(10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(TerminalStyle.inkDim)
        }
    }

    private var currentCrumb: String {
        if state.resetOpen { return "menu / settings / reset" }
        if state.settingsOpen { return "menu / settings" }
        return "menu"
    }

    private var settingsRows: [String] {
        DeviceMenuState.settingsItems.map { label -> String in
            switch label {
            case "brightness": return "brightness    \(state.brightness)/4"
            case "sound":      return "sound         \(state.sound ? "on" : "off")"
            case "bluetooth":  return "bluetooth     \(state.bt ? "on" : "off")"
            case "wifi":       return "wifi          \(state.wifi ? "on" : "off")"
            case "led":        return "led           \(state.led ? "on" : "off")"
            case "transcript": return "transcript    \(state.hud ? "on" : "off")"
            case "clock rot":  return "clock rot     \(clockRotLabel)"
            case "ascii pet":  return "ascii pet     ▸"
            case "reset":      return "reset         ▸"
            case "back":       return "back          ◂"
            default:           return label
            }
        }
    }

    private var clockRotLabel: String {
        switch state.clockRot {
        case 1: return "portrait"
        case 2: return "landscape"
        default: return "auto"
        }
    }

    private var resetRows: [String] {
        DeviceMenuState.resetItems.map { $0 == "confirm" ? "confirm ⚠" : "cancel" }
    }

    @ViewBuilder
    private func list(title: String, items: [String], selected: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(TerminalStyle.mono(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(TerminalStyle.accentSoft)
            ForEach(Array(items.enumerated()), id: \.offset) { idx, label in
                row(label: label, isSelected: idx == selected)
            }
        }
    }

    @ViewBuilder
    private func row(label: String, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Text(isSelected ? "▶" : " ")
                .font(TerminalStyle.mono(13, weight: .bold))
                .foregroundStyle(isSelected ? TerminalStyle.accent : TerminalStyle.inkDim)
            Text(label)
                .font(TerminalStyle.mono(13, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? TerminalStyle.lcdBg : TerminalStyle.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isSelected ? TerminalStyle.ink : Color.clear,
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            footerHint("A:long", "close")
            footerHint("A:short", "next")
            footerHint("B:short", "apply")
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(10, weight: .semibold))
    }

    private func footerHint(_ key: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(key).foregroundStyle(TerminalStyle.accentSoft)
            Text(value).foregroundStyle(TerminalStyle.inkDim)
        }
    }
}

/// Screen-off opaque mask. A short-press on any handheld button wakes.
struct ScreenOffMask: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("— screen off —")
                .font(TerminalStyle.mono(10, weight: .semibold))
                .foregroundStyle(TerminalStyle.inkDim.opacity(0.35))
        }
    }
}
