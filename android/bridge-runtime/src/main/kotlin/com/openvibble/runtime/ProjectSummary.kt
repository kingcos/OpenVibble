// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.openvibble.runtime

/**
 * Per-project view derived from rolling heartbeat entries. Used by the
 * Android home screen (INFO > CLAUDE) to split multi-session activity into
 * horizontally swipeable chips. Recomputed from `entries` on every update —
 * there is no persistent store.
 */
data class ProjectSummary(
    val name: String,
    val entries: List<ParsedEntry>,
    val isActive: Boolean,
    val hasPendingPrompt: Boolean,
)

object ProjectSummaryBuilder {
    /**
     * HookEvent raw values (from OpenVibble Desktop's HookEvent enum) that
     * mark a project as "no longer working" when they are its most recent
     * entry. String-literal copy so we don't need to depend on HookBridge.
     */
    private val terminalEvents: Set<String> = setOf("Stop", "StopFailure", "SessionEnd")

    fun build(entries: List<String>, hasPrompt: Boolean): List<ProjectSummary> {
        val parsed = entries.mapNotNull(ProjectEntryParser::parse)
        val promptProject = if (hasPrompt) findPromptProject(parsed) else null

        val order = mutableListOf<String>()
        val buckets = mutableMapOf<String, MutableList<ParsedEntry>>()
        for (entry in parsed) {
            val project = entry.project ?: continue
            if (project !in buckets) {
                order.add(project)
                buckets[project] = mutableListOf()
            }
            buckets[project]!!.add(entry)
        }

        val summaries = order.map { name ->
            val bucket = buckets[name].orEmpty()
            val newest = bucket.firstOrNull()
            val isActive = newest != null && newest.event !in terminalEvents
            ProjectSummary(
                name = name,
                entries = bucket,
                isActive = isActive,
                hasPendingPrompt = name == promptProject,
            )
        }

        return sorted(summaries)
    }

    private fun findPromptProject(parsed: List<ParsedEntry>): String? {
        for (entry in parsed) {
            if (entry.event == "PermissionRequest" && entry.project != null) return entry.project
        }
        return null
    }

    private fun sorted(summaries: List<ProjectSummary>): List<ProjectSummary> {
        val indexed = summaries.withIndex().toList()
        return indexed.sortedWith(
            Comparator { a, b ->
                if (a.value.hasPendingPrompt != b.value.hasPendingPrompt)
                    return@Comparator if (a.value.hasPendingPrompt) -1 else 1
                if (a.value.isActive != b.value.isActive)
                    return@Comparator if (a.value.isActive) -1 else 1
                a.index - b.index
            },
        ).map { it.value }
    }
}
