package dev.openblock.app.engine

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDateTime

/**
 * Runs the vectors shared with the Dart engine
 * (test/core/rule_engine_vectors_test.dart) so both stay in lockstep.
 */
class RuleEngineVectorsTest {
    private fun vectorsFile(): File {
        // Unit tests run with the module directory (android/app) as working dir.
        val candidates = listOf(
            "../../test/fixtures/rule_engine_vectors.json",
            "../test/fixtures/rule_engine_vectors.json",
            "test/fixtures/rule_engine_vectors.json",
        )
        return candidates.map(::File).first { it.exists() }
    }

    @Test
    fun allVectorsMatch() {
        val cases = JSONObject(vectorsFile().readText()).getJSONArray("cases")
        assertTrue(cases.length() > 0)
        val failures = mutableListOf<String>()
        for (i in 0 until cases.length()) {
            val vector = cases.getJSONObject(i)
            val name = vector.getString("name")
            val rules = ConfigParser.parseRules(vector.getJSONArray("rules"))
            val local = LocalDateTime.parse(vector.getString("nowLocal"))
            val snoozesJson = vector.getJSONObject("snoozes")
            val snoozes = snoozesJson.keys().asSequence().associateWith { snoozesJson.getLong(it) }
            val ctx = EvaluationContext(
                packageName = vector.getString("packageName"),
                nowMs = vector.getLong("nowMs"),
                weekday = local.dayOfWeek.value,
                minuteOfDay = local.hour * 60 + local.minute,
                usageMinutes = vector.optIntOrNull("usageMinutes"),
                focus = vector.optJSONObject("focus")?.let(ConfigParser::parseFocus),
                snoozes = snoozes,
            )
            val decision = RuleEngine.evaluate(rules, ctx)
            val expected = vector.getJSONObject("expect")
            val expectedTargets = expected.optJSONArray("feedTargets").toStringList()
            val actual = listOf(
                decision.action.jsonName,
                decision.reason.jsonName,
                decision.ruleId,
                decision.feedTargets,
            )
            val wanted = listOf(
                expected.getString("action"),
                expected.getString("reason"),
                expected.optStringOrNull("ruleId"),
                expectedTargets,
            )
            if (actual != wanted) failures.add("$name: expected $wanted but was $actual")
        }
        assertEquals(failures.joinToString("\n"), 0, failures.size)
    }
}
