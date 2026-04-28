// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the DeviceMenuState navigation state machine. Uses the in-memory
 * `InMemoryDeviceMenuPrefs` to stay free of Android framework dependencies.
 * Focus is on menu/settings/reset transitions and apply semantics — the
 * persisted-value delegates are thin read/write pass-throughs and aren't
 * worth exercising here.
 */
class DeviceMenuStateTest {

    private fun newState() = DeviceMenuState(InMemoryDeviceMenuPrefs())

    @Test fun toggleMenuOpensAtIndexZero() {
        val s = newState()
        s.menuIndex = 3
        s.toggleMenu()
        assertTrue(s.menuOpen)
        assertEquals(0, s.menuIndex)
    }

    @Test fun toggleMenuClosesSettingsFirst() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.settingsIndex = 5
        s.toggleMenu()
        assertFalse(s.settingsOpen)
        assertEquals(0, s.settingsIndex)
        assertTrue(s.menuOpen)
    }

    @Test fun toggleMenuClosesResetFirst() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.resetOpen = true
        s.resetIndex = 1
        s.toggleMenu()
        assertFalse(s.resetOpen)
        assertEquals(0, s.resetIndex)
        assertTrue(s.settingsOpen)
    }

    @Test fun advanceCursorWrapsAtMenuEnd() {
        val s = newState()
        s.menuOpen = true
        s.menuIndex = DeviceMenuState.MENU_ITEMS.size - 1
        s.advanceCursor()
        assertEquals(0, s.menuIndex)
    }

    @Test fun advanceCursorTargetsInnermostTree() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.resetOpen = true
        s.advanceCursor()
        assertEquals(1, s.resetIndex)
        assertEquals(0, s.menuIndex)
        assertEquals(0, s.settingsIndex)
    }

    @Test fun applyMenuSettingsEntersSettingsTree() {
        val s = newState()
        s.menuOpen = true
        s.menuIndex = DeviceMenuState.MENU_ITEMS.indexOf("settings")
        val desc = s.applyCurrentSelection(
            cycleAsciiSpecies = {}, onReset = {}, onTurnOff = {},
            onDemo = {}, onHelp = {}, onAbout = {}, onBluetoothChanged = {},
        )
        assertEquals("menu -> settings", desc)
        assertTrue(s.settingsOpen)
        assertEquals(0, s.settingsIndex)
    }

    @Test fun applyMenuTurnOffFiresScreenOff() {
        val s = newState()
        s.menuOpen = true
        s.menuIndex = DeviceMenuState.MENU_ITEMS.indexOf("turn off")
        var turnOffFired = 0
        s.applyCurrentSelection(
            cycleAsciiSpecies = {}, onReset = {}, onTurnOff = { turnOffFired++ },
            onDemo = {}, onHelp = {}, onAbout = {}, onBluetoothChanged = {},
        )
        assertEquals(1, turnOffFired)
        assertTrue(s.screenOff)
        assertFalse(s.menuOpen)
    }

    @Test fun applySettingsBluetoothTogglesAndFiresHook() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.settingsIndex = DeviceMenuState.SETTINGS_ITEMS.indexOf("bluetooth")
        val initial = s.bt
        var lastValue: Boolean? = null
        s.applyCurrentSelection(
            cycleAsciiSpecies = {}, onReset = {}, onTurnOff = {},
            onDemo = {}, onHelp = {}, onAbout = {}, onBluetoothChanged = { lastValue = it },
        )
        assertEquals(!initial, s.bt)
        assertEquals(!initial, lastValue)
    }

    @Test fun applySettingsBrightnessWrapsToZero() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.settingsIndex = DeviceMenuState.SETTINGS_ITEMS.indexOf("brightness")
        s.brightness = 4
        s.applyCurrentSelection(
            cycleAsciiSpecies = {}, onReset = {}, onTurnOff = {},
            onDemo = {}, onHelp = {}, onAbout = {}, onBluetoothChanged = {},
        )
        assertEquals(0, s.brightness)
    }

    @Test fun applySettingsResetOpensConfirmationAtCancel() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.settingsIndex = DeviceMenuState.SETTINGS_ITEMS.indexOf("reset")
        s.applyCurrentSelection(
            cycleAsciiSpecies = {}, onReset = {}, onTurnOff = {},
            onDemo = {}, onHelp = {}, onAbout = {}, onBluetoothChanged = {},
        )
        assertTrue(s.resetOpen)
        assertEquals(1, s.resetIndex) // default "cancel" to avoid footguns
    }

    @Test fun applyResetConfirmFiresAndClosesEverything() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.resetOpen = true
        s.resetIndex = 0 // "confirm"
        var resetFired = 0
        s.applyCurrentSelection(
            cycleAsciiSpecies = {}, onReset = { resetFired++ }, onTurnOff = {},
            onDemo = {}, onHelp = {}, onAbout = {}, onBluetoothChanged = {},
        )
        assertEquals(1, resetFired)
        assertFalse(s.resetOpen)
        assertFalse(s.settingsOpen)
        assertFalse(s.menuOpen)
    }

    @Test fun applyResetCancelKeepsSettingsOpen() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.resetOpen = true
        s.resetIndex = 1 // "cancel"
        s.applyCurrentSelection(
            cycleAsciiSpecies = {}, onReset = {}, onTurnOff = {},
            onDemo = {}, onHelp = {}, onAbout = {}, onBluetoothChanged = {},
        )
        assertFalse(s.resetOpen)
        assertTrue(s.settingsOpen)
        assertTrue(s.menuOpen)
    }

    @Test fun applyNoopWhenNothingOpen() {
        val s = newState()
        assertNull(
            s.applyCurrentSelection(
                cycleAsciiSpecies = {}, onReset = {}, onTurnOff = {},
                onDemo = {}, onHelp = {}, onAbout = {}, onBluetoothChanged = {},
            )
        )
    }

    @Test fun brightnessMultiplierRange() {
        val s = newState()
        s.brightness = 0
        assertEquals(0.3f, s.brightnessMultiplier, 0.0001f)
        s.brightness = 4
        assertEquals(1.0f, s.brightnessMultiplier, 0.0001f)
        s.brightness = 2
        assertEquals(0.65f, s.brightnessMultiplier, 0.0001f)
    }

    @Test fun closeMenusResetsAllNavigation() {
        val s = newState()
        s.menuOpen = true
        s.settingsOpen = true
        s.resetOpen = true
        s.menuIndex = 3
        s.settingsIndex = 4
        s.resetIndex = 1
        s.closeMenus()
        assertFalse(s.menuOpen)
        assertFalse(s.settingsOpen)
        assertFalse(s.resetOpen)
        assertEquals(0, s.menuIndex)
        assertEquals(0, s.settingsIndex)
        assertEquals(0, s.resetIndex)
    }

    @Test fun isAnyMenuVisibleReflectsState() {
        val s = newState()
        assertFalse(s.isAnyMenuVisible)
        s.menuOpen = true
        assertTrue(s.isAnyMenuVisible)
        s.menuOpen = false
        s.settingsOpen = true
        assertTrue(s.isAnyMenuVisible)
        s.settingsOpen = false
        s.resetOpen = true
        assertTrue(s.isAnyMenuVisible)
    }

    // --- Item-list canonical ids (guard the label-resolution when statement) ---

    @Test fun menuItemsMatchExpectedCanonicalOrder() {
        assertEquals(
            listOf("settings", "turn off", "help", "about", "demo", "close"),
            DeviceMenuState.MENU_ITEMS,
        )
    }

    @Test fun settingsItemsMatchExpectedCanonicalOrder() {
        assertEquals(
            listOf(
                "brightness", "sound", "bluetooth", "wifi", "led",
                "transcript", "clock rot", "ascii pet", "reset", "back",
            ),
            DeviceMenuState.SETTINGS_ITEMS,
        )
    }

    @Test fun resetItemsMatchExpectedCanonicalOrder() {
        assertEquals(listOf("confirm", "cancel"), DeviceMenuState.RESET_ITEMS)
    }
}
