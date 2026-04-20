import SwiftUI
import UIKit

struct OnboardingScreen: View {
    let onFinish: () -> Void
    @State private var page: Int = 0
    @AppStorage("buddy.themePreset") private var themePreset = BuddyThemePreset.m5Orange.rawValue
    private let totalPages = 3

    var body: some View {
        ZStack {
            BuddyTheme.backgroundGradient(themePreset).ignoresSafeArea()

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
                    .fill(i == page ? Color.white : Color.white.opacity(0.25))
                    .frame(width: i == page ? 22 : 8, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: page)
            }
            Spacer()
            if page < totalPages - 1 {
                Button {
                    onFinish()
                } label: {
                    Text("common.skip")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            M5DeviceShell {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 70, weight: .bold))
                    .foregroundStyle(BuddyTheme.palette(themePreset).highlight)
            }
            VStack(spacing: 12) {
                Text("onboarding.welcome.title")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("onboarding.welcome.body")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    private var renamePage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "iphone.badge.checkmark")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(BuddyTheme.palette(themePreset).highlight)
                .padding(.bottom, 4)
            VStack(spacing: 10) {
                Text("onboarding.rename.title")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("onboarding.rename.body")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text("onboarding.rename.hint")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.95))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.35), lineWidth: 1))
            .padding(.horizontal, 28)

            Button {
                if let url = URL(string: "App-prefs:root=General&path=About") {
                    UIApplication.shared.open(url)
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("onboarding.rename.openSettings", systemImage: "gear")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.12), in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var pairPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(.green)
                .padding(.bottom, 4)
            VStack(spacing: 10) {
                Text("onboarding.pair.title")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("onboarding.pair.body")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            Spacer()
        }
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
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    BuddyTheme.accentGradient(themePreset),
                    in: Capsule()
                )
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }
}
