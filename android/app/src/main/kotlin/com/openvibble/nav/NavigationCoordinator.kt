// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.nav

import android.net.Uri
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Android parity with iOS `NavigationCoordinator`. Drives deep-link-initiated
 * navigation from outside the view tree (openvibble:// URIs). HomeScreen
 * consumes [pendingRoute] and clears it after applying the change.
 *
 * LiveActivity chrome deep-linking is iOS-only, so only openvibble://status
 * is honored for feature parity with the iOS notification tap path.
 */
class NavigationCoordinator {

    sealed class Route {
        data object Status : Route()
    }

    private val _pendingRoute = MutableStateFlow<Route?>(null)
    val pendingRoute: StateFlow<Route?> = _pendingRoute.asStateFlow()

    fun handle(uri: Uri) {
        if (uri.scheme != SCHEME) return
        when (uri.host) {
            "status" -> _pendingRoute.value = Route.Status
            else -> Unit
        }
    }

    fun clearPending() {
        _pendingRoute.value = null
    }

    companion object {
        const val SCHEME = "openvibble"
    }
}
