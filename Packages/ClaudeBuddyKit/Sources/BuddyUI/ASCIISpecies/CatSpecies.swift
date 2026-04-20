import Foundation
import BuddyPersona

public struct ASCIIFrame: Sendable, Equatable {
    public let lines: [String]
    public init(_ lines: [String]) { self.lines = lines }
}

public struct ASCIIAnimation: Sendable {
    public let poses: [ASCIIFrame]
    public let sequence: [Int]
    public let ticksPerBeat: Int
    public init(poses: [ASCIIFrame], sequence: [Int], ticksPerBeat: Int) {
        self.poses = poses
        self.sequence = sequence
        self.ticksPerBeat = ticksPerBeat
    }
    public func frame(at tick: Int) -> ASCIIFrame {
        let beat = (tick / ticksPerBeat) % sequence.count
        return poses[sequence[beat]]
    }
}

public enum CatSpecies {
    public static let bodyColorHex: UInt16 = 0xC2A6

    public static func animation(for state: PersonaState) -> ASCIIAnimation {
        switch state {
        case .sleep: return sleep
        case .idle: return idle
        case .busy: return busy
        case .attention: return attention
        case .celebrate: return celebrate
        case .dizzy: return dizzy
        case .heart: return heart
        }
    }

    // MARK: - SLEEP
    private static let sleep = ASCIIAnimation(
        poses: [
            ASCIIFrame(["            ", "            ", "   .-..-.   ", "  ( -.- )   ", "  `------`~ "]), // LOAF
            ASCIIFrame(["            ", "            ", "   .-..-.   ", "  ( -.- )_  ", " `~------'~ "]), // BREATHE
            ASCIIFrame(["            ", "            ", "   .-/\\.    ", "  (  ..  )) ", "  `~~~~~~`  "]), // CURL
            ASCIIFrame(["            ", "            ", "   .-..-.   ", "  ( u.u )   ", " `~------'~ "]), // PURR
            ASCIIFrame(["            ", "            ", "   .-/\\.    ", "  (  ..  )) ", "  `~~~~~~`~ "]), // CURL_TW
            ASCIIFrame(["            ", "            ", "   .-..-.   ", "  ( o.o )   ", "  `------`  "]), // DREAM
        ],
        // P order from cpp: LOAF(0), BREATHE(1), LOAF(0), PURR(3), CURL(4), CURL_TW(5)
        // SEQ indexes into P. So we already map pose indices 0..5 matching LOAF/BREATHE/LOAF/PURR/CURL/CURL_TW
        // But our poses array puts them in order [LOAF, BREATHE, CURL, PURR, CURL_TW, DREAM]
        // Remap SEQ so it points into our poses array directly:
        //   cpp pose 0 (LOAF) -> our idx 0
        //   cpp pose 1 (BREATHE) -> our idx 1
        //   cpp pose 2 (LOAF again) -> our idx 0
        //   cpp pose 3 (PURR) -> our idx 3
        //   cpp pose 4 (CURL) -> our idx 2
        //   cpp pose 5 (CURL_TW) -> our idx 4
        sequence: [
            0,1,0,1,0,1,
            3,3,0,1,
            2,4,2,4,2,4,
            0,0,
            0,1,0,1,
            4,4,2,2
        ],
        ticksPerBeat: 5
    )

