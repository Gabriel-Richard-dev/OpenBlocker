package dev.openblock.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import dev.openblock.app.MainActivity
import dev.openblock.app.R
import java.util.concurrent.Executors
import kotlin.math.abs

/**
 * Home screen widget: screen time today, how it compares with the usual by
 * this time of day, and the last seven days as bars. Everything is computed on
 * the device from usage access; nothing is stored.
 */
class ProgressWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        renderAsync(context, ids)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        options: Bundle,
    ) {
        renderAsync(context, intArrayOf(id))
    }

    private fun renderAsync(context: Context, ids: IntArray) {
        val pending = goAsync()
        val app = context.applicationContext
        worker.execute {
            try {
                render(app, ids)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private val worker = Executors.newSingleThreadExecutor()

        /** Re-renders every placed widget, e.g. when OpenBlock is opened. */
        fun refresh(context: Context) {
            val app = context.applicationContext
            val manager = AppWidgetManager.getInstance(app)
            val ids = manager.getAppWidgetIds(ComponentName(app, ProgressWidget::class.java))
            if (ids.isEmpty()) return
            worker.execute { render(app, ids) }
        }

        private fun render(context: Context, ids: IntArray) {
            val manager = AppWidgetManager.getInstance(context)
            val progress = ScreenTimeProgress.load(context)
            for (id in ids) {
                manager.updateAppWidget(id, views(context, manager, id, progress))
            }
        }

        private fun views(
            context: Context,
            manager: AppWidgetManager,
            id: Int,
            progress: ScreenTimeProgress?,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_progress)
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)

            if (progress == null) {
                views.setTextViewText(R.id.widget_value, "—")
                views.setTextViewText(R.id.widget_trend, context.getString(R.string.widget_no_permission))
                views.setTextColor(R.id.widget_trend, context.getColor(R.color.widget_muted))
                views.setViewVisibility(R.id.widget_chart, View.GONE)
                views.setViewVisibility(R.id.widget_caption, View.GONE)
                return views
            }

            views.setTextViewText(R.id.widget_value, formatDuration(context, progress.todayMs))
            val change = progress.changePercent
            val (trend, color) = when {
                change == null -> context.getString(R.string.widget_no_history) to R.color.widget_muted
                abs(change) < SAME_PERCENT -> context.getString(R.string.widget_trend_same) to R.color.widget_muted
                change < 0 -> context.getString(R.string.widget_trend_down, -change) to R.color.widget_good
                else -> context.getString(R.string.widget_trend_up, change) to R.color.widget_bad
            }
            views.setTextViewText(R.id.widget_trend, trend)
            views.setTextColor(R.id.widget_trend, context.getColor(color))

            val options = manager.getAppWidgetOptions(id)
            val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).takeIf { it > 0 } ?: 180
            views.setImageViewBitmap(R.id.widget_chart, chart(context, progress.days, widthDp - 32))
            views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
            views.setViewVisibility(R.id.widget_caption, View.VISIBLE)
            return views
        }

        /** One bar per day, today highlighted. */
        private fun chart(context: Context, days: List<Long>, widthDp: Int): Bitmap {
            val width = px(context, widthDp.coerceAtLeast(80))
            val height = px(context, CHART_HEIGHT_DP)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val max = days.maxOrNull()?.takeIf { it > 0 } ?: 1L
            val gap = px(context, 6).toFloat()
            val barWidth = (width - gap * (days.size - 1)) / days.size
            val radius = px(context, 3).toFloat()
            val minBar = px(context, 3).toFloat()
            days.forEachIndexed { index, value ->
                val barHeight = maxOf(minBar, height * (value.toFloat() / max))
                val left = index * (barWidth + gap)
                paint.color = context.getColor(
                    if (index == days.lastIndex) R.color.widget_accent else R.color.widget_bar,
                )
                canvas.drawRoundRect(
                    RectF(left, height - barHeight, left + barWidth, height.toFloat()),
                    radius,
                    radius,
                    paint,
                )
            }
            return bitmap
        }

        private fun formatDuration(context: Context, ms: Long): String {
            val minutes = ms / 60_000L
            return if (minutes < 60) {
                context.getString(R.string.widget_minutes, minutes.toInt())
            } else {
                context.getString(R.string.widget_hours_minutes, (minutes / 60).toInt(), (minutes % 60).toInt())
            }
        }

        private fun px(context: Context, dp: Int): Int = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            context.resources.displayMetrics,
        ).toInt()

        /** Changes smaller than this are reported as "about the usual". */
        private const val SAME_PERCENT = 5
        private const val CHART_HEIGHT_DP = 40
    }
}
