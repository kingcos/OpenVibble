// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.openvibble.R
import com.openvibble.persona.PersonaSpeciesCatalog
import com.openvibble.persona.PersonaSpeciesId
import com.openvibble.settings.SharedPreferencesPersonaSelectionStore
import kotlin.reflect.KProperty

/**
 * Minimal key/value surface the menu state needs — lets unit tests swap in
 * an in-memory fake without implementing the full SharedPreferences API.
 */
interface DeviceMenuPrefs {
    fun getInt(key: String, default: Int): Int
    fun putInt(key: String, value: Int)
    fun getBoolean(key: String, default: Boolean): Boolean
    fun putBoolean(key: String, value: Boolean)
}

class SharedPreferencesDeviceMenuPrefs(private val prefs: SharedPreferences) : DeviceMenuPrefs {
    override fun getInt(key: String, default: Int): Int = prefs.getInt(key, default)
    override fun putInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }
    override fun getBoolean(key: String, default: Boolean): Boolean = prefs.getBoolean(key, default)
    override fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }
}

class InMemoryDeviceMenuPrefs : DeviceMenuPrefs {
    private val ints = mutableMapOf<String, Int>()
    private val bools = mutableMapOf<String, Boolean>()
    override fun getInt(key: String, default: Int): Int = ints[key] ?: default
    override fun putInt(key: String, value: Int) { ints[key] = value }
    override fun getBoolean(key: String, default: Boolean): Boolean = bools[key] ?: default
    override fun putBoolean(key: String, value: Boolean) { bools[key] = value }
}

/**
 * Android parity with iOS `DeviceMenuState`. Holds the firmware-mimicking
 * in-device menu tree (MENU → SETTINGS → RESET) plus the persisted local
 * settings (brightness / sound / bt / wifi / led / hud / clockRot).
 *
 * Navigation state lives in Compose `mutableStateOf` so the overlay
 * recomposes automatically. Persisted values write through to
 * SharedPreferences under the same keys iOS uses in @AppStorage.
 */
class DeviceMenuState(private val prefs: DeviceMenuPrefs) {

