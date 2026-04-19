import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("CLAUDE BUDDY BRIDGE")
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.green)
                Text("Bootstrapping iOS terminal UI...")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
    }
}
