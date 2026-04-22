// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import BuddyPersona

public struct ASCIIBuddyView: View {
    public let state: PersonaState
    public let startDate: Date
    public let speciesIdx: Int?

    private static let monoFont = Font.system(size: 22, weight: .bold, design: .monospaced)
    private static let charAdvance: CGFloat = 13.2   // measured for size 22 monospaced bold
    private static let lineHeight:  CGFloat = 26.0

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
        return SpeciesRegistry.animation(forIdx: speciesIdx ?? 4, state: state)
    }

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

    @ViewBuilder
    private func overlayLayer(overlays: [Overlay], tick: Int) -> some View {
        ForEach(Array(overlays.enumerated()), id: \.offset) { _, overlay in
            if isVisible(overlay.visibility, tick: tick) {
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
    }

    private func isVisible(_ vis: OverlayVisibility, tick: Int) -> Bool {
        switch vis {
        case .always: return true
        case .tickMod(let period, let active):
            return active.contains(tick % period)
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

    private func speciesColor() -> Color {
        let raw = SpeciesRegistry.stateData(forIdx: speciesIdx ?? 4, state: state)?.colorRGB565
            ?? 0xC2A6
        return Color(rgb565: raw)
    }
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