    constructor(context: Context) : this(
        SharedPreferencesDeviceMenuPrefs(
            context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE),
        ),
    )

    // Navigation.
    var menuOpen: Boolean by mutableStateOf(false)
    var settingsOpen: Boolean by mutableStateOf(false)
    var resetOpen: Boolean by mutableStateOf(false)
    var screenOff: Boolean by mutableStateOf(false)

    var menuIndex: Int by mutableIntStateOf(0)
    var settingsIndex: Int by mutableIntStateOf(0)
    var resetIndex: Int by mutableIntStateOf(0)

    // Persisted settings (keys parity with iOS @AppStorage).
    var brightness: Int by prefInt(KEY_BRIGHTNESS, defaultValue = 4)
    var sound: Boolean by prefBool(KEY_SOUND, defaultValue = true)
    var bt: Boolean by prefBool(KEY_BT, defaultValue = true)
    var wifi: Boolean by prefBool(KEY_WIFI, defaultValue = false)
    var led: Boolean by prefBool(KEY_LED, defaultValue = true)
    var hud: Boolean by prefBool(KEY_HUD, defaultValue = true)
    var clockRot: Int by prefInt(KEY_CLOCK_ROT, defaultValue = 0)

    val isAnyMenuVisible: Boolean
        get() = menuOpen || settingsOpen || resetOpen

    /** 0.3 ... 1.0 */
    val brightnessMultiplier: Float
        get() {
            val t = brightness.coerceIn(0, 4).toFloat() / 4f
            return 0.3f + t * 0.7f
        }

    fun toggleMenu() {
        if (resetOpen) { resetOpen = false; resetIndex = 0; return }
        if (settingsOpen) { settingsOpen = false; settingsIndex = 0; return }
        menuOpen = !menuOpen
        if (menuOpen) menuIndex = 0
    }

    fun toggleScreen() { screenOff = !screenOff }

    fun wakeScreen() { screenOff = false }

    fun closeMenus() {
        menuOpen = false
        settingsOpen = false
        resetOpen = false
        menuIndex = 0
        settingsIndex = 0
        resetIndex = 0
    }

    fun advanceCursor() {
        when {
            resetOpen -> resetIndex = (resetIndex + 1) % RESET_ITEMS.size
            settingsOpen -> settingsIndex = (settingsIndex + 1) % SETTINGS_ITEMS.size
            menuOpen -> menuIndex = (menuIndex + 1) % MENU_ITEMS.size
        }
    }

    /**
     * Apply the currently-highlighted item. Hooks that need app-level
     * concerns (persona cycling, bluetooth toggle, reset) are passed in so
     * the state holder stays side-effect-free against external systems.
     *
     * Returns a short log line like `"menu → settings"` for event logging,
     * or null when nothing was done.
     */
    fun applyCurrentSelection(
        cycleAsciiSpecies: () -> Unit,
        onReset: () -> Unit,
        onTurnOff: () -> Unit,
        onDemo: () -> Unit,
        onHelp: () -> Unit,
        onAbout: () -> Unit,
        onBluetoothChanged: (Boolean) -> Unit,
    ): String? = when {
        resetOpen -> applyReset(onReset)
        settingsOpen -> applySettings(cycleAsciiSpecies, onBluetoothChanged)
        menuOpen -> applyMenu(onTurnOff, onDemo, onHelp, onAbout)
        else -> null
    }

    private fun applyMenu(
        onTurnOff: () -> Unit,
        onDemo: () -> Unit,
        onHelp: () -> Unit,
        onAbout: () -> Unit,
    ): String {
        val item = MENU_ITEMS[menuIndex]
        when (item) {
            "settings" -> { settingsOpen = true; settingsIndex = 0 }
            "turn off" -> { onTurnOff(); screenOff = true; menuOpen = false }
            "close" -> menuOpen = false
            "demo" -> onDemo()
            "help" -> onHelp()
            "about" -> onAbout()
        }
        return "menu -> $item"
    }

    private fun applySettings(
        cycleAsciiSpecies: () -> Unit,
        onBluetoothChanged: (Boolean) -> Unit,
    ): String {
        val item = SETTINGS_ITEMS[settingsIndex]
        when (item) {
            "brightness" -> brightness = (brightness + 1) % 5
            "sound" -> sound = !sound
            "bluetooth" -> { bt = !bt; onBluetoothChanged(bt) }
            "wifi" -> wifi = !wifi
            "led" -> led = !led
            "transcript" -> hud = !hud
            "clock rot" -> clockRot = (clockRot + 1) % 3
            "ascii pet" -> cycleAsciiSpecies()
            "reset" -> { resetOpen = true; resetIndex = 1 /* default cancel */ }
            "back" -> { settingsOpen = false; settingsIndex = 0 }
        }
        return "settings -> $item"
    }

    private fun applyReset(onReset: () -> Unit): String {
        val item = RESET_ITEMS[resetIndex]
        when (item) {
            "confirm" -> { onReset(); resetOpen = false; settingsOpen = false; menuOpen = false }
            "cancel" -> resetOpen = false
        }
        return "reset -> $item"
    }

    // -- SharedPreferences-backed property delegates --

    private fun prefInt(key: String, defaultValue: Int) = object {
        private val state: MutableState<Int> = mutableIntStateOf(prefs.getInt(key, defaultValue))
        operator fun getValue(thisRef: Any?, property: KProperty<*>): Int = state.value
        operator fun setValue(thisRef: Any?, property: KProperty<*>, value: Int) {
            state.value = value
            prefs.putInt(key, value)
        }
    }

    private fun prefBool(key: String, defaultValue: Boolean) = object {
        private val state: MutableState<Boolean> = mutableStateOf(prefs.getBoolean(key, defaultValue))
        operator fun getValue(thisRef: Any?, property: KProperty<*>): Boolean = state.value
        operator fun setValue(thisRef: Any?, property: KProperty<*>, value: Boolean) {
            state.value = value
            prefs.putBoolean(key, value)
        }
    }

    companion object {
        const val PREFS_NAME: String = "openvibble.device.menu"

        private const val KEY_BRIGHTNESS = "device.menu.brightness"
        private const val KEY_SOUND = "device.menu.sound"
        private const val KEY_BT = "device.menu.bt"
        private const val KEY_WIFI = "device.menu.wifi"
        private const val KEY_LED = "device.menu.led"
        private const val KEY_HUD = "device.menu.hud"
        private const val KEY_CLOCK_ROT = "device.menu.clockRot"

        val MENU_ITEMS: List<String> = listOf(
            "settings", "turn off", "help", "about", "demo", "close",
        )

        val SETTINGS_ITEMS: List<String> = listOf(
            "brightness", "sound", "bluetooth", "wifi", "led",
            "transcript", "clock rot", "ascii pet", "reset", "back",
        )

        val RESET_ITEMS: List<String> = listOf("confirm", "cancel")

        /**
         * Resolves a MENU item id (the internal English keys in [MENU_ITEMS])
         * to its localized display label. iOS parity: each id maps to a
         * `device.menu.item.*` entry in Localizable.xcstrings; here we route
         * through Android resources so the English source strings surface on
         * en-locale devices.
         */
        fun menuItemLabel(context: Context, id: String): String {
            val resId = when (id) {
                "settings" -> R.string.device_menu_item_settings
                "turn off" -> R.string.device_menu_item_turn_off
                "help" -> R.string.device_menu_item_help
                "about" -> R.string.device_menu_item_about
                "demo" -> R.string.device_menu_item_demo
                "close" -> R.string.device_menu_item_close
                else -> return id
            }
            return context.getString(resId)
        }

        fun settingsItemLabel(context: Context, id: String): String {
            val resId = when (id) {
                "brightness" -> R.string.device_menu_item_brightness
                "sound" -> R.string.device_menu_item_sound
                "bluetooth" -> R.string.device_menu_item_bluetooth
                "wifi" -> R.string.device_menu_item_wifi
                "led" -> R.string.device_menu_item_led
                "transcript" -> R.string.device_menu_item_transcript
                "clock rot" -> R.string.device_menu_item_clock_rot
                "ascii pet" -> R.string.device_menu_item_ascii_pet
                "reset" -> R.string.device_menu_item_reset
                "back" -> R.string.device_menu_item_back
                else -> return id
            }
            return context.getString(resId)
        }

        fun resetItemLabel(context: Context, id: String): String = context.getString(
            if (id == "confirm") R.string.device_menu_item_confirm
            else R.string.device_menu_item_cancel,
        )
    }
}

/**
 * Cycles the local persona selection to the next ASCII species idx in
 * firmware order. Keeps the selection on the ASCII track; a builtin/installed
 * pick enters the ASCII track at idx 4 (cat).
 */
object AsciiPetCycler {
    fun next(context: Context) {
        val store = SharedPreferencesPersonaSelectionStore(context)
        val current = store.load()
        val nextIdx = when (current) {
            is PersonaSpeciesId.AsciiSpecies -> (current.idx + 1) % PersonaSpeciesCatalog.count
            is PersonaSpeciesId.AsciiCat -> 5
            is PersonaSpeciesId.Builtin, is PersonaSpeciesId.Installed -> 4
        }
        store.save(PersonaSpeciesId.AsciiSpecies(nextIdx))
    }

    fun next(store: com.openvibble.persona.PersonaSelectionStore) {
        val current = store.load()
        val nextIdx = when (current) {
            is PersonaSpeciesId.AsciiSpecies -> (current.idx + 1) % PersonaSpeciesCatalog.count
            is PersonaSpeciesId.AsciiCat -> 5
            is PersonaSpeciesId.Builtin, is PersonaSpeciesId.Installed -> 4
        }
        store.save(PersonaSpeciesId.AsciiSpecies(nextIdx))
    }
}
