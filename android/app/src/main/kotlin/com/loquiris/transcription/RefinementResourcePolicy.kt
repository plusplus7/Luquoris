package com.loquiris.transcription

/** Unknown observations fail closed for optional AI work, never for capture. */
data class RefinementResourceSnapshot(
    val thermalStatus: Int?,
    val lowMemory: Boolean?,
    val powerSave: Boolean?,
    val batteryPercent: Int?,
    val charging: Boolean?,
)

object RefinementResourcePolicy {
    /** Separates real memory-pressure hints from the UI-hidden lifecycle hint. */
    fun memoryTrimPauseReason(level: Int): String? =
        if (level in 10 until 20 || level >= 60) "refinement_memory_pressure" else null

    fun pauseReason(snapshot: RefinementResourceSnapshot): String? = with(snapshot) {
        when {
            thermalStatus == null || thermalStatus !in 0..6 || lowMemory == null ||
                powerSave == null || batteryPercent == null || batteryPercent !in 0..100 || charging == null ->
                "refinement_resources_unavailable"
            thermalStatus >= 3 -> "refinement_thermal_severe"
            lowMemory -> "refinement_memory_pressure"
            powerSave -> "refinement_power_save"
            batteryPercent <= 15 && !charging -> "refinement_battery_low"
            else -> null
        }
    }
}
