import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/app/version.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/models/focus_session.dart';
import 'package:openblock/data/models/platform_models.dart';
import 'package:openblock/features/home/protection_status.dart';
import 'package:openblock/features/statistics/statistics.dart';

const block = BlockRule(
  id: 'b',
  name: 'b',
  packageName: 'p',
  mode: BlockMode.scheduledBlock,
);
const limit = BlockRule(
  id: 'l',
  name: 'l',
  packageName: 'p',
  mode: BlockMode.appLimit,
  dailyLimitMinutes: 30,
);

PermissionSnapshot perms({
  bool enabled = true,
  bool running = true,
  bool usage = true,
}) => PermissionSnapshot(
  platformSupported: true,
  accessibilityEnabled: enabled,
  accessibilityRunning: running,
  usageAccessGranted: usage,
);

void main() {
  group('ProtectionStatus', () {
    test('no enabled rules', () {
      expect(
        ProtectionStatus.compute([], perms()).level,
        ProtectionLevel.noRules,
      );
      expect(
        ProtectionStatus.compute([
          block.copyWith(enabled: false),
        ], perms()).level,
        ProtectionLevel.noRules,
      );
    });

    test('working when everything is granted', () {
      expect(
        ProtectionStatus.compute([block, limit], perms()).level,
        ProtectionLevel.working,
      );
    });

    test('not working when accessibility is off or stopped', () {
      final off = ProtectionStatus.compute([block], perms(enabled: false));
      expect(off.level, ProtectionLevel.notWorking);
      expect(off.issues, [ProtectionIssue.accessibilityOff]);

      final stopped = ProtectionStatus.compute([block], perms(running: false));
      expect(stopped.level, ProtectionLevel.notWorking);
      expect(stopped.issues, [ProtectionIssue.accessibilityStopped]);
    });

    test('partial when limits cannot be measured', () {
      final status = ProtectionStatus.compute([
        block,
        limit,
      ], perms(usage: false));
      expect(status.level, ProtectionLevel.partial);
      expect(status.issues, [ProtectionIssue.usageAccessMissing]);
      // Usage access is irrelevant without limit rules.
      expect(
        ProtectionStatus.compute([block], perms(usage: false)).level,
        ProtectionLevel.working,
      );
    });

    test('unsupported platform and unknown state', () {
      expect(
        ProtectionStatus.compute([
          block,
        ], PermissionSnapshot.unsupported).issues,
        [ProtectionIssue.unsupportedPlatform],
      );
      expect(
        ProtectionStatus.compute([block], null).level,
        ProtectionLevel.unknown,
      );
    });
  });

  group('statistics helpers', () {
    final today = DateTime(2026, 10, 28, 15);
    final days = lastDays(today, 7);

    test('lastDays returns local midnights ending today', () {
      expect(days, hasLength(7));
      expect(days.last, DateTime(2026, 10, 28));
      expect(days.first, DateTime(2026, 10, 22));
    });

    test('lastDays crosses month boundaries', () {
      final d = lastDays(DateTime(2026, 3, 2), 3);
      expect(d, [
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 2),
      ]);
    });

    test('interventions are counted per day and per rule', () {
      InterventionEvent event(DateTime at, String rule) => InterventionEvent(
        at: at,
        ruleId: rule,
        packageName: 'p',
        kind: InterventionKind.block,
      );
      final events = [
        event(DateTime(2026, 10, 28, 9), 'a'),
        event(DateTime(2026, 10, 28, 23, 59), 'a'),
        event(DateTime(2026, 10, 27, 1), 'b'),
        event(DateTime(2026, 10, 1), 'b'),
      ];
      expect(interventionsPerDay(events, days), [0, 0, 0, 0, 0, 1, 2]);
      expect(interventionsByRule(events).first.key, 'a');
    });

    test('focus minutes and completed sessions', () {
      FocusSession session(DateTime start, int minutes, {bool done = true}) {
        final s = FocusSession(
          id: '$start',
          startedAt: start,
          plannedEndAt: start.add(Duration(minutes: minutes)),
          activeRuleIds: const [],
        );
        return done ? s.finish(s.plannedEndAt) : s;
      }

      final sessions = [
        session(DateTime(2026, 10, 28, 9), 25),
        session(DateTime(2026, 10, 28, 11), 45),
        session(DateTime(2026, 10, 26, 9), 60),
        session(DateTime(2026, 10, 28, 14, 50), 60, done: false),
      ];
      final minutes = focusMinutesPerDay(sessions, days, today);
      expect(minutes.last, 25 + 45 + 10);
      expect(minutes[4], 60);
      expect(completedSessionsSince(sessions, days.first), 3);
    });
  });

  test('app version matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9.]+)\+',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match?.group(1), appVersion);
  });
}
