import SwiftUI
import UIKit

/// Terminal-style overlay mirroring the firmware's in-device menu tree
/// (h5-demo MENU / SETTINGS / RESET). Purely local — no BLE traffic.
struct DeviceMenuOverlay: View {
    @ObservedObject var state: DeviceMenuState
    /// Reserved height at the bottom that the overlay must NOT cover — keeps
    /// the handheld A/B buttons visible and tappable while the menu is open.
    let bottomReservedHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.96)
                VStack(alignment: .leading, spacing: 12) {
                    header
                    Divider().background(TerminalStyle.lcdDivider)
                    if state.resetOpen {
                        list(titleKey: "device.menu.section.reset",
                             rows: resetRows, selected: state.resetIndex)
                    } else if state.settingsOpen {
                        list(titleKey: "device.menu.section.settings",
                             rows: settingsRows, selected: state.settingsIndex)
                    } else if state.menuOpen {
                        list(titleKey: "device.menu.section.menu",
                             rows: menuRows, selected: state.menuIndex)
                    }
                    Spacer(minLength: 0)
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Transparent spacer leaves the handheld A/B/log bar exposed.
            Color.clear.frame(height: bottomReservedHeight)
        }
        .ignoresSafeArea(edges: .top)
    }

    private struct DisplayRow {
        let labelKey: LocalizedStringKey
        let trailing: String?
    }

    private var header: some View {
        HStack {
            Text("device.menu.title")
                .font(TerminalStyle.display(18))
                .tracking(2)
                .foregroundStyle(TerminalStyle.ink)
                .shadow(color: TerminalStyle.accent.opacity(0.45), radius: 0, x: 1, y: 1)
            Spacer()
            Text(currentCrumbKey)
                .font(TerminalStyle.mono(10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(TerminalStyle.inkDim)
        }
    }

    private var currentCrumbKey: LocalizedStringKey {
        if state.resetOpen { return "device.menu.crumb.reset" }
        if state.settingsOpen { return "device.menu.crumb.settings" }
        return "device.menu.crumb.menu"
    }

    private var menuRows: [DisplayRow] {
        DeviceMenuState.menuItems.map { id in
            DisplayRow(labelKey: DeviceMenuState.menuItemKey(id), trailing: nil)
        }
    }

    private var settingsRows: [DisplayRow] {
        DeviceMenuState.settingsItems.map { id in
            DisplayRow(
                labelKey: DeviceMenuState.settingsItemKey(id),
                trailing: settingsTrailing(for: id)
            )
        }
    }

    private func settingsTrailing(for id: String) -> String? {
        switch id {
        case "brightness": return "\(state.brightness)/4"
        case "sound":      return onOffLabel(state.sound)
        case "bluetooth":  return onOffLabel(state.bt)
        case "wifi":       return onOffLabel(state.wifi)
        case "led":        return onOffLabel(state.led)
        case "transcript": return onOffLabel(state.hud)
        case "clock rot":  return clockRotLabel
        case "ascii pet":  return "▸"
        case "reset":      return "▸"
        case "back":       return "◂"
        default:           return nil
        }
    }

    private func onOffLabel(_ v: Bool) -> String {
        v
            ? String(localized: "device.menu.value.on")
            : String(localized: "device.menu.value.off")
    }

    private var clockRotLabel: String {
        switch state.clockRot {
        case 1: return String(localized: "device.menu.value.portrait")
        case 2: return String(localized: "device.menu.value.landscape")
        default: return String(localized: "device.menu.value.auto")
        }
    }

    private var resetRows: [DisplayRow] {
        DeviceMenuState.resetItems.map { id in
            DisplayRow(
                labelKey: DeviceMenuState.resetItemKey(id),
                trailing: id == "confirm" ? "⚠" : nil
            )
        }
    }

    @ViewBuilder
    private func list(titleKey: LocalizedStringKey, rows: [DisplayRow], selected: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleKey)
                .font(TerminalStyle.mono(11, weight: .bold))
                .tracking(2)
                .foregroundStyle(TerminalStyle.accentSoft)
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                rowView(row, isSelected: idx == selected)
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: DisplayRow, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Text(isSelected ? "▶" : " ")
                .font(TerminalStyle.mono(13, weight: .bold))
                .foregroundStyle(isSelected ? TerminalStyle.accent : TerminalStyle.inkDim)

            HStack(spacing: 8) {
                Text(row.labelKey)
                    .font(TerminalStyle.mono(13, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? TerminalStyle.lcdBg : TerminalStyle.ink)
                Spacer(minLength: 6)
                if let trailing = row.trailing {
                    Text(trailing)
                        .font(TerminalStyle.mono(13, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? TerminalStyle.lcdBg : TerminalStyle.inkDim)
                }
            }
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
            footerHint("device.menu.hint.aLong",  "device.menu.hint.close")
            footerHint("device.menu.hint.aShort", "device.menu.hint.next")
            footerHint("device.menu.hint.bShort", "device.menu.hint.apply")
            Spacer(minLength: 0)
        }
        .font(TerminalStyle.mono(10, weight: .semibold))
    }

    private func footerHint(_ keyLabel: LocalizedStringKey, _ valueLabel: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Text(keyLabel).foregroundStyle(TerminalStyle.accentSoft)
            Text(valueLabel).foregroundStyle(TerminalStyle.inkDim)
        }
    }
}

/// Screen-off opaque mask. A short-press on any handheld button wakes the
/// screen, but the mask itself also accepts a tap anywhere — when the power
/// button is hidden, the handheld buttons are covered by the mask and the
/// user needs an unambiguous wake gesture.
struct ScreenOffMask: View {
    let onWake: () -> Void

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                Text("home.screenOff")
                    .font(TerminalStyle.mono(10, weight: .semibold))
                    .foregroundStyle(TerminalStyle.inkDim.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onWake()
            }
    }
}
