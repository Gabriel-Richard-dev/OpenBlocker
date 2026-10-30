package dev.openblock.app.widget

import android.content.Context
import android.content.Intent
import dev.openblock.app.usage.UsageReader
import java.time.LocalDate
import java.time.ZoneId

/**
 * Screen time today compared with the user's usual: the average of the
 * previous [HISTORY_DAYS] days measured up to the same time of day, so a
 * morning is never compared with whole days.
 */
data class ScreenTimeProgress(
    val todayMs: Long,
    /** Null when there is no history yet. */
    val usualByNowMs: Long?,
    /** Whole-day totals for the last days, oldest first; today last, so far. */
    val days: List<Long>,
) {
    /** Percent change against the usual, e.g. -18 for 18 % less. */
    val changePercent: Int?
        get() {
            val usual = usualByNowMs ?: return null
            if (usual <= 0) return null
            return Math.round((todayMs - usual) * 100.0 / usual).toInt()
        }

    companion object {
        const val HISTORY_DAYS = 7

        /** Returns null without usage access. */
        fun load(context: Context, nowMs: Long = System.currentTimeMillis()): ScreenTimeProgress? {
            val usage = UsageReader(context)
            if (!usage.hasPermission()) return null
            val excluded = excludedPackages(context)
            val zone = ZoneId.systemDefault()
            val today = LocalDate.now(zone)
            val todayStart = today.atStartOfDay(zone).toInstant().toEpochMilli()
            val elapsed = nowMs - todayStart
            val todayMs = usage.screenTimeMs(todayStart, nowMs, excluded) ?: return null

            val past = (HISTORY_DAYS downTo 1).map { offset ->
                val day = today.minusDays(offset.toLong())
                val start = day.atStartOfDay(zone).toInstant().toEpochMilli()
                val end = day.plusDays(1).atStartOfDay(zone).toInstant().toEpochMilli()
                val whole = usage.screenTimeMs(start, end, excluded) ?: 0L
                val byNow = usage.screenTimeMs(start, minOf(start + elapsed, end), excluded) ?: 0L
                whole to byNow
            }
            // Days without any usage are usually days before usage data
            // exists (e.g. right after install), not days off the phone.
            val known = past.filter { it.first > 0 }
            val usual = if (known.size >= MIN_HISTORY_DAYS) known.map { it.second }.average().toLong() else null
            return ScreenTimeProgress(
                todayMs = todayMs,
                usualByNowMs = usual,
                days = past.drop(1).map { it.first } + todayMs,
            )
        }

        /** Time on the home screen, the lock screen or OpenBlock is not screen time. */
        private fun excludedPackages(context: Context): Set<String> {
            val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val launchers = context.packageManager.queryIntentActivities(home, 0)
                .map { it.activityInfo.packageName }
            return launchers.toSet() + context.packageName + "com.android.systemui"
        }

        private const val MIN_HISTORY_DAYS = 2
    }
}
