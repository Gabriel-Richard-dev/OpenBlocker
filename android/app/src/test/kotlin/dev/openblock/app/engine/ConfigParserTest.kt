package dev.openblock.app.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ConfigParserTest {
    @Test
    fun parsesHm() {
        assertEquals(0, ConfigParser.parseHm("00:00"))
        assertEquals(570, ConfigParser.parseHm("09:30"))
        assertNull(ConfigParser.parseHm("24:00"))
        assertNull(ConfigParser.parseHm("9:30"))
        assertNull(ConfigParser.parseHm(null))
    }

    @Test
    fun parsesFullConfig() {
        val json = """
            {
              "version": 1,
              "rules": [
                {"id": "a", "name": "A", "packageName": "p", "mode": "appLimit",
                 "enabled": true, "dailyLimitMinutes": 30, "activeWeekdays": [1, 2],
                 "startTime": "08:00", "endTime": "12:30", "feedTargets": [],
                 "focusOnly": false, "pausedUntilMs": null},
                {"id": "b", "name": "B", "packageName": "p", "mode": "unknownMode"},
                {"name": "no id", "packageName": "p", "mode": "pauseScreen"}
              ],
              "focus": {"id": "f", "startedAtMs": 1, "plannedEndAtMs": 2,
                        "activeRuleIds": ["a"], "completed": false, "endedAtMs": null},
              "snoozeMinutes": 15,
              "pauseSeconds": 3,
              "pauseMessage": null
            }
        """.trimIndent()
        val config = ConfigParser.parseConfig(json)
        assertEquals(1, config.rules.size)
        val rule = config.rules.single()
        assertEquals(BlockMode.APP_LIMIT, rule.mode)
        assertEquals(30, rule.dailyLimitMinutes)
        assertEquals(listOf(1, 2), rule.activeWeekdays)
        assertEquals(480, rule.startMinute)
        assertEquals(750, rule.endMinute)
        assertNull(rule.pausedUntilMs)
        assertEquals("f", config.focus?.id)
        assertEquals(listOf("a"), config.focus?.activeRuleIds)
        assertEquals(15, config.snoozeMinutes)
        assertEquals(3, config.pauseSeconds)
        assertNull(config.pauseMessage)
        assertEquals(setOf("p"), config.packages)
    }

    @Test
    fun invalidDocumentsFallBackToEmpty() {
        assertTrue(ConfigParser.parseConfig(null).rules.isEmpty())
        assertTrue(ConfigParser.parseConfig("not json").rules.isEmpty())
        assertTrue(ConfigParser.parseConfig("{}").rules.isEmpty())
    }

    @Test
    fun everyDartModeHasANativeMode() {
        // Must match BlockMode in lib/data/models/block_rule.dart.
        val dartModes = listOf(
            "appLimit",
            "scheduledBlock",
            "selectiveFeed",
            "pauseScreen",
            "allowException",
        )
        dartModes.forEach { assertEquals(it, BlockMode.fromJson(it)?.jsonName) }
    }

    @Test
    fun selectiveFeedFlag() {
        val config = OpenBlockConfig(
            rules = listOf(
                BlockRule("a", "A", "p", BlockMode.SELECTIVE_FEED, enabled = false),
            ),
        )
        assertEquals(false, config.hasSelectiveFeedRules)
        val enabled = config.copy(rules = config.rules.map { it.copy(enabled = true) })
        assertEquals(true, enabled.hasSelectiveFeedRules)
    }
}
