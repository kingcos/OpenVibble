// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble

import android.app.Application

/**
 * Application-scoped bootstrap. Future iterations will wire
 * BridgeAppModel / PersonaController / BuddyPeripheralService
 * startup here (iOS parity: OpenVibbleApp.init()).
 */
class OpenVibbleApplication : Application()
