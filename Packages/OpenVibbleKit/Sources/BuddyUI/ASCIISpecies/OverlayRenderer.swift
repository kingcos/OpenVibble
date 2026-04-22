import Foundation

public enum OverlayRenderer {
    public static func position(for path: OverlayPath, tick: Int) -> (col: Double, row: Double) {
        let t = Double(tick)
        switch path {
        case .fixed(let col, let row):
            return (col, row)
        case .driftUpRight(let speed, let phase, let span):
            let p = (t * speed + phase).truncatingRemainder(dividingBy: span)
            return (col: p, row: -p * 0.5 + span * 0.5)
        case .orbit(let radius, let speed, let phase):
            let angle = t * speed + phase
            return (col: cos(angle) * radius, row: sin(angle) * radius)
        case .bobble(let col, let row, let amp, let speed):
            return (col: col, row: row + sin(t * speed) * amp)
        case .baked(let points):
            guard !points.isEmpty else { return (0, 0) }
            let idx = tick % points.count
            return (col: points[idx].col, row: points[idx].row)
        case .linear(let originCol, let originRow, let dx, let dy, let phase, let span):
            let p = (t + phase).truncatingRemainder(dividingBy: span)
            return (col: originCol + p * dx, row: originRow + p * dy)
        }
    }
}
