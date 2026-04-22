// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import BuddyPersona

public struct GIFView: View {
    public let persona: InstalledPersona
    public let state: PersonaState

    @StateObject private var player = GIFPlayer()

    public init(persona: InstalledPersona, state: PersonaState) {
        self.persona = persona
        self.state = state
    }

    public var body: some View {
        Group {
            if let image = player.currentImage {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .overlay(ProgressView())
            }
        }
        .onAppear { reload() }
        .onDisappear { player.stop() }
        .onChange(of: state) { _, _ in reload() }
        .onChange(of: persona.id) { _, _ in reload() }
    }

    private func reload() {
        let urls = urlsForState()
        player.load(urls: urls)
        player.start()
    }

    private func urlsForState() -> [URL] {
        // Try exact slug first; fall back to idle; then any state.
        if let frames = persona.manifest.frames(for: state.slug), !frames.filenames.isEmpty {
            return persona.fileURL(for: state.slug)
        }
        if let frames = persona.manifest.frames(for: PersonaState.idle.slug), !frames.filenames.isEmpty {
            return persona.fileURL(for: PersonaState.idle.slug)
        }
        if let firstSlug = persona.manifest.states.keys.sorted().first {
            return persona.fileURL(for: firstSlug)
        }
        return []
    }
}