    // MARK: - IDLE
    private static let idle = ASCIIAnimation(
        poses: [
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )  ", "  (\")_(\")   "]), // 0 REST
            ASCIIFrame(["            ", "   /\\_/\\    ", "  (o    o ) ", "  (  w   )  ", "  (\")_(\")   "]), // 1 LOOK_L
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( o    o) ", "  (  w   )  ", "  (\")_(\")   "]), // 2 LOOK_R
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( -   - ) ", "  (  w   )  ", "  (\")_(\")   "]), // 3 BLINK
            ASCIIFrame(["            ", "   /\\-/\\    ", "  ( _   _ ) ", "  (  w   )  ", "  (\")_(\")   "]), // 4 SLOW_BL
            ASCIIFrame(["            ", "   <\\_/\\    ", "  ( o   o ) ", "  (  w   )  ", "  (\")_(\")   "]), // 5 EAR_L
            ASCIIFrame(["            ", "   /\\_/>    ", "  ( o   o ) ", "  (  w   )  ", "  (\")_(\")   "]), // 6 EAR_R
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )  ", "  (\")_(\")~  "]), // 7 TAIL_L
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )  ", " ~(\")_(\")   "]), // 8 TAIL_R
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( ^   ^ ) ", "  (  P   )  ", "  (\")_(\")   "]), // 9 GROOM
        ],
        sequence: [
            0,0,0,3,0,1,0,2,0,
            7,8,7,8,7,
            0,5,0,6,0,
            4,4,0,
            9,9,9,0,
            0,3,0,
            8,7,8,7,
            0,0,4,0
        ],
        ticksPerBeat: 5
    )

    // MARK: - BUSY
    private static let busy = ASCIIAnimation(
        poses: [
            ASCIIFrame(["      .     ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )/ ", "  (\")_(\")   "]), // 0 PAW_UP
            ASCIIFrame(["    .       ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )_ ", "  (\")_(\")   "]), // 1 PAW_TAP
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( O   O ) ", "  (  w   )  ", "  (\")_(\")   "]), // 2 STARE
            ASCIIFrame(["    o       ", "   /\\_/\\    ", "  ( o   o ) ", "  ( -w   )  ", "  (\")_(\")   "]), // 3 NUDGE
            ASCIIFrame(["  o         ", "   /\\_/\\    ", "  ( o   o ) ", "  (-w    )  ", "  (\")_(\")   "]), // 4 SHOVE
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( -   - ) ", "  (  w   )  ", "  (\")_(\")   "]), // 5 SMUG
        ],
        sequence: [
            2,2,2, 0,1,0,1, 3,4,3,4, 5,5, 2,2, 0,1,0,1, 5,2
        ],
        ticksPerBeat: 5
    )

    // MARK: - ATTENTION
    private static let attention = ASCIIAnimation(
        poses: [
            ASCIIFrame(["            ", "   /^_^\\    ", "  ( O   O ) ", "  (  v   )  ", "  (\")_(\")   "]), // 0 ALERT
            ASCIIFrame(["            ", "   /^_^\\    ", "  (O    O ) ", "  (  v   )  ", "  (\")_(\")   "]), // 1 SCAN_L
            ASCIIFrame(["            ", "   /^_^\\    ", "  ( O    O) ", "  (  v   )  ", "  (\")_(\")   "]), // 2 SCAN_R
            ASCIIFrame(["            ", "   /^_^\\    ", "  ( ^   ^ ) ", "  (  v   )  ", "  (\")_(\")   "]), // 3 SCAN_U
            ASCIIFrame(["            ", "   /^_^\\    ", " /( O   O )\\", " (   v    ) ", " /(\")_(\")\\  "]), // 4 CROUCH
            ASCIIFrame(["            ", "   /^_^\\    ", "  ( O   O ) ", "  (  >   )  ", "  (\")_(\")   "]), // 5 HISS
        ],
        sequence: [
            0,4,0,1,0,2,0,3, 4,4,0,1,2,0, 5,0
        ],
        ticksPerBeat: 5
    )

    // MARK: - CELEBRATE
    private static let celebrate = ASCIIAnimation(
        poses: [
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( ^   ^ ) ", "  (  W   )  ", " /(\")_(\")\\  "]), // 0 CROUCH
            ASCIIFrame(["  \\^   ^/   ", "    /\\_/\\   ", "  ( ^   ^ ) ", "  (  W   )  ", "  (\")_(\")   "]), // 1 JUMP
            ASCIIFrame(["  \\^   ^/   ", "    /\\_/\\   ", "  ( * * * ) ", "  (  W   )  ", "  (\")_(\")~  "]), // 2 PEAK
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( <   < ) ", "  (  W   ) /", " ~(\")_(\")   "]), // 3 SPIN_L
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( >   > ) ", " \\(  W   )  ", "  (\")_(\")~  "]), // 4 SPIN_R
            ASCIIFrame(["    \\o/     ", "   /\\_/\\    ", "  ( ^   ^ ) ", " /(  W   )\\ ", "  (\")_(\")   "]), // 5 POSE
        ],
        sequence: [ 0,1,2,1,0, 3,4,3,4, 0,1,2,1,0, 5,5 ],
        ticksPerBeat: 3
    )

    // MARK: - DIZZY
    private static let dizzy = ASCIIAnimation(
        poses: [
            ASCIIFrame(["            ", "  /\\_/\\     ", " ( @   @ )  ", " (   ~~  )  ", " (\")_(\")    "]), // 0 TILT_L
            ASCIIFrame(["            ", "    /\\_/\\   ", "  ( @   @ ) ", "  (  ~~  )  ", "    (\")_(\") "]), // 1 TILT_R
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( x   @ ) ", "  (  v   )  ", "  (\")_(\")~  "]), // 2 WOOZY
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( @   x ) ", "  (  v   )  ", " ~(\")_(\")   "]), // 3 WOOZY2
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( @   @ ) ", "  (  -   )  ", " /(\")_(\")\\~ "]), // 4 SPLAT
        ],
        sequence: [ 0,1,0,1, 2,3, 0,1,0,1, 4,4, 2,3 ],
        ticksPerBeat: 4
    )

    // MARK: - HEART
    private static let heart = ASCIIAnimation(
        poses: [
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( ^   ^ ) ", "  (  u   )  ", "  (\")_(\")~  "]), // 0 DREAMY
            ASCIIFrame(["            ", "   /\\_/\\    ", "  (#^   ^#) ", "  (  u   )  ", "  (\")_(\")   "]), // 1 BLUSH
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( <3 <3 ) ", "  (  u   )  ", "  (\")_(\")~  "]), // 2 HEART_E
            ASCIIFrame(["            ", "   /\\-/\\    ", "  ( ~   ~ ) ", "  (  u   )  ", " ~(\")_(\")~  "]), // 3 PURR
            ASCIIFrame(["            ", "   /\\_/\\    ", "  ( ^   - ) ", "  (  u   )  ", "  (\")_(\")   "]), // 4 HEAD_T
        ],
        sequence: [
            0,0,1,0, 2,2,0, 1,0,4, 0,0,3,3, 0,1,0,2, 1,0
        ],
        ticksPerBeat: 5
    )
}
