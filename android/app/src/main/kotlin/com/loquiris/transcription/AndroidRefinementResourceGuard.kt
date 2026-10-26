package com.loquiris.transcription

import android.app.ActivityManager
import android.content.BroadcastReceiver
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.os.BatteryManager
import android.os.PowerManager
import android.os.SystemClock

/** Scoped Android observations; no database, model or audio work runs in callbacks. */
class AndroidRefinementResourceGuard(context: Context) {
    private val app = context.applicationContext
    private val power = app.getSystemService(PowerManager::class.java)
    private val battery = app.getSystemService(BatteryManager::class.java)
    private val memory = app.getSystemService(ActivityManager::class.java)
    private val guard = RefinementResourceGuard(::readSnapshot, ::observeUnsafe, SystemClock::elapsedRealtime)

    fun pauseReason(): String? = guard.pauseReason()
    fun observe(listener: (String) -> Unit): AutoCloseable = guard.observe(listener)

    private fun readSnapshot(): RefinementResourceSnapshot {
        val info = ActivityManager.MemoryInfo()
        memory?.getMemoryInfo(info)
        return RefinementResourceSnapshot(
            power?.currentThermalStatus,
            if (memory == null) null else info.lowMemory,
            power?.isPowerSaveMode,
            battery?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
            battery?.isCharging,
        )
    }

    private fun observeUnsafe(listener: (String) -> Unit): AutoCloseable {
        val owner = RefinementObserverScope()
        fun notify(reason: String) { if (!owner.isClosed) listener(reason) }
        try {
            val manager = checkNotNull(power)
            val thermal = PowerManager.OnThermalStatusChangedListener { status ->
                when {
                    status !in 0..6 -> notify("refinement_resources_unavailable")
                    status >= PowerManager.THERMAL_STATUS_SEVERE -> notify("refinement_thermal_severe")
                }
            }
            owner.register({ manager.addThermalStatusListener(thermal) }, { manager.removeThermalStatusListener(thermal) })
            val callbacks = object : ComponentCallbacks2 {
                override fun onConfigurationChanged(configuration: Configuration) = Unit
                override fun onLowMemory() = notify("refinement_memory_pressure")
                override fun onTrimMemory(level: Int) {
                    RefinementResourcePolicy.memoryTrimPauseReason(level)?.let(::notify)
                }
            }
            owner.register({ app.registerComponentCallbacks(callbacks) }, { app.unregisterComponentCallbacks(callbacks) })
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    when (intent?.action) {
                        Intent.ACTION_BATTERY_LOW -> notify("refinement_battery_low")
                        Intent.ACTION_BATTERY_CHANGED -> {
                            val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                            val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                            val plugged = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
                            if (level < 0 || scale <= 0 || level > scale || status < 0 || plugged < 0) {
                                notify("refinement_resources_unavailable")
                            } else if (level.toLong() * 100 <= scale.toLong() * 15 && plugged == 0 &&
                                status != BatteryManager.BATTERY_STATUS_CHARGING && status != BatteryManager.BATTERY_STATUS_FULL
                            ) notify("refinement_battery_low")
                        }
                        PowerManager.ACTION_POWER_SAVE_MODE_CHANGED -> {
                            try {
                                if (manager.isPowerSaveMode) notify("refinement_power_save")
                            } catch (_: RuntimeException) { notify("refinement_resources_unavailable") }
                        }
                    }
                }
            }
            val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED).apply {
                addAction(Intent.ACTION_BATTERY_LOW)
                addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
            }
            // These are exclusively system broadcasts; no exported app receiver surface.
            owner.register({ app.registerReceiver(receiver, filter) }, { app.unregisterReceiver(receiver) })
            return owner
        } catch (error: Throwable) {
            try { owner.close() } catch (_: Throwable) { /* Preserve registration failure. */ }
            throw error
        }
    }
}
