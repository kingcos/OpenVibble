// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.onboarding

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Collects the runtime permissions the Android BLE peripheral needs. Scoping
 * mirrors the manifest declarations in app/src/main/AndroidManifest.xml:
 *   - Android 12+ (API 31): BLUETOOTH_CONNECT, BLUETOOTH_ADVERTISE
 *   - Android 8-11: ACCESS_FINE_LOCATION (some OEMs gate advertising on it)
 *   - Android 13+ (API 33): POST_NOTIFICATIONS
 */
object BluetoothPermissions {

    /** Runtime permissions required before BLE advertising can start. */
    fun required(): Array<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_ADVERTISE,
        )
    } else {
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    /** On Android 13+ POST_NOTIFICATIONS is a runtime prompt. Older versions grant implicitly. */
    fun notification(): String? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.POST_NOTIFICATIONS
        } else {
            null
        }

    fun allGranted(context: Context): Boolean =
        required().all { isGranted(context, it) }

    fun notificationsGranted(context: Context): Boolean {
        val perm = notification() ?: return true
        return isGranted(context, perm)
    }

    fun isGranted(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
}

/**
 * Three-valued status for a permission group. Drives status-row color +
 * button label in OnboardingScreen.
 */
enum class PermissionGroupStatus { NOT_DETERMINED, GRANTED, DENIED }
