import SwiftUI
import UIKit
import UserNotifications
import CoreBluetooth

/// Single-page guided setup. Three stacked step cards the user walks through
/// top-to-bottom:
///   1. Grant BLE + notification permission (explicit tap — no auto-prompt)
///   2. Rename the iPhone in Settings (copy a generated `claude.xxxx` name)
///   3. Skim the button cheat-sheet
///
/// The "Enter" CTA is disabled until BLE authorization reaches a usable state
/// (notDetermined resolved). Notification opt-in is encouraged but not gating.
struct OnboardingScreen: View {
    @ObservedObject var model: BridgeAppModel
    let onFinish: () -> Void

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var suggestedName: String = OnboardingScreen.makeSuggestedName()
    @State private var copied: Bool = false
    @State private var copyResetTask: Task<Void, Never>?
    @AppStorage("bridge.displayName") private var persistedDisplayName = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    stepPermission
                    stepRename
                    stepHelp
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 0) {
                Spacer()
                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 160)
                        .offset(y: 40),
                        alignment: .bottom
                    )
            }
        }
        .preferredColorScheme(.dark)
        .task { await refreshNotificationStatus() }
        .onChange(of: model.bluetoothAuthorization) { _, _ in
            // re-render when permission resolves
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("$ buddy --init")
                .font(TerminalStyle.mono(12, weight: .semibold))
                .foregroundStyle(TerminalStyle.inkDim)
            Text("onboarding.welcome.title")
                .font(TerminalStyle.display(32))
                .tracking(2)
                .foregroundStyle(TerminalStyle.ink)
                .shadow(color: TerminalStyle.accent.opacity(0.55), radius: 0, x: 2, y: 2)
            Text("onboarding.welcome.body")
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.inkDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Step 1 — Permissions

    private var stepPermission: some View {
        OnboardingStepCard(
            index: 1,
            title: "onboarding.step.permission.title",
            subtitle: "onboarding.step.permission.body",
            active: !permissionStepComplete,
            done: permissionStepComplete
        ) {
            VStack(alignment: .leading, spacing: 10) {
                permissionRow(
                    label: "onboarding.permission.ble",
                    status: bleStatusText,
                    color: bleStatusColor,
                    actionLabel: bleButtonLabel,
                    actionDisabled: bleButtonDisabled,
                    action: requestBluetooth
                )
                permissionRow(
                    label: "onboarding.permission.notification",
                    status: notificationStatusText,
                    color: notificationStatusColor,
                    actionLabel: notificationButtonLabel,
                    actionDisabled: notificationButtonDisabled,
                    action: requestNotification
                )
            }
        }
    }

    private func permissionRow(
        label: LocalizedStringKey,
        status: LocalizedStringKey,
        color: Color,
        actionLabel: LocalizedStringKey,
        actionDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(TerminalStyle.mono(12, weight: .semibold))
                    .foregroundStyle(TerminalStyle.ink)
                Spacer(minLength: 0)
                Text(status)
                    .font(TerminalStyle.mono(11))
                    .foregroundStyle(color)
            }
            Button(action: action) {
                Text(actionLabel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OnboardingFilledButtonStyle(
                foreground: actionDisabled ? TerminalStyle.inkDim : .white,
                background: actionDisabled
                    ? TerminalStyle.lcdPanel
                    : TerminalStyle.accent
            ))
            .disabled(actionDisabled)
        }
    }

    // MARK: - Step 2 — Rename device

    private var stepRename: some View {
        OnboardingStepCard(
            index: 2,
            title: "onboarding.step.rename.title",
            subtitle: "onboarding.step.rename.body",
            active: permissionStepComplete,
            done: false
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(suggestedName)
                        .font(TerminalStyle.mono(14, weight: .bold))
                        .foregroundStyle(TerminalStyle.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Button {
                        suggestedName = OnboardingScreen.makeSuggestedName()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(TerminalHeaderButtonStyle())
                    .accessibilityLabel(Text("onboarding.rename.shuffle"))

                    Button(action: copyName) {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .bold))
                            Text(copied ? "onboarding.rename.copied" : "onboarding.rename.copy")
                                .font(TerminalStyle.mono(11, weight: .semibold))
                        }
                    }
                    .buttonStyle(TerminalHeaderButtonStyle(fill: false))
                }
                .padding(10)
                .background(TerminalStyle.lcdPanel.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(TerminalStyle.inkDim.opacity(0.5), lineWidth: 1)
                )

                if canOpenSystemSettings {
                    Button(action: openSettings) {
                        HStack {
                            Image(systemName: "gear")
                            Text("onboarding.rename.openSettings")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OnboardingFilledButtonStyle(
                        foreground: .white,
                        background: TerminalStyle.accent.opacity(0.85)
                    ))
                } else {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(TerminalStyle.accentSoft)
                        Text("onboarding.rename.manualHint")
                            .font(TerminalStyle.mono(11))
                            .foregroundStyle(TerminalStyle.inkDim)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(TerminalStyle.lcdPanel.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Step 3 — Button cheat-sheet

    private var stepHelp: some View {
        OnboardingStepCard(
            index: 3,
            title: "onboarding.step.help.title",
            subtitle: "onboarding.step.help.body",
            active: permissionStepComplete,
            done: false
        ) {
            VStack(alignment: .leading, spacing: 8) {
                helpRow(key: "A", body: "onboarding.help.a")
                helpRow(key: "B", body: "onboarding.help.b")
                helpRow(key: "Log", body: "onboarding.help.log")
                helpRow(key: "⚙", body: "onboarding.help.gear")
            }
        }
    }

    private func helpRow(key: String, body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(key)
                .font(TerminalStyle.mono(11, weight: .bold))
                .foregroundStyle(TerminalStyle.lcdBg)
                .frame(width: 28, height: 22)
                .background(TerminalStyle.ink, in: RoundedRectangle(cornerRadius: 5))
            Text(body)
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Footer CTA

    private var footer: some View {
        VStack(spacing: 8) {
            Button {
                finalizeAndEnter()
            } label: {
                Text(permissionStepComplete ? "onboarding.cta.enter" : "onboarding.cta.needsPermission")
                    .font(TerminalStyle.mono(14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(permissionStepComplete ? Color.white : TerminalStyle.inkDim)
                    .background(
                        (permissionStepComplete ? TerminalStyle.accent : TerminalStyle.lcdPanel),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                (permissionStepComplete
                                    ? TerminalStyle.shellBottom.opacity(0.7)
                                    : TerminalStyle.inkDim.opacity(0.4)),
                                lineWidth: 1
                            )
                    )
            }
            .disabled(!permissionStepComplete)

            Button(action: finalizeAndEnter) {
                Text("onboarding.cta.skip")
                    .font(TerminalStyle.mono(11, weight: .semibold))
                    .foregroundStyle(TerminalStyle.inkDim)
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Actions

    private func requestBluetooth() {
        model.requestBluetoothAuthorization()
    }

    private func requestNotification() {
        Task {
            _ = await BuddyNotificationCenter.shared.requestAuthorizationIfNeeded()
            await refreshNotificationStatus()
        }
    }

    private func copyName() {
        UIPasteboard.general.string = suggestedName
        copied = true
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }

    private func openSettings() {
        if let url = URL(string: "App-prefs:root=General&path=About"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func finalizeAndEnter() {
        // Persist the suggested name only if the user hasn't set one yet —
        // don't overwrite a value they typed in Settings.
        if persistedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            persistedDisplayName = suggestedName
        }
        onFinish()
    }

    @MainActor
    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    // MARK: - Derived state

    /// BLE authorization is "good enough" once the user has made a decision
    /// (granted or denied). If they denied we still let them enter but surface
    /// the state later in the home status indicator.
    private var permissionStepComplete: Bool {
        switch model.bluetoothAuthorization {
        case .notDetermined: return false
        default: return true
        }
    }

    private var bleStatusText: LocalizedStringKey {
        switch model.bluetoothAuthorization {
        case .notDetermined: return "onboarding.permission.status.notDetermined"
        case .allowedAlways: return "onboarding.permission.status.allowed"
        case .restricted: return "onboarding.permission.status.restricted"
        case .denied: return "onboarding.permission.status.denied"
        @unknown default: return "onboarding.permission.status.unknown"
        }
    }

    private var bleStatusColor: Color {
        switch model.bluetoothAuthorization {
        case .allowedAlways: return TerminalStyle.good
        case .notDetermined: return TerminalStyle.accentSoft
        case .denied, .restricted: return TerminalStyle.bad
        @unknown default: return TerminalStyle.inkDim
        }
    }

    private var bleButtonLabel: LocalizedStringKey {
        switch model.bluetoothAuthorization {
        case .notDetermined: return "onboarding.permission.request"
        case .allowedAlways: return "onboarding.permission.granted"
        case .denied, .restricted: return "onboarding.permission.openSettings"
        @unknown default: return "onboarding.permission.request"
        }
    }

    private var bleButtonDisabled: Bool {
        model.bluetoothAuthorization == .allowedAlways
    }

    private var notificationStatusText: LocalizedStringKey {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "onboarding.permission.status.allowed"
        case .denied:
            return "onboarding.permission.status.denied"
        case .notDetermined:
            return "onboarding.permission.status.notDetermined"
        @unknown default:
            return "onboarding.permission.status.unknown"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return TerminalStyle.good
        case .notDetermined: return TerminalStyle.accentSoft
        case .denied: return TerminalStyle.bad
        @unknown default: return TerminalStyle.inkDim
        }
    }

    private var notificationButtonLabel: LocalizedStringKey {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "onboarding.permission.granted"
        case .denied:
            return "onboarding.permission.openSettings"
        case .notDetermined:
            return "onboarding.permission.request"
        @unknown default:
            return "onboarding.permission.request"
        }
    }

    private var notificationButtonDisabled: Bool {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    private var canOpenSystemSettings: Bool {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }

    // MARK: - Helpers

    /// `claude.xxxxx` with 5 hex chars — short enough to survive iOS's 29-byte
    /// advertisement-name cap even after the `Claude-` sanitization in
    /// `BridgeAppModel.sanitizedDisplayName`.
    static func makeSuggestedName() -> String {
        let chars = "0123456789abcdef"
        let suffix = String((0..<5).compactMap { _ in chars.randomElement() })
        return "claude.\(suffix)"
    }
}

// MARK: - Reusable step card

private struct OnboardingStepCard<Content: View>: View {
    let index: Int
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let active: Bool
    let done: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(badgeBackground)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(TerminalStyle.lcdBg)
                    } else {
                        Text("\(index)")
                            .font(TerminalStyle.mono(13, weight: .bold))
                            .foregroundStyle(badgeForeground)
                    }
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TerminalStyle.mono(13, weight: .bold))
                        .foregroundStyle(TerminalStyle.ink)
                    Text(subtitle)
                        .font(TerminalStyle.mono(11))
                        .foregroundStyle(TerminalStyle.inkDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            content()
                .padding(.leading, 38)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardStroke, lineWidth: active ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.2), value: active)
        .animation(.easeInOut(duration: 0.2), value: done)
    }

    private var badgeBackground: Color {
        if done { return TerminalStyle.good }
        return active ? TerminalStyle.accent : TerminalStyle.lcdPanel
    }

    private var badgeForeground: Color {
        if done { return TerminalStyle.lcdBg }
        return active ? .white : TerminalStyle.inkDim
    }

    private var cardBackground: Color {
        active ? TerminalStyle.lcdPanel.opacity(0.9) : TerminalStyle.lcdPanel.opacity(0.45)
    }

    private var cardStroke: Color {
        if done { return TerminalStyle.good.opacity(0.6) }
        return active ? TerminalStyle.accent.opacity(0.8) : TerminalStyle.inkDim.opacity(0.35)
    }
}

private struct OnboardingFilledButtonStyle: ButtonStyle {
    let foreground: Color
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalStyle.mono(12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                background.opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
    }
}
