package com.loquiris.performance

import android.content.Context
import android.os.BatteryManager
import android.os.Debug
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock

class PerformanceMetricsReader internal constructor(
    private val observedAtMonotonicMs: () -> Long,
    private val processCpuTimeMs: () -> Long,
    private val processPssKilobytes: () -> Long,
    private val thermalStatus: () -> Int,
    private val remainingDeviceEnergyNanowattHours: () -> Long,
    private val isCharging: () -> Boolean,
) {
    constructor(context: Context) : this(
        observedAtMonotonicMs = SystemClock::elapsedRealtime,
        processCpuTimeMs = Process::getElapsedCpuTime,
        processPssKilobytes = {
            val memoryInfo = Debug.MemoryInfo()
            Debug.getMemoryInfo(memoryInfo)
            memoryInfo.totalPss.toLong()
        },
        thermalStatus = {
            context.getSystemService(PowerManager::class.java).currentThermalStatus
        },
        remainingDeviceEnergyNanowattHours = {
            context
                .getSystemService(BatteryManager::class.java)
                .getLongProperty(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER)
        },
        isCharging = {
            context.getSystemService(BatteryManager::class.java).isCharging
        },
    )

    fun readSnapshot(): PerformanceMetricsSnapshot {
        val pssKilobytes = processPssKilobytes()
        require(pssKilobytes >= 0) { "PSS must be non-negative" }
        val energy =
            runCatching(remainingDeviceEnergyNanowattHours)
                .getOrNull()
                ?.takeIf { it >= 0 }
        return PerformanceMetricsSnapshot(
            observedAtMonotonicMs = observedAtMonotonicMs(),
            processCpuTimeMs = processCpuTimeMs(),
            processPssBytes = Math.multiplyExact(pssKilobytes, 1024L),
            thermalState = coarseThermalState(thermalStatus()),
            remainingDeviceEnergyNanowattHours = energy,
            isCharging = isCharging(),
        )
    }

    private fun coarseThermalState(status: Int): String =
        when (status) {
            PowerManager.THERMAL_STATUS_NONE,
            PowerManager.THERMAL_STATUS_LIGHT,
            -> "nominal"
            PowerManager.THERMAL_STATUS_MODERATE -> "warm"
            PowerManager.THERMAL_STATUS_SEVERE -> "hot"
            PowerManager.THERMAL_STATUS_CRITICAL,
            PowerManager.THERMAL_STATUS_EMERGENCY,
            PowerManager.THERMAL_STATUS_SHUTDOWN,
            -> "critical"
            else -> "unknown"
        }
}
