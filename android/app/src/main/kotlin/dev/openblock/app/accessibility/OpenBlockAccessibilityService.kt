package dev.openblock.app.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager
import dev.openblock.app.accessibility.adapters.FeedAdapters
import dev.openblock.app.accessibility.adapters.recycleCompat
import dev.openblock.app.engine.BlockMode
import dev.openblock.app.engine.BlockRule
import dev.openblock.app.engine.DecisionAction
import dev.openblock.app.engine.DecisionReason
import dev.openblock.app.engine.EvaluationContext
import dev.openblock.app.engine.RuleActivation
import dev.openblock.app.engine.RuleEngine
import dev.openblock.app.overlay.InterventionOverlay
import dev.openblock.app.storage.NativeStore
import dev.openblock.app.usage.UsageReader
import java.time.LocalDateTime

/**
 * Enforces the rules synced from Flutter.
 *
 * Privacy: the service only looks at the package name of the foreground app.
 * For apps with an enabled feed rule it also asks the adapter whether views
 * with known ids are visible. It never reads text, never logs screen content
 * and ignores every app without a rule.
 *
 * Battery: content-change events are only subscribed to while a feed rule
 * exists, feed checks are debounced, and the periodic re-check only runs while
 * an app with rules is in the foreground.
 */
class OpenBlockAccessibilityService : AccessibilityService(), InterventionOverlay.Listener {
    private lateinit var store: NativeStore
    private lateinit var usage: UsageReader
    private lateinit var overlay: InterventionOverlay
    private val handler = Handler(Looper.getMainLooper())

    private var foreground: String? = null
    private var ignoredPackages: Set<String> = emptySet()

    /** Packages where the pause screen was acknowledged during this visit. */
    private val acknowledged = HashSet<String>()
    private val usageCache = HashMap<String, Pair<Long, Int?>>()
    private val labelCache = HashMap<String, String>()
    private var lastRecorded: Pair<String, Long>? = null
    private var feedCheckPending = false

    private val feedCheck = Runnable {
        feedCheckPending = false
        evaluate()
    }

