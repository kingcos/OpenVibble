// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles APPROVE / DENY tapped straight from the notification banner or
 * drawer. Records the decision in [PromptDecisionStore] so the running (or
 * cold-starting) app can drain it on next resume, then cancels the
 * notification so its actions don't linger.
 *
 * Runs briefly on the main thread of the app process — we deliberately
 * avoid touching `BridgeAppModel` here because the viewmodel may not exist
 * when a notification action cold-starts the app.
 */
class PromptActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(BuddyNotificationCenter.EXTRA_PROMPT_ID) ?: return
        if (id.isEmpty()) return

        val decision = when (intent.action) {
            BuddyNotificationCenter.ACTION_APPROVE -> PromptDecision.APPROVE
            BuddyNotificationCenter.ACTION_DENY -> PromptDecision.DENY
            else -> return
        }

        PromptDecisionStore(context).writePendingDecision(id, decision)
        BuddyNotificationCenter.clearPromptNotifications(context, id)
    }
}
