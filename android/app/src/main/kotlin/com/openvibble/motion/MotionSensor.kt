// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.motion

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.sqrt

/**
 * Android parity with iOS `MotionSensor`. Listens for device motion via
 * TYPE_GRAVITY + TYPE_LINEAR_ACCELERATION (or TYPE_ACCELEROMETER as a
 * fallback) and surfaces two signals:
 *
 *  - [MotionListener.onShake] once per debounce window when the linear
 *    acceleration magnitude crosses [SHAKE_MAGNITUDE_THRESHOLD_MS2].
 *  - [MotionListener.onFaceDownChanged] when gravity.z crosses below/above
 *    [FACE_DOWN_GRAVITY_THRESHOLD_MS2]. Unit is m/s² (9.81 = 1g).
 *
 * Thresholds mirror iOS's relative scale: shake > 0.8 "g of user accel"
 * (≈ 7.85 m/s²) and face-down when gravity.z < -0.9 g (≈ -8.83 m/s²).
 *
 * Everything is framework-free behind the static [process] function so
 * unit tests can feed synthetic samples without an Android runtime.
 */
class MotionSensor(
    private val sensorManager: SensorManager,
    private val listener: MotionListener,
    private val nowMs: () -> Long = { System.currentTimeMillis() },
) : SensorEventListener {

    interface MotionListener {
        fun onShake()
        fun onFaceDownChanged(faceDown: Boolean)
    }

    private var lastShakeAtMs: Long = Long.MIN_VALUE / 2
    private var lastFaceDown: Boolean = false

    private val gravitySensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val linearAccelSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
    private val accelSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

    /** True when at least one usable sensor is available. */
    val isAvailable: Boolean
        get() = gravitySensor != null || linearAccelSensor != null || accelSensor != null

    fun start() {
        val rate = SensorManager.SENSOR_DELAY_GAME
        gravitySensor?.let { sensorManager.registerListener(this, it, rate) }
        linearAccelSensor?.let { sensorManager.registerListener(this, it, rate) }
        if (gravitySensor == null || linearAccelSensor == null) {
            // Only fall back to raw accelerometer when a dedicated sensor is
            // missing — it's noisier but lets us compute both gravity and
            // linear accel via a cheap low-pass filter.
            accelSensor?.let { sensorManager.registerListener(this, it, rate) }
        }
    }

    fun stop() {
        sensorManager.unregisterListener(this)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) { /* unused */ }

    // -- Low-pass / high-pass split for the accelerometer-only fallback.
    private var gFilterX: Float = 0f
    private var gFilterY: Float = 0f
    private var gFilterZ: Float = 0f

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_GRAVITY -> handleGravity(event.values[0], event.values[1], event.values[2])
            Sensor.TYPE_LINEAR_ACCELERATION -> handleLinearAccel(event.values[0], event.values[1], event.values[2])
            Sensor.TYPE_ACCELEROMETER -> {
                // Simple low-pass to extract gravity, high-pass to extract
                // linear accel. Matches Apple's Core Motion split roughly.
                gFilterX = LPF_ALPHA * gFilterX + (1 - LPF_ALPHA) * event.values[0]
                gFilterY = LPF_ALPHA * gFilterY + (1 - LPF_ALPHA) * event.values[1]
                gFilterZ = LPF_ALPHA * gFilterZ + (1 - LPF_ALPHA) * event.values[2]
                handleGravity(gFilterX, gFilterY, gFilterZ)
                handleLinearAccel(
                    event.values[0] - gFilterX,
                    event.values[1] - gFilterY,
                    event.values[2] - gFilterZ,
                )
            }
        }
    }

    private fun handleGravity(x: Float, y: Float, z: Float) {
        val faceDown = z < FACE_DOWN_GRAVITY_THRESHOLD_MS2
        if (faceDown != lastFaceDown) {
            lastFaceDown = faceDown
            listener.onFaceDownChanged(faceDown)
        }
    }

    private fun handleLinearAccel(x: Float, y: Float, z: Float) {
        val magnitude = sqrt((x * x + y * y + z * z).toDouble()).toFloat()
        if (magnitude > SHAKE_MAGNITUDE_THRESHOLD_MS2) {
            val now = nowMs()
            if (now - lastShakeAtMs > SHAKE_DEBOUNCE_MS) {
                lastShakeAtMs = now
                listener.onShake()
            }
        }
    }

    companion object {
        /** Accelerometer LPF constant. 0.8 gives a ~200ms gravity response at 30Hz. */
        internal const val LPF_ALPHA: Float = 0.8f

        /** Core Motion's threshold is ≈ 0.8 g of user accel. 1g ≈ 9.81 m/s². */
        const val SHAKE_MAGNITUDE_THRESHOLD_MS2: Float = 7.85f

        /** iOS face-down cutoff at gravity.z < -0.9 g. */
        const val FACE_DOWN_GRAVITY_THRESHOLD_MS2: Float = -8.83f

        /** 1 shake/sec cap — matches iOS debounce window. */
        const val SHAKE_DEBOUNCE_MS: Long = 1_000L

        /**
         * Framework-free shake test. Public so unit tests can assert the
         * threshold+debounce behaviour directly from sample vectors without
         * standing up a fake SensorManager.
         */
        fun exceedsShakeThreshold(x: Float, y: Float, z: Float): Boolean {
            val mag = sqrt((x * x + y * y + z * z).toDouble()).toFloat()
            return mag > SHAKE_MAGNITUDE_THRESHOLD_MS2
        }

        fun isFaceDown(gz: Float): Boolean = gz < FACE_DOWN_GRAVITY_THRESHOLD_MS2
    }
}

/**
 * Convenience factory that wires a Context's SensorManager into a fresh
 * [MotionSensor] bound to the given listener. Keeps MainActivity/RootFlow
 * clear of sensor-system-service lookups.
 */
fun createMotionSensor(context: Context, listener: MotionSensor.MotionListener): MotionSensor? {
    val sm = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager ?: return null
    return MotionSensor(sm, listener)
}
