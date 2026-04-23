// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.nusperipheral

import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins the Nordic UART UUIDs so any accidental drift from the iOS / firmware values is caught here. */
class NusUuidsTest {

    @Test fun serviceUuidMatchesIOS() {
        assertEquals("6e400001-b5a3-f393-e0a9-e50e24dcca9e", NusUuids.SERVICE_STRING)
        assertEquals(NusUuids.SERVICE_STRING, NusUuids.service.toString())
    }

    @Test fun rxUuidMatchesIOS() {
        assertEquals("6e400002-b5a3-f393-e0a9-e50e24dcca9e", NusUuids.RX_STRING)
    }

    @Test fun txUuidMatchesIOS() {
        assertEquals("6e400003-b5a3-f393-e0a9-e50e24dcca9e", NusUuids.TX_STRING)
    }

    @Test fun cccdIsStandardBluetoothSigDescriptor() {
        assertEquals("00002902-0000-1000-8000-00805f9b34fb", NusUuids.CCCD_STRING)
    }
}
