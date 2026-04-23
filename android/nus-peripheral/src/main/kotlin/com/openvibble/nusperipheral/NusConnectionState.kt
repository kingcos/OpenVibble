// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.nusperipheral

sealed class NusConnectionState {
    data object Stopped : NusConnectionState()
    data object Advertising : NusConnectionState()
    data class Connected(val centralCount: Int) : NusConnectionState()

    val isConnected: Boolean get() = this is Connected
    val isAdvertising: Boolean get() = this is Advertising || this is Connected
}

/**
 * Android bluetooth power states observed through
 * BluetoothAdapter.getState() / ACTION_STATE_CHANGED broadcasts. Keeps parity
 * with iOS `bluetoothPowerState` so the UI can branch the same way.
 */
enum class BluetoothPowerState {
    UNKNOWN, OFF, TURNING_ON, ON, TURNING_OFF, UNSUPPORTED
}
