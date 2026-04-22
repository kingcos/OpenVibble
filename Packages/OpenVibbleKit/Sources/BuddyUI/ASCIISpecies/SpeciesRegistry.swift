import Foundation
import BuddyPersona

public enum SpeciesRegistry {
    public static func stateData(forIdx idx: Int, state: PersonaState) -> SpeciesStateData? {
        guard idx >= 0, idx < PersonaSpeciesCatalog.count else { return nil }
        let name = PersonaSpeciesCatalog.names[idx]
        guard let base = GeneratedSpecies.all[name]?[state] else { return nil }
        let overlays = SpeciesOverlays.overlays(for: name, state: state)
        guard !overlays.isEmpty else { return base }
        return SpeciesStateData(
            frames: base.frames,
            seq: base.seq,
            colorRGB565: base.colorRGB565,
            overlays: overlays
        )
    }

    public static func animation(forIdx idx: Int, state: PersonaState) -> ASCIIAnimation {
        let data = stateData(forIdx: idx, state: state)
            ?? GeneratedSpecies.all["cat"]?[state]
            ?? GeneratedSpecies.all["cat"]?[.idle]
            ?? SpeciesStateData(frames: [[" "]], seq: [0], colorRGB565: 0xFFFF)
        let poses = data.frames.map { ASCIIFrame($0) }
        let sequence = data.seq.isEmpty ? [0] : data.seq
        return ASCIIAnimation(poses: poses, sequence: sequence, ticksPerBeat: 5)
    }
}
