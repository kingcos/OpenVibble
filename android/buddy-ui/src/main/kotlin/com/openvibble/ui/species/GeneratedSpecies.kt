// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// AUTO-GENERATED port of iOS GeneratedSpeciesFrames.swift. Seeded with the
// default "cat" species — remaining 17 species are ported incrementally and
// the registry falls back to "cat" when an unknown species is requested.
package com.openvibble.ui.species

import com.openvibble.persona.PersonaState

object GeneratedSpecies {
    val all: Map<String, Map<PersonaState, SpeciesStateData>> = mapOf(
        "cat" to cat,
    )

    private val cat: Map<PersonaState, SpeciesStateData> = mapOf(
        PersonaState.SLEEP to SpeciesStateData(
            frames = listOf(
                listOf("            ", "            ", "   .-..-.   ", "  ( -.- )   ", "  `------`~ "),
                listOf("            ", "            ", "   .-..-.   ", "  ( -.- )_  ", " `~------'~ "),
                listOf("            ", "            ", "   .-..-.   ", "  ( -.- )   ", "  `------`~ "),
                listOf("            ", "            ", "   .-..-.   ", "  ( u.u )   ", " `~------'~ "),
                listOf("            ", "            ", "   .-/\\.    ", "  (  ..  )) ", "  `~~~~~~`  "),
                listOf("            ", "            ", "   .-/\\.    ", "  (  ..  )) ", "  `~~~~~~`~ "),
            ),
            seq = listOf(0, 1, 0, 1, 0, 1, 3, 3, 0, 1, 4, 5, 4, 5, 4, 5, 2, 2, 0, 1, 0, 1, 5, 5, 4, 4),
            colorRGB565 = 0xC2A6,
        ),
        PersonaState.IDLE to SpeciesStateData(
            frames = listOf(
                listOf("            ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )  ", "  (\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  (o    o ) ", "  (  w   )  ", "  (\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( o    o) ", "  (  w   )  ", "  (\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( -   - ) ", "  (  w   )  ", "  (\")_(\")   "),
                listOf("            ", "   /\\-/\\    ", "  ( _   _ ) ", "  (  w   )  ", "  (\")_(\")   "),
                listOf("            ", "   <\\_/\\    ", "  ( o   o ) ", "  (  w   )  ", "  (\")_(\")   "),
                listOf("            ", "   /\\_/>    ", "  ( o   o ) ", "  (  w   )  ", "  (\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )  ", "  (\")_(\")~  "),
                listOf("            ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )  ", " ~(\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( ^   ^ ) ", "  (  P   )  ", "  (\")_(\")   "),
            ),
            seq = listOf(0, 0, 0, 3, 0, 1, 0, 2, 0, 7, 8, 7, 8, 7, 0, 5, 0, 6, 0, 4, 4, 0, 9, 9, 9, 0, 0, 3, 0, 8, 7, 8, 7, 0, 0, 4, 0),
            colorRGB565 = 0xC2A6,
        ),
        PersonaState.BUSY to SpeciesStateData(
            frames = listOf(
                listOf("      .     ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )/ ", "  (\")_(\")   "),
                listOf("    .       ", "   /\\_/\\    ", "  ( o   o ) ", "  (  w   )_ ", "  (\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( O   O ) ", "  (  w   )  ", "  (\")_(\")   "),
                listOf("    o       ", "   /\\_/\\    ", "  ( o   o ) ", "  ( -w   )  ", "  (\")_(\")   "),
                listOf("  o         ", "   /\\_/\\    ", "  ( o   o ) ", "  (-w    )  ", "  (\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( -   - ) ", "  (  w   )  ", "  (\")_(\")   "),
            ),
            seq = listOf(2, 2, 2, 0, 1, 0, 1, 3, 4, 3, 4, 5, 5, 2, 2, 0, 1, 0, 1, 5, 2),
            colorRGB565 = 0xC2A6,
        ),
        PersonaState.ATTENTION to SpeciesStateData(
            frames = listOf(
                listOf("            ", "   /^_^\\    ", "  ( O   O ) ", "  (  v   )  ", "  (\")_(\")   "),
                listOf("            ", "   /^_^\\    ", "  (O    O ) ", "  (  v   )  ", "  (\")_(\")   "),
                listOf("            ", "   /^_^\\    ", "  ( O    O) ", "  (  v   )  ", "  (\")_(\")   "),
                listOf("            ", "   /^_^\\    ", "  ( ^   ^ ) ", "  (  v   )  ", "  (\")_(\")   "),
                listOf("            ", "   /^_^\\    ", " /( O   O )\\", " (   v    ) ", " /(\")_(\")\\  "),
                listOf("            ", "   /^_^\\    ", "  ( O   O ) ", "  (  >   )  ", "  (\")_(\")   "),
            ),
            seq = listOf(0, 4, 0, 1, 0, 2, 0, 3, 4, 4, 0, 1, 2, 0, 5, 0),
            colorRGB565 = 0xFFFF,
        ),
        PersonaState.CELEBRATE to SpeciesStateData(
            frames = listOf(
                listOf("            ", "   /\\_/\\    ", "  ( ^   ^ ) ", "  (  W   )  ", " /(\")_(\")\\  "),
                listOf("  \\^   ^/   ", "    /\\_/\\   ", "  ( ^   ^ ) ", "  (  W   )  ", "  (\")_(\")   "),
                listOf("  \\^   ^/   ", "    /\\_/\\   ", "  ( * * * ) ", "  (  W   )  ", "  (\")_(\")~  "),
                listOf("            ", "   /\\_/\\    ", "  ( <   < ) ", "  (  W   ) /", " ~(\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( >   > ) ", " \\(  W   )  ", "  (\")_(\")~  "),
                listOf("    \\o/     ", "   /\\_/\\    ", "  ( ^   ^ ) ", " /(  W   )\\ ", "  (\")_(\")   "),
            ),
            seq = listOf(0, 1, 2, 1, 0, 3, 4, 3, 4, 0, 1, 2, 1, 0, 5, 5),
            colorRGB565 = 0xFFFF,
        ),
        PersonaState.DIZZY to SpeciesStateData(
            frames = listOf(
                listOf("            ", "  /\\_/\\     ", " ( @   @ )  ", " (   ~~  )  ", " (\")_(\")    "),
                listOf("            ", "    /\\_/\\   ", "  ( @   @ ) ", "  (  ~~  )  ", "    (\")_(\") "),
                listOf("            ", "   /\\_/\\    ", "  ( x   @ ) ", "  (  v   )  ", "  (\")_(\")~  "),
                listOf("            ", "   /\\_/\\    ", "  ( @   x ) ", "  (  v   )  ", " ~(\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( @   @ ) ", "  (  -   )  ", " /(\")_(\")\\~ "),
            ),
            seq = listOf(0, 1, 0, 1, 2, 3, 0, 1, 0, 1, 4, 4, 2, 3),
            colorRGB565 = 0xFFFF,
        ),
        PersonaState.HEART to SpeciesStateData(
            frames = listOf(
                listOf("            ", "   /\\_/\\    ", "  ( ^   ^ ) ", "  (  u   )  ", "  (\")_(\")~  "),
                listOf("            ", "   /\\_/\\    ", "  (#^   ^#) ", "  (  u   )  ", "  (\")_(\")   "),
                listOf("            ", "   /\\_/\\    ", "  ( <3 <3 ) ", "  (  u   )  ", "  (\")_(\")~  "),
                listOf("            ", "   /\\-/\\    ", "  ( ~   ~ ) ", "  (  u   )  ", " ~(\")_(\")~  "),
                listOf("            ", "   /\\_/\\    ", "  ( ^   - ) ", "  (  u   )  ", "  (\")_(\")   "),
            ),
            seq = listOf(0, 0, 1, 0, 2, 2, 0, 1, 0, 4, 0, 0, 3, 3, 0, 1, 0, 2, 1, 0),
            colorRGB565 = 0xFFFF,
        ),
    )
}
