package dev.openblock.app.engine

/**
 * Kotlin port of `lib/core/rule_engine.dart`. Both implementations are tested
 * against `test/fixtures/rule_engine_vectors.json`, so keep them in lockstep.
 *
 * Precedence (docs/rule-precedence.md):
 *  1. Disabled, paused or snoozed rules are ignored.
 *  2. An active exception for the app wins over everything.
 *  3. Whole-app block: scheduledBlock first, then an exceeded appLimit.
 *  4. selectiveFeed: the union of the active rules' feed targets.
 *  5. pauseScreen.
 */
object RuleEngine {
    fun weekdayMatches(weekdays: List<Int>, weekday: Int): Boolean =
        weekdays.isEmpty() || weekdays.contains(weekday)

    fun previousWeekday(weekday: Int): Int = if (weekday == 1) 7 else weekday - 1

    fun scheduleMatches(rule: BlockRule, weekday: Int, minuteOfDay: Int): Boolean {
        val start = rule.startMinute
        val end = rule.endMinute
        if (start == null || end == null || start == end) {
            return weekdayMatches(rule.activeWeekdays, weekday)
        }
        if (start < end) {
            return weekdayMatches(rule.activeWeekdays, weekday) &&
                minuteOfDay >= start && minuteOfDay < end
        }
        // Overnight window; the weekday is the day on which the window starts.
        if (minuteOfDay >= start) return weekdayMatches(rule.activeWeekdays, weekday)
        if (minuteOfDay < end) {
            return weekdayMatches(rule.activeWeekdays, previousWeekday(weekday))
        }
        return false
    }

    fun isFocusActive(focus: FocusSession?, nowMs: Long): Boolean {
        if (focus == null || focus.endedAtMs != null) return false
        return nowMs >= focus.startedAtMs && nowMs < focus.plannedEndAtMs
    }

    fun activation(rule: BlockRule, ctx: EvaluationContext): RuleActivation {
        if (!rule.enabled) return RuleActivation.DISABLED
        val snoozedUntil = ctx.snoozes[rule.id]
        val paused = (rule.pausedUntilMs ?: 0L) > ctx.nowMs
        if (paused || (snoozedUntil != null && snoozedUntil > ctx.nowMs)) {
            return RuleActivation.PAUSED
        }
        val inFocus = isFocusActive(ctx.focus, ctx.nowMs) &&
            ctx.focus!!.activeRuleIds.contains(rule.id)
        if (rule.focusOnly) {
            return if (inFocus) RuleActivation.ACTIVE_BY_FOCUS else RuleActivation.FOCUS_ONLY_IDLE
        }
        if (inFocus) return RuleActivation.ACTIVE_BY_FOCUS
        return if (scheduleMatches(rule, ctx.weekday, ctx.minuteOfDay)) {
            RuleActivation.ACTIVE
        } else {
            RuleActivation.OUTSIDE_SCHEDULE
        }
    }

    fun limitReached(rule: BlockRule, usageMinutes: Int?): Boolean {
        val limit = rule.dailyLimitMinutes ?: return false
        return usageMinutes != null && usageMinutes >= limit
    }

    fun evaluate(rules: List<BlockRule>, ctx: EvaluationContext): Decision {
        val active = rules
            .filter { it.packageName == ctx.packageName }
            .map { it to activation(it, ctx) }
            .filter { it.second.isActive }
        if (active.isEmpty()) return Decision.ALLOW

        active.firstOrNull { it.first.mode == BlockMode.ALLOW_EXCEPTION }?.let { (rule, _) ->
            return Decision(DecisionAction.NONE, DecisionReason.EXCEPTION, rule.id)
        }

        active.firstOrNull { it.first.mode == BlockMode.SCHEDULED_BLOCK }?.let { (rule, state) ->
            val reason = if (state == RuleActivation.ACTIVE_BY_FOCUS) {
                DecisionReason.FOCUS
            } else {
                DecisionReason.SCHEDULED
            }
            return Decision(DecisionAction.BLOCK_APP, reason, rule.id)
        }

        active.firstOrNull {
            it.first.mode == BlockMode.APP_LIMIT && limitReached(it.first, ctx.usageMinutes)
        }?.let { (rule, _) ->
            return Decision(DecisionAction.BLOCK_APP, DecisionReason.LIMIT, rule.id)
        }

        val feedRules = active.map { it.first }.filter { it.mode == BlockMode.SELECTIVE_FEED }
        val targets = LinkedHashSet<String>()
        feedRules.forEach { targets.addAll(it.feedTargets) }
        if (feedRules.isNotEmpty() && targets.isNotEmpty()) {
            return Decision(
                DecisionAction.BLOCK_FEED,
                DecisionReason.FEED,
                feedRules.first().id,
                targets.toList(),
            )
        }

        active.firstOrNull { it.first.mode == BlockMode.PAUSE_SCREEN }?.let { (rule, _) ->
            return Decision(DecisionAction.PAUSE, DecisionReason.PAUSE, rule.id)
        }

        return Decision.ALLOW
    }
}
