import SwiftUI
import BuddyPersona

public struct ASCIIBuddyView: View {
    public let state: PersonaState
    public let startDate: Date
    public let speciesIdx: Int?

    public init(state: PersonaState, startDate: Date = .now, speciesIdx: Int? = nil) {
        self.state = state
        self.startDate = startDate
        self.speciesIdx = speciesIdx
    }

    public var body: some View {
        // Use a fixed reference point (equivalent to the h5 demo's
        // `performance.now()`) so `tick` is strictly monotonic across view
        // reconstructions. If we derived it from an instance-level `startDate`
        // default-initialized to `.now`, every re-render of the parent (driven
        // by PersonaController's 0.2s publish tick) would reset the tick to 0
        // and freeze the animation on `sequence[0]`.
        TimelineView(.periodic(from: startDate, by: 0.2)) { ctx in
            let tick = Int(ctx.date.timeIntervalSinceReferenceDate * 5)
            let animation = resolveAnimation()
            let frame = animation.frame(at: tick)
            renderFrame(frame, state: state, tick: tick)
        }
    }

    private func resolveAnimation() -> ASCIIAnimation {
        if let idx = speciesIdx {
            return SpeciesRegistry.animation(forIdx: idx, state: state)
        }
        return CatSpecies.animation(for: state)
    }

    @ViewBuilder
    private func renderFrame(_ frame: ASCIIFrame, state: PersonaState, tick: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(frame.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Self.bodyColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .accessibilityLabel("OpenVibble pet, state: \(state.slug)")
    }

    // 0xC2A6 RGB565 ≈ RGB(197, 85, 49). Convert to sRGB.
    private static let bodyColor = Color(
        red: 197.0 / 255.0,
        green: 85.0 / 255.0,
        blue: 49.0 / 255.0
    )
}

#Preview("Cat states") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(PersonaState.allCases, id: \.rawValue) { state in
                VStack(alignment: .leading) {
                    Text(state.slug).font(.caption).foregroundStyle(.secondary)
                    ASCIIBuddyView(state: state)
                }
                .padding()
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}
