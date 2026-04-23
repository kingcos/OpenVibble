// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.notifications

import android.content.Context
import com.openvibble.bridge.BridgeAppModel

/**
 * Thin adapter from [BridgeAppModel.NotificationsBridge] to the static
 * [BuddyNotificationCenter]. Keeps the bridge model free of Android imports.
 */
class BuddyNotificationsBridge(context: Context) : BridgeAppModel.NotificationsBridge {
    private val appContext: Context = context.applicationContext

    override fun notifyPromptIfNeeded(promptId: String, tool: String, enabled: Boolean) {
        BuddyNotificationCenter.notifyPromptIfNeeded(appContext, promptId, tool, enabled)
    }

    override fun notifyLevelUpIfNeeded(level: Int, enabled: Boolean) {
        BuddyNotificationCenter.notifyLevelUpIfNeeded(appContext, level, enabled)
    }

    override fun clearPromptNotifications(promptId: String) {
        BuddyNotificationCenter.clearPromptNotifications(appContext, promptId)
    }
}
