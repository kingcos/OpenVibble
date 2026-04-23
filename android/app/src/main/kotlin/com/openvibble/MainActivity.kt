// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import com.openvibble.bridge.BridgeAppModel
import com.openvibble.home.HomeScreen
import com.openvibble.nav.NavigationCoordinator
import com.openvibble.onboarding.OnboardingScreen
import com.openvibble.persona.PersonaController
import com.openvibble.settings.AppSettings
import com.openvibble.settings.SettingsScreen

/**
 * Android app entry. Hosts the Onboarding → Home → Settings navigation flow
 * in Compose state (no NavHost — three destinations, a boolean each).
 *
 * The BridgeAppModel ViewModel is scoped to the activity so configuration
 * changes don't reset the BLE peripheral or runtime snapshot.
 */
class MainActivity : ComponentActivity() {

    private val navigation = NavigationCoordinator()

    private val model: BridgeAppModel by viewModels {
        BridgeAppModel.Factory(applicationContext)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleDeepLink(intent)

        setContent {
            OpenVibbleTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = Color.Black) {
                    RootFlow(model = model, navigation = navigation)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
    }

    private fun handleDeepLink(intent: Intent?) {
        val uri = intent?.data ?: return
        navigation.handle(uri)
    }
}

@Composable
private fun OpenVibbleTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            background = Color.Black,
            surface = Color.Black,
            onBackground = Color.White,
            onSurface = Color.White,
        ),
        content = content,
    )
}

/**
 * Top-level flow: decides between Onboarding and Home based on the
 * persisted `buddy.hasOnboarded` flag, and layers SettingsScreen over Home
 * when the user taps the gear.
 */
@Composable
private fun RootFlow(
    model: BridgeAppModel,
    navigation: NavigationCoordinator,
) {
    val context = LocalContext.current
    val settings = remember { AppSettings(context) }
    val scope = rememberCoroutineScope()
    val persona = remember { PersonaController(scope) }

    LaunchedEffect(Unit) {
        persona.bind(model, model.statsStore)
    }

    var hasOnboarded by remember { mutableStateOf(settings.hasOnboarded) }
    var showSettings by remember { mutableStateOf(false) }

    if (!hasOnboarded) {
        OnboardingScreen(onFinish = {
            settings.hasOnboarded = true
            hasOnboarded = true
        })
        return
    }

    if (showSettings) {
        SettingsScreen(
            model = model,
            settings = settings,
            onDone = { showSettings = false },
            onRequestNotificationPermission = { /* wired with Task #4 */ },
            onShowOnboarding = {
                settings.hasOnboarded = false
                hasOnboarded = false
                showSettings = false
            },
            onPickSpecies = { /* species picker arrives in Phase 4d-4 */ },
        )
        return
    }

    var showLogs by remember { mutableStateOf(false) }

    if (showLogs) {
        com.openvibble.home.HomeLogSheet(
            model = model,
            onDismiss = { showLogs = false },
        )
        return
    }

    HomeScreen(
        model = model,
        persona = persona,
        navigation = navigation,
        settings = settings,
        onOpenSettings = { showSettings = true },
        onOpenLogs = { showLogs = true },
    )
}
