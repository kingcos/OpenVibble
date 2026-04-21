import SwiftUI
import UIKit

struct OnboardingScreen: View {
    let onFinish: () -> Void
    @State private var page: Int = 0
    @AppStorage("buddy.showScanline") private var showScanline = true
    private let totalPages = 3

    var body: some View {
        ZStack {
            TerminalBackground(showScanline: showScanline)

            VStack(spacing: 0) {
                header
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    renamePage.tag(1)
                    pairPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)
                footer
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == page ? TerminalStyle.accent : TerminalStyle.inkDim.opacity(0.4))
                    .frame(width: i == page ? 22 : 8, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: page)
            }
            Spacer()
            if page < totalPages - 1 {
                Button {
                    onFinish()
                } label: {
                    Text("common.skip")
                        .font(TerminalStyle.mono(12, weight: .semibold))
                        .foregroundStyle(TerminalStyle.inkDim)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("$ buddy --init")
                .font(TerminalStyle.mono(14, weight: .bold))
                .foregroundStyle(TerminalStyle.inkDim)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(TerminalStyle.ink)
                .padding(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(TerminalStyle.inkDim.opacity(0.55), lineWidth: 1)
                )

            VStack(spacing: 10) {
                Text("onboarding.welcome.title")
                    .font(TerminalStyle.mono(22, weight: .bold))
                    .foregroundStyle(TerminalStyle.ink)
                    .multilineTextAlignment(.center)
                Text("onboarding.welcome.body")
                    .font(TerminalStyle.mono(13))
                    .foregroundStyle(TerminalStyle.inkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var renamePage: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("$ system.setDeviceName")
                .font(TerminalStyle.mono(14, weight: .bold))
                .foregroundStyle(TerminalStyle.inkDim)

            Image(systemName: "iphone.badge.checkmark")
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(TerminalStyle.ink)

            VStack(spacing: 8) {
                Text("onboarding.rename.title")
                    .font(TerminalStyle.mono(20, weight: .bold))
                    .foregroundStyle(TerminalStyle.ink)
                    .multilineTextAlignment(.center)
                Text("onboarding.rename.body")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.inkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(TerminalStyle.accent)
                Text("onboarding.rename.hint")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.accentSoft)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TerminalStyle.lcdPanel.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(TerminalStyle.accent.opacity(0.45), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Button {
                if let url = URL(string: "App-prefs:root=General&path=About") {
                    UIApplication.shared.open(url)
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("onboarding.rename.openSettings")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(TerminalHeaderButtonStyle(fill: true))
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var pairPage: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("$ ble --advertise")
                .font(TerminalStyle.mono(14, weight: .bold))
                .foregroundStyle(TerminalStyle.inkDim)

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 60, weight: .regular))
                .foregroundStyle(TerminalStyle.ink)

            VStack(spacing: 8) {
                Text("onboarding.pair.title")
                    .font(TerminalStyle.mono(20, weight: .bold))
                    .foregroundStyle(TerminalStyle.ink)
                    .multilineTextAlignment(.center)
                Text("onboarding.pair.body")
                    .font(TerminalStyle.mono(12))
                    .foregroundStyle(TerminalStyle.inkDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        Button {
            if page < totalPages - 1 {
                withAnimation { page += 1 }
            } else {
                onFinish()
            }
        } label: {
            Text(page < totalPages - 1 ? "common.next" : "onboarding.cta.start")
                .font(TerminalStyle.mono(14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(TerminalStyle.accent, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(TerminalStyle.shellBottom.opacity(0.7), lineWidth: 1)
                )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}
