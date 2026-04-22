// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct PersonaManifest: Codable, Sendable, Equatable {
    public let name: String
    public let mode: Mode
    public let colors: Palette
    public let states: [String: StateFrames]

    public enum Mode: String, Codable, Sendable { case gif, text }

    public struct Palette: Codable, Sendable, Equatable {
        public let body: String?
        public let bg: String?
        public let text: String?
        public let textDim: String?
        public let ink: String?

        public init(body: String? = nil, bg: String? = nil, text: String? = nil, textDim: String? = nil, ink: String? = nil) {
            self.body = body
            self.bg = bg
            self.text = text
            self.textDim = textDim
            self.ink = ink
        }
    }

    public init(name: String, mode: Mode = .gif, colors: Palette = Palette(), states: [String: StateFrames]) {
        self.name = name
        self.mode = mode
        self.colors = colors
        self.states = states
    }

    enum CodingKeys: String, CodingKey { case name, mode, colors, states }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.mode = (try? container.decode(Mode.self, forKey: .mode)) ?? .gif
        self.colors = (try? container.decode(Palette.self, forKey: .colors)) ?? Palette()
        self.states = (try? container.decode([String: StateFrames].self, forKey: .states)) ?? [:]
    }

    public func frames(for slug: String) -> StateFrames? {
        states[slug]
    }
}

public enum StateFrames: Codable, Sendable, Equatable {
    case single(String)
    case variants([String])
    case text(frames: [String], delayMs: Int)

    public var filenames: [String] {
        switch self {
        case .single(let name): return [name]
        case .variants(let names): return names
        case .text: return []
        }
    }

    public init(from decoder: Decoder) throws {
        // Try string
        if let single = try? decoder.singleValueContainer().decode(String.self) {
            self = .single(single); return
        }
        // Try array of strings
        if let array = try? decoder.singleValueContainer().decode([String].self) {
            self = .variants(array); return
        }
        // Try object { frames: [String], delay: Int }
        let obj = try decoder.container(keyedBy: ObjectKeys.self)
        let frames = try obj.decode([String].self, forKey: .frames)
        let delay = (try? obj.decode(Int.self, forKey: .delayMs))
            ?? (try? obj.decode(Int.self, forKey: .delay))
            ?? 200
        self = .text(frames: frames, delayMs: delay)
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .single(let s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case .variants(let arr):
            var c = encoder.singleValueContainer()
            try c.encode(arr)
        case .text(let frames, let delay):
            var c = encoder.container(keyedBy: ObjectKeys.self)
            try c.encode(frames, forKey: .frames)
            try c.encode(delay, forKey: .delayMs)
        }
    }

    private enum ObjectKeys: String, CodingKey {
        case frames
        case delayMs = "delay_ms"
        case delay
    }
}
