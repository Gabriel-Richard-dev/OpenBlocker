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
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import dev.openblock.app.R
import kotlin.random.Random

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
 * focus sessions ended from inside OpenBlock. When the user opted in, block
 * screens offer an unlock that takes effort instead: hold a button for
 * [HOLD_SECONDS] seconds, then solve a sum on an on-screen keypad (the window
 * is not focusable, so the system keyboard cannot be used).
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
        /** How long a solved challenge lets the app in; 0 hides the unlock. */
        val unlockMinutes: Int,
        val customMessage: String?,
    ) {
        /** Identity of the screen; a new key means a new intervention. */
        val key: String get() = "$kind|$packageName|$ruleId"
    }

    interface Listener {
        fun onLeave(spec: Spec)
        fun onContinue(spec: Spec)
        fun onUnlock(spec: Spec)
    }

    private val windowManager = service.getSystemService(WindowManager::class.java)
    private val handler = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var countdown: Runnable? = null
    private var holdTick: Runnable? = null

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
        holdTick?.let(handler::removeCallbacks)
        holdTick = null
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
        } else if (spec.unlockMinutes > 0) {
            val unlockArea = LinearLayout(service).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
            }

            fun showChallenge() {
                unlockArea.removeAllViews()
                unlockArea.setPadding(0, dp(24), 0, 0)
                val prompt = text(
                    res.getString(R.string.overlay_unlock_prompt, spec.appLabel, spec.unlockMinutes),
                    15f,
                    muted,
                )
                val problemView = text("", 24f, foreground, bold = true)
                val answerView = text("–", 28f, accent, bold = true)
                unlockArea.addView(prompt)
                unlockArea.addView(problemView)
                unlockArea.addView(answerView)

                var problem = Problem.next()
                var input = ""
                problemView.text = problem.text
                fun refresh() {
                    answerView.text = input.ifEmpty { "–" }
                }

                fun key(label: String, primary: Boolean = false, onClick: () -> Unit) =
                    button(label, primary, onClick).apply {
                        minWidth = 0
                        minimumWidth = 0
                        layoutParams = LinearLayout.LayoutParams(
                            0,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            1f,
                        ).apply { setMargins(dp(4), dp(4), dp(4), dp(4)) }
                    }

                val digitKeys = listOf("1", "2", "3", "4", "5", "6", "7", "8", "9")
                    .map { digit ->
                        key(digit) {
                            if (input.length < MAX_ANSWER_DIGITS) input += digit
                            refresh()
                        }
                    }
                val deleteKey = key("⌫") {
                    input = input.dropLast(1)
                    refresh()
                }.apply { contentDescription = res.getString(R.string.overlay_unlock_delete) }
                val zeroKey = key("0") {
                    if (input.length < MAX_ANSWER_DIGITS) input += "0"
                    refresh()
                }
                val okKey = key(res.getString(R.string.overlay_unlock_ok), primary = true) {
                    if (input.toIntOrNull() == problem.answer) {
                        listener.onUnlock(spec)
                    } else {
                        // A wrong answer gets a new sum, so guessing does not pay.
                        problem = Problem.next()
                        problemView.text = problem.text
                        prompt.text = res.getString(R.string.overlay_unlock_wrong)
                        input = ""
                        refresh()
                    }
                }
                (digitKeys + listOf(deleteKey, zeroKey, okKey)).chunked(3).forEach { row ->
                    unlockArea.addView(
                        LinearLayout(service).apply {
                            orientation = LinearLayout.HORIZONTAL
                            row.forEach { addView(it) }
                        },
                        LinearLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                        ),
                    )
                }
            }

            val holdButton = button(res.getString(R.string.overlay_action_unlock_hold), false) {}
            holdToConfirm(holdButton) { showChallenge() }
            unlockArea.addView(holdButton)
            column.addView(
                unlockArea,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
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

    /** Runs [onHeld] once [button] has been held down for [HOLD_SECONDS]. */
    private fun holdToConfirm(button: Button, onHeld: () -> Unit) {
        val label = button.text
        fun stop() {
            holdTick?.let(handler::removeCallbacks)
            holdTick = null
            button.isPressed = false
            button.text = label
        }
        button.setOnTouchListener { view, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    stop()
                    button.isPressed = true
                    var remaining = HOLD_SECONDS
                    val tick = object : Runnable {
                        override fun run() {
                            if (remaining <= 0) {
                                holdTick = null
                                onHeld()
                                return
                            }
                            button.text = service.resources.getString(
                                R.string.overlay_action_unlock_holding,
                                remaining,
                            )
                            remaining -= 1
                            handler.postDelayed(this, 1000)
                        }
                    }
                    holdTick = tick
                    tick.run()
                }
                MotionEvent.ACTION_UP -> {
                    stop()
                    view.performClick()
                }
                MotionEvent.ACTION_CANCEL -> stop()
            }
            true
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

    /** A sum hard enough to need a moment of thought, e.g. 27 × 6 + 48. */
    private data class Problem(val text: String, val answer: Int) {
        companion object {
            fun next(): Problem {
                val a = Random.nextInt(12, 40)
                val b = Random.nextInt(3, 10)
                val c = Random.nextInt(11, 90)
                return Problem("$a × $b + $c = ?", a * b + c)
            }
        }
    }

    private companion object {
        const val HOLD_SECONDS = 5
        const val MAX_ANSWER_DIGITS = 4
    }
}
