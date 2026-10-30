package dev.openblock.app.storage

import android.content.Context
import android.content.SharedPreferences
import dev.openblock.app.engine.ConfigParser
import dev.openblock.app.engine.FocusSession
import dev.openblock.app.engine.OpenBlockConfig
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native storage shared by the Flutter bridge and the accessibility service,
 * which run in the same process.
 *
 * Plain SharedPreferences is used instead of DataStore because the service
 * needs synchronous reads on the main thread when an accessibility event
 * arrives, and the data is a few kilobytes at most. The Flutter side keeps its
 * own copy in DataStore (via shared_preferences) and is the source of truth for
 * rules; this store only mirrors the last synced config plus runtime state.
 */
class NativeStore private constructor(context: Context) {
    val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Volatile
    private var cachedConfigJson: String? = null

    @Volatile
    private var cachedConfig: OpenBlockConfig = OpenBlockConfig.EMPTY

    fun saveConfig(json: String) {
        prefs.edit().putString(KEY_CONFIG, json).apply()
    }

    fun config(): OpenBlockConfig {
        val json = prefs.getString(KEY_CONFIG, null)
        if (json != cachedConfigJson) {
            cachedConfig = ConfigParser.parseConfig(json)
            cachedConfigJson = json
        }
        return cachedConfig
    }

    /** The configured focus session, unless it was ended from the overlay. */
    fun effectiveFocus(config: OpenBlockConfig = config()): FocusSession? {
        val focus = config.focus ?: return null
        return if (prefs.getString(KEY_FOCUS_ENDED_ID, null) == focus.id) null else focus
    }

    fun snoozes(nowMs: Long = System.currentTimeMillis()): Map<String, Long> {
        val obj = readObject(KEY_SNOOZES)
        val result = HashMap<String, Long>()
        val keys = obj.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val until = obj.optLong(key)
            if (until > nowMs) result[key] = until
        }
        return result
    }

    fun clearSnooze(ruleId: String) {
        val obj = JSONObject()
        snoozes().filterKeys { it != ruleId }.forEach { (id, until) -> obj.put(id, until) }
        prefs.edit().putString(KEY_SNOOZES, obj.toString()).apply()
    }

    /** Set while the bank guard has the accessibility service turned off. */
    fun isBankPaused(): Boolean = prefs.getBoolean(KEY_BANK_PAUSED, false)

    fun setBankPaused(paused: Boolean) {
        // Committed synchronously: the process may die right after the
        // accessibility service turns itself off.
        prefs.edit().putBoolean(KEY_BANK_PAUSED, paused).commit()
    }

    fun endedFocusId(): String? = prefs.getString(KEY_FOCUS_ENDED_ID, null)

    fun endedFocusAtMs(): Long? =
        if (prefs.contains(KEY_FOCUS_ENDED_AT)) prefs.getLong(KEY_FOCUS_ENDED_AT, 0L) else null

    /** Records that an intervention screen was shown. No screen content is kept. */
    fun recordEvent(ruleId: String, packageName: String, kind: String, atMs: Long) {
        val events = readArray(KEY_EVENTS)
        val minMs = atMs - EVENT_RETENTION_MS
        val kept = JSONArray()
        for (i in 0 until events.length()) {
            val event = events.optJSONObject(i) ?: continue
            if (event.optLong("atMs") >= minMs) kept.put(event)
        }
        kept.put(
            JSONObject()
                .put("atMs", atMs)
                .put("ruleId", ruleId)
                .put("packageName", packageName)
                .put("kind", kind),
        )
        val trimmed = if (kept.length() > MAX_EVENTS) {
            JSONArray().also { out ->
                for (i in kept.length() - MAX_EVENTS until kept.length()) out.put(kept.get(i))
            }
        } else {
            kept
        }
        prefs.edit().putString(KEY_EVENTS, trimmed.toString()).apply()
    }

    fun events(): JSONArray = readArray(KEY_EVENTS)

    /** Deletes statistics and runtime state, keeping the synced config. */
    fun clearRuntime() {
        prefs.edit()
            .remove(KEY_EVENTS)
            .remove(KEY_SNOOZES)
            .remove(KEY_FOCUS_ENDED_ID)
            .remove(KEY_FOCUS_ENDED_AT)
            .apply()
    }

    private fun readObject(key: String): JSONObject = try {
        JSONObject(prefs.getString(key, null) ?: "{}")
    } catch (_: Exception) {
        JSONObject()
    }

    private fun readArray(key: String): JSONArray = try {
        JSONArray(prefs.getString(key, null) ?: "[]")
    } catch (_: Exception) {
        JSONArray()
    }

    companion object {
        const val PREFS = "openblock_native"
        const val KEY_CONFIG = "config"
        const val KEY_SNOOZES = "snoozes"
        const val KEY_FOCUS_ENDED_ID = "focus_ended_id"
        const val KEY_FOCUS_ENDED_AT = "focus_ended_at"
        const val KEY_EVENTS = "events"
        const val KEY_BANK_PAUSED = "bank_paused"
        const val MAX_EVENTS = 2000
        const val EVENT_RETENTION_MS = 30L * 24 * 60 * 60 * 1000

        @Volatile
        private var instance: NativeStore? = null

        fun get(context: Context): NativeStore =
            instance ?: synchronized(this) {
                instance ?: NativeStore(context).also { instance = it }
            }
    }
}
