package dev.openblock.app.engine

import org.json.JSONArray
import org.json.JSONObject

/** Parses the JSON documents produced by the Flutter side. */
object ConfigParser {
    private val HM = Regex("""^(\d{2}):(\d{2})$""")

    fun parseHm(value: String?): Int? {
        if (value == null) return null
        val match = HM.matchEntire(value) ?: return null
        val hours = match.groupValues[1].toInt()
        val minutes = match.groupValues[2].toInt()
        if (hours > 23 || minutes > 59) return null
        return hours * 60 + minutes
    }

    fun parseConfig(json: String?): OpenBlockConfig {
        if (json.isNullOrBlank()) return OpenBlockConfig.EMPTY
        return try {
            parseConfig(JSONObject(json))
        } catch (_: Exception) {
            OpenBlockConfig.EMPTY
        }
    }

    fun parseConfig(obj: JSONObject): OpenBlockConfig = OpenBlockConfig(
        rules = parseRules(obj.optJSONArray("rules")),
        focus = obj.optJSONObject("focus")?.let(::parseFocus),
        pauseSeconds = obj.optInt("pauseSeconds", 10),
        pauseMessage = obj.optStringOrNull("pauseMessage"),
        bankPackages = obj.optJSONArray("bankPackages").toStringList().toSet(),
    )

    fun parseRules(array: JSONArray?): List<BlockRule> {
        if (array == null) return emptyList()
        val rules = ArrayList<BlockRule>(array.length())
        for (i in 0 until array.length()) {
            val rule = array.optJSONObject(i)?.let(::parseRule) ?: continue
            rules.add(rule)
        }
        return rules
    }

    /** Returns null for entries that cannot be enforced (unknown mode, no id). */
    fun parseRule(obj: JSONObject): BlockRule? {
        val mode = BlockMode.fromJson(obj.optString("mode")) ?: return null
        val id = obj.optStringOrNull("id") ?: return null
        val packageName = obj.optStringOrNull("packageName") ?: return null
        return BlockRule(
            id = id,
            name = obj.optString("name", ""),
            packageName = packageName,
            mode = mode,
            enabled = obj.optBoolean("enabled", true),
            dailyLimitMinutes = obj.optIntOrNull("dailyLimitMinutes"),
            activeWeekdays = obj.optJSONArray("activeWeekdays").toIntList(),
            startMinute = parseHm(obj.optStringOrNull("startTime")),
            endMinute = parseHm(obj.optStringOrNull("endTime")),
            feedTargets = obj.optJSONArray("feedTargets").toStringList(),
            focusOnly = obj.optBoolean("focusOnly", false),
            pausedUntilMs = obj.optLongOrNull("pausedUntilMs"),
        )
    }

    fun parseFocus(obj: JSONObject): FocusSession? {
        val id = obj.optStringOrNull("id") ?: return null
        return FocusSession(
            id = id,
            startedAtMs = obj.optLong("startedAtMs"),
            plannedEndAtMs = obj.optLong("plannedEndAtMs"),
            activeRuleIds = obj.optJSONArray("activeRuleIds").toStringList(),
            endedAtMs = obj.optLongOrNull("endedAtMs"),
        )
    }
}

internal fun JSONObject.optStringOrNull(key: String): String? =
    if (has(key) && !isNull(key)) getString(key) else null

internal fun JSONObject.optIntOrNull(key: String): Int? =
    if (has(key) && !isNull(key)) getInt(key) else null

internal fun JSONObject.optLongOrNull(key: String): Long? =
    if (has(key) && !isNull(key)) getLong(key) else null

internal fun JSONArray?.toIntList(): List<Int> {
    if (this == null) return emptyList()
    return (0 until length()).map { getInt(it) }
}

internal fun JSONArray?.toStringList(): List<String> {
    if (this == null) return emptyList()
    return (0 until length()).map { getString(it) }
}
