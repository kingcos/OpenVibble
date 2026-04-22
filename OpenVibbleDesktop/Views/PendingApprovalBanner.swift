// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import HookBridge

struct PendingApprovalBanner: View {
    @EnvironmentObject var state: AppState
    @Environment(\.localizationBundle) private var bundle

    var body: some View {
        if let pending = state.pendingApproval {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                    LText("desktop.pending.title").font(.headline)
                    Spacer()
                }
                if let project = pending.projectName {
                    Text(String(format: bundle.l("desktop.pending.project"), project))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let tool = pending.toolName {
                    Text("\(bundle.l("desktop.pending.tool")): \(tool)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let hint = pending.hint {
                    Text(hint)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                HStack {
                    Button(action: { state.approvePending() }) { LText("desktop.btn.approve") }
                        .tint(.green).keyboardShortcut(.return)
                    Button(action: { state.denyPending() }) { LText("desktop.btn.deny") }
                        .tint(.red)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4)))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
