package dev.openblock.app.engine

/**
 * Native mirror of the Dart models in `lib/data/models/`. The JSON names are
 * shared with Flutter; see `ConfigParser`.
 */
enum class BlockMode(val jsonName: String) {
    APP_LIMIT("appLimit"),
    SCHEDULED_BLOCK("scheduledBlock"),
    SELECTIVE_FEED("selectiveFeed"),
    PAUSE_SCREEN("pauseScreen"),
    ALLOW_EXCEPTION("allowException");

    companion object {
        fun fromJson(name: String): BlockMode? = entries.firstOrNull { it.jsonName == name }
    }
}

data class BlockRule(
    val id: String,
    val name: String,
    val packageName: String,
    val mode: BlockMode,
    val enabled: Boolean = true,
    val dailyLimitMinutes: Int? = null,
    /** ISO weekdays (1 = Monday … 7 = Sunday). Empty means every day. */
    val activeWeekdays: List<Int> = emptyList(),
    /** Minutes since midnight, or null for all day. */
    val startMinute: Int? = null,
    val endMinute: Int? = null,
    val feedTargets: List<String> = emptyList(),
    val focusOnly: Boolean = false,
    val pausedUntilMs: Long? = null,
)

data class FocusSession(
    val id: String,
    val startedAtMs: Long,
    val plannedEndAtMs: Long,
    val activeRuleIds: List<String>,
    val endedAtMs: Long? = null,
)

data class OpenBlockConfig(
    val rules: List<BlockRule> = emptyList(),
    val focus: FocusSession? = null,
    val snoozeMinutes: Int = 5,
    val pauseSeconds: Int = 10,
    val pauseMessage: String? = null,
) {
    val packages: Set<String> by lazy { rules.mapTo(mutableSetOf()) { it.packageName } }

    fun rulesFor(packageName: String): List<BlockRule> = rules.filter { it.packageName == packageName }

    val hasSelectiveFeedRules: Boolean
        get() = rules.any { it.enabled && it.mode == BlockMode.SELECTIVE_FEED }

    companion object {
        val EMPTY = OpenBlockConfig()
    }
}

enum class DecisionAction(val jsonName: String) {
    NONE("none"),
    PAUSE("pause"),
    BLOCK_FEED("blockFeed"),
    BLOCK_APP("blockApp"),
}

enum class DecisionReason(val jsonName: String) {
    NO_RULE("noRule"),
    EXCEPTION("exception"),
    SCHEDULED("scheduled"),
    FOCUS("focus"),
    LIMIT("limit"),
    FEED("feed"),
    PAUSE("pause"),
}

data class Decision(
    val action: DecisionAction,
    val reason: DecisionReason,
    val ruleId: String? = null,
    val feedTargets: List<String> = emptyList(),
) {
    companion object {
        val ALLOW = Decision(DecisionAction.NONE, DecisionReason.NO_RULE)
    }
}

data class EvaluationContext(
    val packageName: String,
    val nowMs: Long,
    /** ISO weekday in local time (1 = Monday). */
    val weekday: Int,
    /** Minutes since local midnight. */
    val minuteOfDay: Int,
    /** Measured minutes today, or null when unknown. Limits need a value. */
    val usageMinutes: Int? = null,
    val focus: FocusSession? = null,
    val snoozes: Map<String, Long> = emptyMap(),
)

enum class RuleActivation {
    DISABLED,
    PAUSED,
    FOCUS_ONLY_IDLE,
    OUTSIDE_SCHEDULE,
    ACTIVE,
    ACTIVE_BY_FOCUS;

    val isActive: Boolean
        get() = this == ACTIVE || this == ACTIVE_BY_FOCUS
}
