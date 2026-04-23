// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.nusperipheral

import java.util.UUID

/**
 * Nordic UART Service UUIDs. These are a 1:1 match with iOS NUSUUIDs so
 * Claude Desktop's central scanner (which filters on the service UUID plus
 * name prefix "Claude") can discover Android devices identically.
 *
 * Client Characteristic Configuration Descriptor (CCCD) is the standard
 * BLE descriptor every central uses to enable notifications on TX.
 */
object NusUuids {
    const val SERVICE_STRING: String = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
    const val RX_STRING: String = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    const val TX_STRING: String = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    const val CCCD_STRING: String = "00002902-0000-1000-8000-00805f9b34fb"

    val service: UUID = UUID.fromString(SERVICE_STRING)
    val rx: UUID = UUID.fromString(RX_STRING)
    val tx: UUID = UUID.fromString(TX_STRING)
    val cccd: UUID = UUID.fromString(CCCD_STRING)
}
