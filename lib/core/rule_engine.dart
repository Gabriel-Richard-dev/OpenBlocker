/// Pure rule evaluation shared by the UI and the test suite.
///
/// The native Android service has a Kotlin port of this file
/// (`android/.../engine/RuleEngine.kt`). Both implementations are checked
/// against the same test vectors in `test/fixtures/rule_engine_vectors.json`;
/// update the vectors whenever the behaviour changes.
///
/// Precedence (see docs/rule-precedence.md):
///  1. Disabled, temporarily paused or snoozed rules are ignored.
///  2. An active exception (`allowException`) for the app wins over everything.
///  3. A whole-app block: `scheduledBlock` first, then an exceeded
///     `appLimit`. Ties are broken by rule order.
///  4. `selectiveFeed`: blocks the union of the active rules' feed targets.
///  5. `pauseScreen`.
library;

import '../data/models/block_rule.dart';
import '../data/models/focus_session.dart';
import 'time_utils.dart';

enum DecisionAction { none, pause, blockFeed, blockApp }

enum DecisionReason { noRule, exception, scheduled, focus, limit, feed, pause }

/// Why a rule is or is not active right now.
enum RuleActivation {
  disabled,
  paused,
  focusOnlyIdle,
  outsideSchedule,
  active,
  activeByFocus;

  bool get isActive => this == active || this == activeByFocus;
}

class Decision {
  const Decision({
    required this.action,
    required this.reason,
    this.ruleId,
    this.feedTargets = const [],
  });

  static const Decision allow = Decision(
    action: DecisionAction.none,
    reason: DecisionReason.noRule,
  );

  final DecisionAction action;
  final DecisionReason reason;
  final String? ruleId;
  final List<String> feedTargets;

  @override
  String toString() =>
      'Decision(${action.name}, ${reason.name}, $ruleId, $feedTargets)';
}

class EvaluationContext {
  const EvaluationContext({
    required this.packageName,
    required this.nowMs,
    required this.weekday,
    required this.minuteOfDay,
    this.usageMinutes,
    this.focus,
    this.snoozes = const {},
  });

  factory EvaluationContext.at(
    DateTime now, {
    required String packageName,
    int? usageMinutes,
    FocusSession? focus,
    Map<String, int> snoozes = const {},
  }) {
    final local = now.toLocal();
    return EvaluationContext(
      packageName: packageName,
      nowMs: now.millisecondsSinceEpoch,
      weekday: local.weekday,
      minuteOfDay: local.hour * 60 + local.minute,
      usageMinutes: usageMinutes,
      focus: focus,
      snoozes: snoozes,
    );
  }

  final String packageName;
  final int nowMs;

  /// ISO weekday in local time (1 = Monday).
  final int weekday;

  /// Minutes since local midnight.
  final int minuteOfDay;

  /// Measured foreground minutes today, or `null` when unknown (for example
  /// when usage access was not granted). Limits are not enforced when unknown.
  final int? usageMinutes;
  final FocusSession? focus;

  /// Rule id → UTC epoch ms until which the rule is snoozed from the pause or
  /// block screen.
  final Map<String, int> snoozes;
}

abstract final class RuleEngine {
  static bool weekdayMatches(List<int> weekdays, int weekday) =>
      weekdays.isEmpty || weekdays.contains(weekday);

  /// Whether the rule's weekly schedule covers [weekday] at [minuteOfDay].
  static bool scheduleMatches(BlockRule rule, int weekday, int minuteOfDay) {
    final start = rule.startMinute;
    final end = rule.endMinute;
    if (start == null || end == null || start == end) {
      return weekdayMatches(rule.activeWeekdays, weekday);
    }
    if (start < end) {
      return weekdayMatches(rule.activeWeekdays, weekday) &&
          minuteOfDay >= start &&
          minuteOfDay < end;
    }
    // Overnight window, e.g. 22:00–06:00. The weekday refers to the day on
    // which the window starts.
    if (minuteOfDay >= start) {
      return weekdayMatches(rule.activeWeekdays, weekday);
    }
    if (minuteOfDay < end) {
      return weekdayMatches(rule.activeWeekdays, previousWeekday(weekday));
    }
    return false;
  }

  static bool isFocusActive(FocusSession? focus, int nowMs) {
    if (focus == null || focus.endedAt != null) return false;
    return nowMs >= focus.startedAt.millisecondsSinceEpoch &&
        nowMs < focus.plannedEndAt.millisecondsSinceEpoch;
  }

  static RuleActivation activation(BlockRule rule, EvaluationContext ctx) {
    if (!rule.enabled) return RuleActivation.disabled;
    final snoozedUntil = ctx.snoozes[rule.id];
    if (rule.isPausedAt(ctx.nowMs) ||
        (snoozedUntil != null && snoozedUntil > ctx.nowMs)) {
      return RuleActivation.paused;
    }
    final inFocus =
        isFocusActive(ctx.focus, ctx.nowMs) &&
        ctx.focus!.activeRuleIds.contains(rule.id);
    if (rule.focusOnly) {
      return inFocus
          ? RuleActivation.activeByFocus
          : RuleActivation.focusOnlyIdle;
    }
    if (inFocus) return RuleActivation.activeByFocus;
    return scheduleMatches(rule, ctx.weekday, ctx.minuteOfDay)
        ? RuleActivation.active
        : RuleActivation.outsideSchedule;
  }

  static bool limitReached(BlockRule rule, int? usageMinutes) {
    final limit = rule.dailyLimitMinutes;
    return limit != null && usageMinutes != null && usageMinutes >= limit;
  }

  static Decision evaluate(List<BlockRule> rules, EvaluationContext ctx) {
    final active = <(BlockRule, RuleActivation)>[];
    for (final rule in rules) {
      if (rule.packageName != ctx.packageName) continue;
      final state = activation(rule, ctx);
      if (state.isActive) active.add((rule, state));
    }
    if (active.isEmpty) return Decision.allow;

    for (final (rule, _) in active) {
      if (rule.mode == BlockMode.allowException) {
        return Decision(
          action: DecisionAction.none,
          reason: DecisionReason.exception,
          ruleId: rule.id,
        );
      }
    }

    for (final (rule, state) in active) {
      if (rule.mode == BlockMode.scheduledBlock) {
        return Decision(
          action: DecisionAction.blockApp,
          reason: state == RuleActivation.activeByFocus
              ? DecisionReason.focus
              : DecisionReason.scheduled,
          ruleId: rule.id,
        );
      }
    }

    for (final (rule, _) in active) {
      if (rule.mode == BlockMode.appLimit &&
          limitReached(rule, ctx.usageMinutes)) {
        return Decision(
          action: DecisionAction.blockApp,
          reason: DecisionReason.limit,
          ruleId: rule.id,
        );
      }
    }

    String? feedRuleId;
    final targets = <String>[];
    for (final (rule, _) in active) {
      if (rule.mode != BlockMode.selectiveFeed) continue;
      feedRuleId ??= rule.id;
      for (final target in rule.feedTargets) {
        if (!targets.contains(target)) targets.add(target);
      }
    }
    if (feedRuleId != null && targets.isNotEmpty) {
      return Decision(
        action: DecisionAction.blockFeed,
        reason: DecisionReason.feed,
        ruleId: feedRuleId,
        feedTargets: targets,
      );
    }

    for (final (rule, _) in active) {
      if (rule.mode == BlockMode.pauseScreen) {
        return Decision(
          action: DecisionAction.pause,
          reason: DecisionReason.pause,
          ruleId: rule.id,
        );
      }
    }

    return Decision.allow;
  }
}
