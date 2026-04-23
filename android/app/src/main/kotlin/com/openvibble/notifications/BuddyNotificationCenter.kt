// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/**
 * Android parity with iOS `BuddyNotificationCenter`. Owns an actionable
 * "prompt" notification channel + a plain channel for level-ups.
 *
 * Quick-action taps from the banner/drawer route into the app through
 * [PromptActionReceiver] → [PromptDecisionStore], the same durable hand-off
 * the iOS Live Activity uses. `MainActivity` drains the record on next
 * resume and calls `BridgeAppModel.respondPermission`.
 */
object BuddyNotificationCenter {

    const val CHANNEL_PROMPT: String = "buddy.prompt"
    const val CHANNEL_LEVEL: String = "buddy.level"

    const val ACTION_APPROVE: String = "com.openvibble.notifications.ACTION_APPROVE"
    const val ACTION_DENY: String = "com.openvibble.notifications.ACTION_DENY"
    const val EXTRA_PROMPT_ID: String = "promptId"

    // Dedup — mirrors iOS `lastPromptNotificationID` / `lastLevelNotified`.
    private var lastPromptNotificationId: String? = null
    private var lastLevelNotified: Int = 0

    /** Create notification channels. Safe to call more than once. */
    fun configure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        val prompt = NotificationChannel(
            CHANNEL_PROMPT,
            "权限请求",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Claude Desktop 发来的权限请求，支持直接在通知上允许或拒绝。"
            enableVibration(true)
        }
        val level = NotificationChannel(
            CHANNEL_LEVEL,
            "升级通知",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "桌宠升级时的提醒。"
        }

        nm.createNotificationChannel(prompt)
        nm.createNotificationChannel(level)
    }

    fun notifyPromptIfNeeded(
        context: Context,
        promptId: String,
        tool: String,
        enabled: Boolean,
    ) {
        if (!enabled || promptId.isEmpty()) return
        if (promptId == lastPromptNotificationId) return
        if (!postNotificationsGranted(context)) return
        lastPromptNotificationId = promptId

        val approveIntent = buildActionPendingIntent(context, ACTION_APPROVE, promptId, requestOffset = 0)
        val denyIntent = buildActionPendingIntent(context, ACTION_DENY, promptId, requestOffset = 1)

        val notification = NotificationCompat.Builder(context, CHANNEL_PROMPT)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("Claude 需要权限")
            .setContentText("工具：$tool")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Claude Desktop 请求使用工具「$tool」"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setAutoCancel(true)
            .addAction(NotificationCompat.Action.Builder(0, "允许", approveIntent).build())
            .addAction(NotificationCompat.Action.Builder(0, "拒绝", denyIntent).build())
            .build()

        runCatching {
            NotificationManagerCompat.from(context).notify(notificationId(promptId), notification)
        }
    }

    fun notifyLevelUpIfNeeded(
        context: Context,
        level: Int,
        enabled: Boolean,
    ) {
        if (!enabled) return
        if (level <= lastLevelNotified) return
        if (!postNotificationsGranted(context)) return
        lastLevelNotified = level

        val notification = NotificationCompat.Builder(context, CHANNEL_LEVEL)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle("升级！")
            .setContentText("桌宠升到了 LV $level")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        runCatching {
            NotificationManagerCompat.from(context).notify(LEVEL_ID_BASE + level, notification)
        }
    }

    /** Drops the delivered prompt notification for a given id. */
    fun clearPromptNotifications(context: Context, promptId: String) {
        if (promptId.isEmpty()) return
        runCatching {
            NotificationManagerCompat.from(context).cancel(notificationId(promptId))
        }
    }

    /** Stable per-prompt notification id. Hash collisions just replace the
     *  older notification — acceptable, since the system would cap drawer
     *  depth anyway. */
    private fun notificationId(promptId: String): Int =
        (promptId.hashCode() and 0x3FFFFFFF) or PROMPT_ID_BASE

    private fun buildActionPendingIntent(
        context: Context,
        action: String,
        promptId: String,
        requestOffset: Int,
    ): PendingIntent {
        val intent = Intent(context, PromptActionReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_PROMPT_ID, promptId)
            setPackage(context.packageName)
        }
        return PendingIntent.getBroadcast(
            context,
            notificationId(promptId) + requestOffset,
            intent,
            pendingIntentMutabilityFlag(),
        )
    }

    private fun postNotificationsGranted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun pendingIntentMutabilityFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

    private const val PROMPT_ID_BASE: Int = 0x40000000
    private const val LEVEL_ID_BASE: Int = 0x20000000
}
