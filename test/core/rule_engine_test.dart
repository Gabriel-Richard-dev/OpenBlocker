import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/core/rule_engine.dart';
import 'package:openblock/core/time_utils.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/models/focus_session.dart';

BlockRule rule({
  String id = 'r',
  BlockMode mode = BlockMode.scheduledBlock,
  List<int> weekdays = const [],
  String? start,
  String? end,
  bool focusOnly = false,
}) => BlockRule(
  id: id,
  name: id,
  packageName: 'app',
  mode: mode,
  activeWeekdays: weekdays,
  startTime: start,
  endTime: end,
  focusOnly: focusOnly,
);

void main() {
  group('time helpers', () {
    test('parseHm accepts valid times and rejects invalid ones', () {
      expect(parseHm('00:00'), 0);
      expect(parseHm('09:30'), 570);
      expect(parseHm('23:59'), 1439);
      expect(parseHm('24:00'), isNull);
      expect(parseHm('12:60'), isNull);
      expect(parseHm('9:30'), isNull);
      expect(parseHm(null), isNull);
    });

    test('formatHm round-trips and wraps', () {
      expect(formatHm(570), '09:30');
      expect(formatHm(minutesPerDay + 5), '00:05');
      for (var m = 0; m < minutesPerDay; m += 37) {
        expect(parseHm(formatHm(m)), m);
      }
    });

    test('previousWeekday wraps Monday to Sunday', () {
      expect(previousWeekday(1), 7);
      expect(previousWeekday(7), 6);
    });
  });

  group('scheduleMatches', () {
    test('no window and no weekdays means always', () {
      for (var day = 1; day <= 7; day++) {
        expect(RuleEngine.scheduleMatches(rule(), day, 0), isTrue);
      }
    });

    test('daytime window checks weekday and time', () {
      final r = rule(weekdays: [1], start: '09:00', end: '10:00');
      expect(RuleEngine.scheduleMatches(r, 1, 9 * 60), isTrue);
      expect(RuleEngine.scheduleMatches(r, 1, 10 * 60), isFalse);
      expect(RuleEngine.scheduleMatches(r, 2, 9 * 60 + 30), isFalse);
    });

    test('overnight window spills into the next day', () {
      final r = rule(weekdays: [7], start: '23:00', end: '01:00');
      expect(RuleEngine.scheduleMatches(r, 7, 23 * 60 + 30), isTrue);
      expect(RuleEngine.scheduleMatches(r, 1, 30), isTrue); // Monday 00:30
      expect(RuleEngine.scheduleMatches(r, 1, 23 * 60 + 30), isFalse);
    });
  });

  group('activation', () {
    final now = DateTime(2026, 10, 28, 12);
    EvaluationContext ctx({FocusSession? focus, Map<String, int>? snoozes}) =>
        EvaluationContext.at(
          now,
          packageName: 'app',
          focus: focus,
          snoozes: snoozes ?? const {},
        );

    test('reports why a rule is inactive', () {
      expect(
        RuleEngine.activation(rule().copyWith(enabled: false), ctx()),
        RuleActivation.disabled,
      );
      expect(
        RuleEngine.activation(
          rule(),
          ctx(snoozes: {'r': now.millisecondsSinceEpoch + 1}),
        ),
        RuleActivation.paused,
      );
      expect(
        RuleEngine.activation(rule(focusOnly: true), ctx()),
        RuleActivation.focusOnlyIdle,
      );
      expect(
        RuleEngine.activation(rule(weekdays: [1]), ctx()),
        RuleActivation.outsideSchedule,
      );
      expect(RuleEngine.activation(rule(), ctx()), RuleActivation.active);
    });

    test('focus session activates included rules', () {
      final session = FocusSession(
        id: 'f',
        startedAt: now.subtract(const Duration(minutes: 5)),
        plannedEndAt: now.add(const Duration(minutes: 20)),
        activeRuleIds: const ['r'],
      );
      expect(
        RuleEngine.activation(rule(focusOnly: true), ctx(focus: session)),
        RuleActivation.activeByFocus,
      );
      expect(
        RuleEngine.activation(
          rule(focusOnly: true),
          ctx(focus: session.finish(now)),
        ),
        RuleActivation.focusOnlyIdle,
      );
    });

    test('EvaluationContext.at derives local weekday and minute', () {
      final c = EvaluationContext.at(
        DateTime(2026, 10, 31, 7, 45),
        packageName: 'app',
      );
      expect(c.weekday, DateTime.saturday);
      expect(c.minuteOfDay, 7 * 60 + 45);
    });
  });
}
