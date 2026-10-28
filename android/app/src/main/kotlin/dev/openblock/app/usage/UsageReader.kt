package dev.openblock.app.usage

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process
import java.time.LocalDate
import java.time.ZoneId

/**
 * Reads measured foreground time from UsageStatsManager. Requires the user to
 * grant "Usage access" in system settings; every method returns null without it.
 */
class UsageReader(private val context: Context) {
    private val manager = context.getSystemService(UsageStatsManager::class.java)

    fun hasPermission(): Boolean {
        val appOps = context.getSystemService(AppOpsManager::class.java) ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Foreground minutes today for [packageName], or null without permission. */
    fun minutesToday(packageName: String, nowMs: Long = System.currentTimeMillis()): Int? {
        if (!hasPermission()) return null
        val zone = ZoneId.systemDefault()
        val start = LocalDate.now(zone).atStartOfDay(zone).toInstant().toEpochMilli()
        val totals = foregroundMs(start, nowMs, setOf(packageName)) ?: return null
        return ((totals[packageName] ?: 0L) / 60_000L).toInt()
    }

    /**
     * Minutes per package for each of the last [days] local days (oldest
     * first), limited to [packages].
     */
    fun dailyUsage(packages: Set<String>, days: Int, nowMs: Long = System.currentTimeMillis()):
        List<Pair<LocalDate, Map<String, Int>>>? {
        if (!hasPermission()) return null
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        return (days - 1 downTo 0).map { offset ->
            val day = today.minusDays(offset.toLong())
            val start = day.atStartOfDay(zone).toInstant().toEpochMilli()
            val end = minOf(day.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli(), nowMs)
            val totals = foregroundMs(start, end, packages) ?: emptyMap()
            day to totals.mapValues { (it.value / 60_000L).toInt() }
        }
    }

    /**
     * Sums foreground time from activity resume/pause events. An app that was
     * already in the foreground at [startMs] is counted from [startMs]; one
     * still in the foreground at [endMs] is counted until [endMs].
     */
    private fun foregroundMs(startMs: Long, endMs: Long, packages: Set<String>): Map<String, Long>? {
        if (endMs <= startMs) return emptyMap()
        val events = try {
            manager?.queryEvents(startMs, endMs) ?: return null
        } catch (_: SecurityException) {
            return null
        }
        val totals = HashMap<String, Long>()
        val openSince = HashMap<String, Long>()
        val seen = HashSet<String>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (pkg !in packages) continue
            when (event.eventType) {
                RESUMED -> {
                    seen.add(pkg)
                    if (pkg !in openSince) openSince[pkg] = event.timeStamp
                }
                PAUSED -> {
                    val since = openSince.remove(pkg) ?: if (pkg !in seen) startMs else null
                    seen.add(pkg)
                    if (since != null) {
                        totals[pkg] = (totals[pkg] ?: 0L) + (event.timeStamp - since)
                    }
                }
            }
        }
        openSince.forEach { (pkg, since) ->
            totals[pkg] = (totals[pkg] ?: 0L) + (endMs - since)
        }
        return totals
    }

    companion object {
        // ACTIVITY_RESUMED / ACTIVITY_PAUSED (API 29) share their values with the
        // older MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND constants.
        private const val RESUMED = 1
        private const val PAUSED = 2
    }
}
