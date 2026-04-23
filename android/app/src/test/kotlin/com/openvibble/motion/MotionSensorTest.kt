// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.motion

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Framework-free coverage of [MotionSensor]'s threshold maths. These exercise
 * the same pure helpers that the Android SensorEventListener path delegates
 * to, so we can verify the shake/face-down boundaries without standing up a
 * fake SensorManager.
 */
class MotionSensorTest {

    // --- Shake threshold (≥ 7.85 m/s² magnitude = ~0.8g of user accel) ---

    @Test fun restingAccelDoesNotTriggerShake() {
        // Typical hand-held jitter under 1 m/s² should never register.
        assertFalse(MotionSensor.exceedsShakeThreshold(0.2f, 0.1f, 0.3f))
    }

    @Test fun justBelowThresholdDoesNotTriggerShake() {
        // Magnitude ≈ 7.8 — right under the 7.85 cutoff.
        assertFalse(MotionSensor.exceedsShakeThreshold(7.8f, 0f, 0f))
    }

    @Test fun crossingThresholdOnSingleAxisTriggersShake() {
        // Magnitude ≈ 8.0 — just over the cutoff.
        assertTrue(MotionSensor.exceedsShakeThreshold(8.0f, 0f, 0f))
    }

    @Test fun combinedAxesSumToMagnitudeAboveThreshold() {
        // sqrt(5² + 5² + 5²) ≈ 8.66 → above threshold even though no single
        // axis dominates. Matches a real vigorous shake.
        assertTrue(MotionSensor.exceedsShakeThreshold(5f, 5f, 5f))
    }

    @Test fun negativeAxesStillTriggerShake() {
        // Magnitude is rotation-invariant — sign doesn't matter.
        assertTrue(MotionSensor.exceedsShakeThreshold(-8.0f, 0f, 0f))
    }

    // --- Face-down threshold (gravity.z < -8.83 m/s² = ~-0.9g) ---

    @Test fun faceUpIsNotFaceDown() {
        // Standard face-up orientation: gravity.z ≈ +9.81.
        assertFalse(MotionSensor.isFaceDown(9.81f))
    }

    @Test fun uprightIsNotFaceDown() {
        // Phone held vertically: gravity.z ≈ 0.
        assertFalse(MotionSensor.isFaceDown(0f))
    }

    @Test fun mildlyTiltedFaceDownIsNotFaceDown() {
        // Tilted but not fully inverted — shouldn't count.
        assertFalse(MotionSensor.isFaceDown(-5f))
    }

    @Test fun justBelowFaceDownThresholdIsNotFaceDown() {
        // Right above the cutoff.
        assertFalse(MotionSensor.isFaceDown(-8.8f))
    }

    @Test fun inverterdFlatIsFaceDown() {
        // Fully inverted: gravity.z ≈ -9.81.
        assertTrue(MotionSensor.isFaceDown(-9.81f))
    }

    // --- Static constant sanity (catches accidental threshold regressions) ---

    @Test fun shakeThresholdMatchesDocumentedValue() {
        // 0.8 g at 9.81 m/s²/g = 7.848 — we use 7.85.
        assertTrue(MotionSensor.SHAKE_MAGNITUDE_THRESHOLD_MS2 in 7.8f..7.9f)
    }

    @Test fun faceDownThresholdMatchesDocumentedValue() {
        // -0.9 g at 9.81 m/s²/g = -8.829 — we use -8.83.
        assertTrue(MotionSensor.FACE_DOWN_GRAVITY_THRESHOLD_MS2 in -8.9f..-8.8f)
    }

    @Test fun shakeDebounceIsOneSecond() {
        // iOS parity: 1 shake/sec cap.
        assertTrue(MotionSensor.SHAKE_DEBOUNCE_MS == 1_000L)
    }
}
