// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import BridgeRuntime
import BuddyPersona

/// INFO > CLAUDE page body. A horizontally-scrollable chip row with `ALL`
/// pinned left + one chip per discovered project, and a detail pane that
/// changes to match the selection. `BridgeAppModel.projects` does all the
/// grouping work — this view is purely presentational.
struct ClaudeSessionsView: View {
    @ObservedObject var model: BridgeAppModel
    @ObservedObject var persona: PersonaController

    @State private var selectedProject: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chipRow
            Divider().background(TerminalStyle.lcdDivider)
            if let name = selectedProject,
               let project = model.projects.first(where: { $0.name == name }) {
                ProjectDetailView(project: project)
            } else {
                allOverview
            }
            Spacer(minLength: 0)
        }
        .onChange(of: model.projects.map(\.name)) { _, names in
            if let current = selectedProject, !names.contains(current) {
                selectedProject = nil
            }
        }
    }

    // MARK: - Chip row

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(
                    title: "ALL",
                    isSelected: selectedProject == nil,
                    trailing: nil,
                    action: { selectedProject = nil }
                )
                ForEach(model.projects, id: \.name) { project in
                    chip(
                        title: project.name,
                        isSelected: selectedProject == project.name,
                        trailing: trailing(for: project),
                        action: { selectedProject = project.name }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func chip(
        title: String,
        isSelected: Bool,
        trailing: AnyView?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(TerminalStyle.mono(12, weight: .bold))
                    .tracking(1)
                if let trailing { trailing }
            }
            .foregroundStyle(isSelected ? TerminalStyle.lcdBg : TerminalStyle.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? TerminalStyle.ink : TerminalStyle.lcdPanel.opacity(0.6),
                in: Capsule()
            )
            .overlay(Capsule().stroke(TerminalStyle.inkDim.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func trailing(for project: ProjectSummary) -> AnyView? {
        if project.hasPendingPrompt {
            AnyView(
                Text("!")
                    .font(TerminalStyle.mono(10, weight: .bold))
                    .foregroundStyle(TerminalStyle.bad)
            )
        } else if project.isActive {
            AnyView(
                Circle()
                    .fill(TerminalStyle.good)
                    .frame(width: 6, height: 6)
            )
        } else {
            nil
        }
    }

    // MARK: - ALL overview (unchanged semantics from the old CLAUDE page)

    private var allOverview: some View {
        VStack(alignment: .leading, spacing: 4) {
            overviewRow("info.claude.sessions", value: "\(model.snapshot.total)")
            overviewRow("info.claude.running", value: "\(model.snapshot.running)")
            overviewRow("info.claude.waiting", value: "\(model.snapshot.waiting)")
            overviewRow("info.claude.state", value: localizedPersonaState(persona.state))
            overviewRow("info.claude.tokPerDay", value: "\(model.snapshot.tokensToday)")
        }
    }

    private func overviewRow(_ labelKey: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(labelKey)
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.inkDim)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.ink)
            Spacer(minLength: 0)
        }
    }

    private func localizedPersonaState(_ state: PersonaState) -> String {
        switch state {
        case .sleep: return String(localized: "state.sleep")
        case .idle: return String(localized: "state.idle")
        case .busy: return String(localized: "state.busy")
        case .attention: return String(localized: "state.attention")
        case .celebrate: return String(localized: "state.celebrate")
        case .dizzy: return String(localized: "state.dizzy")
        case .heart: return String(localized: "state.heart")
        }
    }
}

/// Placeholder — filled in by Phase 4. Shows the bare minimum so the chip
/// selection is demonstrably functional in Phase 3.
private struct ProjectDetailView: View {
    let project: ProjectSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(TerminalStyle.mono(12, weight: .bold))
                .foregroundStyle(TerminalStyle.ink)
            Text("\(project.entries.count) entries")
                .font(TerminalStyle.mono(11))
                .foregroundStyle(TerminalStyle.inkDim)
        }
    }
}
