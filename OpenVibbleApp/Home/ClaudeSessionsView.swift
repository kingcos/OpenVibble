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
                ProjectDetailView(
                    project: project,
                    prompt: project.hasPendingPrompt ? model.prompt : nil
                )
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

    private func trailing(for project: ProjectSummary) -> AnyView? {
        if project.hasPendingPrompt {
            return AnyView(
                Text("!")
                    .font(TerminalStyle.mono(10, weight: .bold))
                    .foregroundStyle(TerminalStyle.bad)
            )
        }
        if project.isActive {
            return AnyView(
                Circle()
                    .fill(TerminalStyle.good)
                    .frame(width: 6, height: 6)
            )
        }
        return nil
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

/// One-project slice: a status line, the pending prompt preview (if this
/// project owns it), and a scrollable list of the recent entries for that
/// project. Entries are already bucketed/ordered newest-first by
/// ProjectSummaryBuilder.
private struct ProjectDetailView: View {
    let project: ProjectSummary
    let prompt: PromptRequest?

    private static let recentCap = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            statusRow
            if let prompt { promptRow(prompt) }
            recentHeader
            recentList
        }
    }

    private var statusRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("info.claude.project.status")
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.inkDim)
                .frame(width: 82, alignment: .leading)
            Text(statusLabel)
                .font(TerminalStyle.mono(12))
                .foregroundStyle(statusColor)
            Spacer(minLength: 0)
        }
    }

    private var statusLabel: LocalizedStringKey {
        if project.hasPendingPrompt { return "info.claude.project.status.waiting" }
        if project.isActive { return "info.claude.project.status.running" }
        return "info.claude.project.status.idle"
    }

    private var statusColor: Color {
        if project.hasPendingPrompt { return TerminalStyle.bad }
        if project.isActive { return TerminalStyle.good }
        return TerminalStyle.inkDim
    }

    private func promptRow(_ prompt: PromptRequest) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("info.claude.project.prompt")
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.inkDim)
                .frame(width: 82, alignment: .leading)
            Text(formatPrompt(prompt))
                .font(TerminalStyle.mono(12))
                .foregroundStyle(TerminalStyle.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private func formatPrompt(_ prompt: PromptRequest) -> String {
        let tool = prompt.tool.trimmingCharacters(in: .whitespaces)
        let hint = prompt.hint.trimmingCharacters(in: .whitespaces)
        if tool.isEmpty && hint.isEmpty { return "—" }
        if hint.isEmpty { return tool }
        if tool.isEmpty { return hint }
        return "\(tool): \(hint)"
    }

    private var recentHeader: some View {
        Text("info.claude.project.recent")
            .font(TerminalStyle.mono(11, weight: .semibold))
            .tracking(1)
            .foregroundStyle(TerminalStyle.accentSoft)
            .padding(.top, 2)
    }

    @ViewBuilder
    private var recentList: some View {
        if project.entries.isEmpty {
            Text("info.claude.project.recent.empty")
                .font(TerminalStyle.mono(11))
                .foregroundStyle(TerminalStyle.inkDim)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(project.entries.prefix(Self.recentCap).enumerated()), id: \.offset) { _, entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: ParsedEntry) -> some View {
        let label = [entry.event, entry.detail]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(entry.time)
                .font(TerminalStyle.mono(11))
                .foregroundStyle(TerminalStyle.inkDim)
            Text(label)
                .font(TerminalStyle.mono(11))
                .foregroundStyle(TerminalStyle.ink.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
