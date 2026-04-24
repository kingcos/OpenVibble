// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import com.openvibble.bridge.BridgeAppModel
import com.openvibble.home.HomeScreen
import com.openvibble.motion.MotionSensor
import com.openvibble.motion.createMotionSensor
import com.openvibble.nav.NavigationCoordinator
import com.openvibble.notifications.BuddyNotificationCenter
import com.openvibble.notifications.BuddyNotificationsBridge
import com.openvibble.notifications.PromptDecision
import com.openvibble.notifications.PromptDecisionStore
import com.openvibble.onboarding.OnboardingScreen
import com.openvibble.persona.PersonaController
import com.openvibble.protocol.PermissionDecision
import com.openvibble.settings.AppSettings
import com.openvibble.settings.SettingsScreen
import com.openvibble.ui.terminal.TerminalPalette

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

    private val decisionStore by lazy { PromptDecisionStore(applicationContext) }

    private val requestNotificationPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* no-op */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleDeepLink(intent)

        BuddyNotificationCenter.configure(applicationContext)
        model.notifications = BuddyNotificationsBridge(applicationContext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestNotificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        setContent {
            OpenVibbleTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = TerminalPalette.lcdBg) {
                    RootFlow(
                        model = model,
                        navigation = navigation,
                        onRequestNotificationPermission = ::askForNotificationPermission,
                    )
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        drainPendingPromptDecision()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
        drainPendingPromptDecision()
    }

    private fun handleDeepLink(intent: Intent?) {
        val uri = intent?.data ?: return
        navigation.handle(uri)
    }

    /**
     * Consumes one pending notification-action decision and forwards it into
     * [BridgeAppModel.respondPermission]. Runs on every resume — cheap no-op
     * when nothing's queued.
     */
    private fun drainPendingPromptDecision() {
        val pending = decisionStore.drainPending() ?: return
        val bridgeDecision = when (pending.decision) {
            PromptDecision.APPROVE -> PermissionDecision.ONCE
            PromptDecision.DENY -> PermissionDecision.DENY
        }
        model.respondPermission(bridgeDecision)
    }

    private fun askForNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestNotificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}

@Composable
private fun OpenVibbleTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            background = TerminalPalette.lcdBg,
            surface = TerminalPalette.lcdPanel,
            onBackground = TerminalPalette.ink,
            onSurface = TerminalPalette.ink,
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
    onRequestNotificationPermission: () -> Unit,
) {
    val context = LocalContext.current
    val settings = remember { AppSettings(context) }
    var terminalTheme by remember { mutableStateOf(settings.terminalTheme) }
    val scope = rememberCoroutineScope()
    val persona = remember { PersonaController(scope) }

    TerminalPalette.mode = terminalTheme

    LaunchedEffect(Unit) {
        persona.bind(model, model.statsStore)
    }

    DisposableEffect(persona) {
        val listener = object : MotionSensor.MotionListener {
            override fun onShake() { persona.notifyShake() }
            override fun onFaceDownChanged(faceDown: Boolean) { persona.setFaceDown(faceDown) }
        }
        val sensor = createMotionSensor(context, listener)?.also { it.start() }
        onDispose { sensor?.stop() }
    }

    var hasOnboarded by remember { mutableStateOf(settings.hasOnboarded) }
    var showSettings by remember { mutableStateOf(false) }
    var showSpeciesPicker by remember { mutableStateOf(false) }
    val personaStore = remember { com.openvibble.settings.SharedPreferencesPersonaSelectionStore(context) }

    if (!hasOnboarded) {
        OnboardingScreen(onFinish = {
            settings.hasOnboarded = true
            hasOnboarded = true
            onRequestNotificationPermission()
        })
        return
    }

    if (showSpeciesPicker) {
        val builtin = remember(model) {
            com.openvibble.persona.PersonaCatalog(model.builtinCharactersRoot).listInstalled()
        }
        val installed = remember(model) {
            com.openvibble.persona.PersonaCatalog(model.charactersRoot).listInstalled()
        }
        com.openvibble.home.SpeciesPickerSheet(
            selection = personaStore.load(),
            store = personaStore,
            builtin = builtin,
            installed = installed,
            onSelect = { /* persisted by the sheet itself */ },
            onClose = { showSpeciesPicker = false },
        )
        return
    }

    if (showSettings) {
        SettingsScreen(
            model = model,
            settings = settings,
            terminalTheme = terminalTheme,
            onTerminalThemeChange = { theme ->
                settings.terminalTheme = theme
                terminalTheme = theme
            },
            onDone = { showSettings = false },
            onRequestNotificationPermission = onRequestNotificationPermission,
            onShowOnboarding = {
                settings.hasOnboarded = false
                hasOnboarded = false
                showSettings = false
            },
            onPickSpecies = {
                showSettings = false
                showSpeciesPicker = true
            },
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