    private val ticker = object : Runnable {
        override fun run() {
            evaluate()
        }
    }

    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
        when (key) {
            NativeStore.KEY_CONFIG -> {
                usageCache.clear()
                updateServiceInfo()
                evaluate()
            }
            NativeStore.KEY_SNOOZES, NativeStore.KEY_FOCUS_ENDED_ID -> evaluate()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        store = NativeStore.get(this)
        usage = UsageReader(this)
        overlay = InterventionOverlay(this)
        ignoredPackages = computeIgnoredPackages()
        store.prefs.registerOnSharedPreferenceChangeListener(prefsListener)
        updateServiceInfo()
        isConnected = true
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !::store.isInitialized) return
        val pkg = event.packageName?.toString() ?: return
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> onWindowChanged(pkg)
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED,
            -> if (pkg == foreground) scheduleFeedCheck()
        }
    }

    override fun onInterrupt() {
        if (::overlay.isInitialized) overlay.hide()
    }

    override fun onUnbind(intent: Intent?): Boolean {
        shutdown()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        shutdown()
        super.onDestroy()
    }

    private fun shutdown() {
        isConnected = false
        handler.removeCallbacksAndMessages(null)
        if (::store.isInitialized) {
            store.prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
        }
        if (::overlay.isInitialized) overlay.hide()
    }

    private fun computeIgnoredPackages(): Set<String> {
        val ignored = mutableSetOf(packageName, "com.android.systemui")
        val imm = getSystemService(InputMethodManager::class.java)
        imm?.enabledInputMethodList?.forEach { ignored.add(it.packageName) }
        return ignored
    }

    /** Subscribe to content changes only while a feed rule needs them. */
    private fun updateServiceInfo() {
        val info = serviceInfo ?: return
        var types = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        if (store.config().hasSelectiveFeedRules) {
            types = types or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_SCROLLED
        }
        if (info.eventTypes != types) {
            info.eventTypes = types
            serviceInfo = info
        }
    }

    private fun onWindowChanged(eventPackage: String) {
        if (eventPackage in ignoredPackages) return
        // Confirm with the active window: dialogs and toasts from other
        // packages also emit window events.
        val root = rootInActiveWindow
        val activePackage = root?.packageName?.toString()
        root?.recycleCompat()
        val current = activePackage?.takeIf { it !in ignoredPackages } ?: eventPackage
        if (current != foreground) {
            foreground?.let { acknowledged.remove(it) }
            foreground = current
            if (overlay.current?.packageName != current) overlay.hide()
        }
        evaluate()
    }

    private fun scheduleFeedCheck() {
        if (feedCheckPending) return
        val pkg = foreground ?: return
        if (!FeedAdapters.supports(pkg)) return
        val hasFeedRule = store.config().rulesFor(pkg).any {
            it.enabled && it.mode == BlockMode.SELECTIVE_FEED
        }
        if (!hasFeedRule) return
        feedCheckPending = true
        handler.postDelayed(feedCheck, FEED_CHECK_DEBOUNCE_MS)
    }

    private fun usageMinutes(pkg: String, nowMs: Long): Int? {
        val cached = usageCache[pkg]
        if (cached != null && nowMs - cached.first < USAGE_CACHE_MS) return cached.second
        val minutes = usage.minutesToday(pkg, nowMs)
        usageCache[pkg] = nowMs to minutes
        return minutes
    }

    private fun evaluate() {
        if (!::store.isInitialized) return
        handler.removeCallbacks(ticker)
        val pkg = foreground ?: return
        val config = store.config()
        val rules = config.rulesFor(pkg)
        if (rules.isEmpty()) {
            overlay.hide()
            return
        }
        val nowMs = System.currentTimeMillis()
        val local = LocalDateTime.now()
        val needsUsage = rules.any { it.enabled && it.mode == BlockMode.APP_LIMIT }
        val ctx = EvaluationContext(
            packageName = pkg,
            nowMs = nowMs,
            weekday = local.dayOfWeek.value,
            minuteOfDay = local.hour * 60 + local.minute,
            usageMinutes = if (needsUsage) usageMinutes(pkg, nowMs) else null,
            focus = store.effectiveFocus(config),
            snoozes = store.snoozes(nowMs),
        )
        val decision = RuleEngine.evaluate(rules, ctx)
        val rule = rules.firstOrNull { it.id == decision.ruleId }

        when (decision.action) {
            DecisionAction.NONE -> overlay.hide()
            DecisionAction.BLOCK_APP -> if (rule != null) {
                val kind = when (decision.reason) {
                    DecisionReason.LIMIT -> InterventionOverlay.Kind.LIMIT
                    DecisionReason.FOCUS -> InterventionOverlay.Kind.FOCUS
                    else -> InterventionOverlay.Kind.BLOCK
                }
                show(kind, pkg, rule, ctx, nowMs)
            }
            DecisionAction.PAUSE -> if (rule != null) {
                if (pkg in acknowledged) {
                    overlay.hide()
                } else {
                    show(InterventionOverlay.Kind.PAUSE, pkg, rule, ctx, nowMs)
                }
            }
            DecisionAction.BLOCK_FEED -> if (rule != null) {
                if (isFeedVisible(pkg, decision.feedTargets)) {
                    show(InterventionOverlay.Kind.FEED, pkg, rule, ctx, nowMs)
                } else if (overlay.current?.kind == InterventionOverlay.Kind.FEED) {
                    overlay.hide()
                }
            }
        }
        // Schedules, limits and focus sessions change over time even when no
        // event arrives, so re-check while an app with rules is in front.
        handler.postDelayed(ticker, TICK_MS)
    }

    private fun isFeedVisible(pkg: String, targets: List<String>): Boolean {
        val root = rootInActiveWindow ?: return false
        return try {
            if (root.packageName?.toString() != pkg) return false
            FeedAdapters.forPackage(pkg).any { it.detect(root, targets) != null }
        } finally {
            root.recycleCompat()
        }
    }

    private fun show(
        kind: InterventionOverlay.Kind,
        pkg: String,
        rule: BlockRule,
        ctx: EvaluationContext,
        nowMs: Long,
    ) {
        val config = store.config()
        val byFocus = RuleEngine.activation(rule, ctx) == RuleActivation.ACTIVE_BY_FOCUS
        val spec = InterventionOverlay.Spec(
            kind = kind,
            packageName = pkg,
            ruleId = rule.id,
            ruleName = rule.name,
            appLabel = appLabel(pkg),
            focusId = if (byFocus) ctx.focus?.id else null,
            countdownSeconds = config.pauseSeconds,
            snoozeMinutes = config.snoozeMinutes,
            customMessage = config.pauseMessage,
        )
        overlay.show(spec, this)
        val last = lastRecorded
        if (overlay.isShowing && (last == null || last.first != spec.key || nowMs - last.second > RECORD_DEDUP_MS)) {
            store.recordEvent(rule.id, pkg, kind.eventName, nowMs)
            lastRecorded = spec.key to nowMs
        }
    }

    private fun appLabel(pkg: String): String = labelCache.getOrPut(pkg) {
        try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (_: Exception) {
            pkg
        }
    }

    override fun onLeave(spec: InterventionOverlay.Spec) {
        overlay.hide()
        if (spec.kind == InterventionOverlay.Kind.FEED) {
            performGlobalAction(GLOBAL_ACTION_BACK)
        } else {
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
        handler.postDelayed({ evaluate() }, LEAVE_RECHECK_MS)
    }

    override fun onSnooze(spec: InterventionOverlay.Spec) {
        overlay.hide()
        store.snooze(spec.ruleId, System.currentTimeMillis() + spec.snoozeMinutes * 60_000L)
    }

    override fun onContinue(spec: InterventionOverlay.Spec) {
        acknowledged.add(spec.packageName)
        overlay.hide()
    }

    override fun onEndFocus(spec: InterventionOverlay.Spec) {
        overlay.hide()
        spec.focusId?.let { store.endFocus(it, System.currentTimeMillis()) }
    }

    companion object {
        private const val FEED_CHECK_DEBOUNCE_MS = 400L
        private const val USAGE_CACHE_MS = 30_000L
        private const val TICK_MS = 30_000L
        private const val LEAVE_RECHECK_MS = 700L
        private const val RECORD_DEDUP_MS = 60_000L

        @Volatile
        var isConnected: Boolean = false
            private set
    }
}
