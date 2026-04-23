// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.ui.species

data class SpeciesStateData(
    val frames: List<List<String>>,
    val seq: List<Int>,
    val colorRGB565: Int,
    val overlays: List<Overlay> = emptyList(),
)

data class AsciiFrame(val lines: List<String>)

data class AsciiAnimation(
    val poses: List<AsciiFrame>,
    val sequence: List<Int>,
    val ticksPerBeat: Int,
) {
    fun frameAt(tick: Int): AsciiFrame {
        val beatIndex = (tick / ticksPerBeat).mod(sequence.size)
        val poseIndex = sequence[beatIndex]
        return poses[poseIndex]
    }
}
