package dev.openblock.app.overlay

import android.accessibilityservice.AccessibilityService
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import dev.openblock.app.R

/**
 * Full-screen pause/block screen drawn as an accessibility overlay
 * (TYPE_ACCESSIBILITY_OVERLAY), so "Display over other apps" is not needed.
 *
 * The window is not focusable: the system back and home gestures still reach
 * the app underneath, which means the user can always leave. Nothing on this
 * screen hides or locks the device settings.
 *
 * Blocks deliberately offer no snooze and no way to end a focus session from
 * here: a one-tap escape defeats the rule. Rules can still be paused or
 * focus sessions ended from inside OpenBlock.
 */
class InterventionOverlay(private val service: AccessibilityService) {
    enum class Kind(val eventName: String) {
        BLOCK("block"),
        LIMIT("limit"),
        FOCUS("focus"),
        FEED("feed"),
        PAUSE("pause"),
    }

    data class Spec(
        val kind: Kind,
        val packageName: String,
        val ruleId: String,
        val ruleName: String,
        val appLabel: String,
        val focusId: String?,
        val countdownSeconds: Int,
        val customMessage: String?,
    ) {
        /** Identity of the screen; a new key means a new intervention. */
        val key: String get() = "$kind|$packageName|$ruleId"
    }

    interface Listener {
        fun onLeave(spec: Spec)
        fun onContinue(spec: Spec)
    }

    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var countdown: Runnable? = null

    var current: Spec? = null
        private set

    val isShowing: Boolean get() = view != null

    fun show(spec: Spec, listener: Listener) {
        if (current?.key == spec.key && view != null) return
        hide()
        val root = build(spec, listener)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        try {
            windowManager.addView(root, params)
            view = root
            current = spec
        } catch (_: RuntimeException) {
            // The service may be disconnecting; there is nothing to show on.
            view = null
            current = null
        }
    }

    fun hide() {
        countdown?.let(handler::removeCallbacks)
        countdown = null
        view?.let {
            try {
                windowManager.removeView(it)
            } catch (_: RuntimeException) {
                // Already removed.
            }
        }
        view = null
        current = null
    }

    private fun isDark(): Boolean =
        (service.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        service.resources.displayMetrics,
    ).toInt()

    private fun build(spec: Spec, listener: Listener): View {
        val dark = isDark()
        val backgroundColor = if (dark) Color.rgb(0x12, 0x15, 0x14) else Color.rgb(0xF6, 0xF7, 0xF6)
        val foreground = if (dark) Color.rgb(0xE3, 0xE6, 0xE4) else Color.rgb(0x1A, 0x1C, 0x1B)
        val muted = if (dark) Color.rgb(0xB0, 0xB8, 0xB4) else Color.rgb(0x52, 0x5B, 0x57)
        val accent = if (dark) Color.rgb(0x8C, 0xD5, 0xC1) else Color.rgb(0x2E, 0x7D, 0x6B)
        val onAccent = if (dark) Color.rgb(0x00, 0x37, 0x2D) else Color.WHITE
        val res = service.resources

        val (title, message) = when (spec.kind) {
            Kind.BLOCK -> res.getString(R.string.overlay_title_block) to
                res.getString(R.string.overlay_message_block, spec.ruleName)
            Kind.LIMIT -> res.getString(R.string.overlay_title_limit) to
                res.getString(R.string.overlay_message_limit, spec.appLabel)
            Kind.FOCUS -> res.getString(R.string.overlay_title_focus) to
                res.getString(R.string.overlay_message_focus, spec.appLabel)
            Kind.FEED -> res.getString(R.string.overlay_title_feed) to
                res.getString(
                    if (spec.focusId != null) R.string.overlay_message_feed_focus
                    else R.string.overlay_message_feed,
                )
            Kind.PAUSE -> res.getString(R.string.overlay_title_pause) to
                res.getString(R.string.overlay_message_pause, spec.appLabel)
        }
        val question = spec.customMessage?.takeIf { it.isNotBlank() }
            ?: res.getString(R.string.overlay_question)

        val column = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(32), dp(48), dp(32), dp(48))
        }

        fun text(value: String, sizeSp: Float, color: Int, bold: Boolean = false) =
            TextView(service).apply {
                text = value
                setTextColor(color)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
                gravity = Gravity.CENTER
                if (bold) typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                setPadding(0, 0, 0, dp(16))
            }

        fun button(label: String, primary: Boolean, onClick: () -> Unit) =
            Button(service).apply {
                text = label
                isAllCaps = false
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTextColor(if (primary) onAccent else accent)
                background = GradientDrawable().apply {
                    cornerRadius = dp(28).toFloat()
                    if (primary) setColor(accent) else setStroke(dp(1), accent)
                }
                minHeight = dp(52)
                setOnClickListener { onClick() }
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ).apply { topMargin = dp(12) }
            }

        column.addView(text(res.getString(R.string.app_name), 14f, accent, bold = true))
        column.addView(text(title, 26f, foreground, bold = true))
        column.addView(text(message, 17f, muted))
        column.addView(text(question, 18f, foreground))

        val leaveLabel = if (spec.kind == Kind.FEED) {
            res.getString(R.string.overlay_action_back)
        } else {
            res.getString(R.string.overlay_action_home)
        }
        column.addView(button(leaveLabel, primary = true) { listener.onLeave(spec) })

        if (spec.kind == Kind.PAUSE) {
            val continueButton = button(res.getString(R.string.overlay_action_continue), false) {
                listener.onContinue(spec)
            }
            column.addView(continueButton)
            startCountdown(continueButton, spec.countdownSeconds)
        }

        val scroll = ScrollView(service).apply {
            isFillViewport = true
            addView(
                FrameLayout(service).apply {
                    addView(
                        column,
                        FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            Gravity.CENTER,
                        ),
                    )
                },
            )
        }
        return FrameLayout(service).apply {
            setBackgroundColor(backgroundColor)
            // Swallow touches so the app underneath cannot be used.
            isClickable = true
            addView(scroll)
        }
    }

    private fun startCountdown(button: Button, seconds: Int) {
        val label = service.resources.getString(R.string.overlay_action_continue)
        if (seconds <= 0) return
        var remaining = seconds
        button.isEnabled = false
        button.alpha = 0.5f
        val tick = object : Runnable {
            override fun run() {
                if (remaining <= 0) {
                    button.isEnabled = true
                    button.alpha = 1f
                    button.text = label
                    countdown = null
                    return
                }
                button.text = service.resources.getString(
                    R.string.overlay_action_continue_in,
                    remaining,
                )
                remaining -= 1
                handler.postDelayed(this, 1000)
            }
        }
        countdown = tick
        tick.run()
    }
}
