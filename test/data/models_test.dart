import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/data/backup.dart';
import 'package:openblock/data/models/app_settings.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/models/focus_session.dart';
import 'package:openblock/data/models/platform_models.dart';

void main() {
  const rule = BlockRule(
    id: 'r1',
    name: 'Shorts',
    packageName: 'com.google.android.youtube',
    appLabel: 'YouTube',
    mode: BlockMode.selectiveFeed,
    activeWeekdays: [1, 2],
    startTime: '08:00',
    endTime: '12:00',
    feedTargets: ['youtube.shorts'],
    focusOnly: true,
    pausedUntilMs: 42,
  );

  group('BlockRule', () {
    test('JSON round-trip keeps every field', () {
      final decoded = BlockRule.fromJson(
        jsonDecode(jsonEncode(rule.toJson())) as Map<String, Object?>,
      );
      expect(decoded, rule);
      expect(decoded.hashCode, rule.hashCode);
    });

    test('copyWith can clear nullable fields', () {
      final cleared = rule.copyWith(
        startTime: null,
        endTime: null,
        pausedUntilMs: null,
      );
      expect(cleared.startTime, isNull);
      expect(cleared.hasTimeWindow, isFalse);
      expect(cleared.pausedUntilMs, isNull);
      expect(rule.copyWith().startTime, '08:00');
    });

    test('unknown mode is rejected', () {
      expect(
        () => BlockRule.fromJson({...rule.toJson(), 'mode': 'somethingElse'}),
        throwsFormatException,
      );
    });

    test('isPausedAt compares against epoch ms', () {
      expect(rule.isPausedAt(41), isTrue);
      expect(rule.isPausedAt(42), isFalse);
    });
  });

  group('FocusSession', () {
    final start = DateTime(2026, 10, 28, 10);
    final session = FocusSession(
      id: 'f',
      startedAt: start,
      plannedEndAt: start.add(const Duration(minutes: 25)),
      activeRuleIds: const ['r1'],
    );

    test('durations and progress', () {
      final now = start.add(const Duration(minutes: 10));
      expect(session.isActiveAt(now), isTrue);
      expect(session.remainingAt(now), const Duration(minutes: 15));
      expect(session.elapsedAt(now), const Duration(minutes: 10));
      expect(session.progressAt(now), closeTo(0.4, 1e-9));
    });

    test('elapsed time is clamped before start and after end', () {
      expect(
        session.elapsedAt(start.subtract(const Duration(hours: 1))),
        Duration.zero,
      );
      expect(
        session.elapsedAt(start.add(const Duration(hours: 5))),
        const Duration(minutes: 25),
      );
      expect(
        session.remainingAt(start.add(const Duration(hours: 5))),
        Duration.zero,
      );
    });

    test('finishing early is not completed; at planned end it is', () {
      final early = session.finish(start.add(const Duration(minutes: 5)));
      expect(early.completed, isFalse);
      expect(early.elapsedAt(DateTime(2030)), const Duration(minutes: 5));
      expect(early.isActiveAt(start.add(const Duration(minutes: 6))), isFalse);

      final late = session.finish(start.add(const Duration(hours: 2)));
      expect(late.completed, isTrue);
      expect(late.endedAt, session.plannedEndAt);
    });

    test('JSON uses epoch milliseconds and survives time zone changes', () {
      final json = session.toJson();
      expect(json['startedAtMs'], start.millisecondsSinceEpoch);
      final decoded = FocusSession.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, Object?>,
      );
      expect(
        decoded.startedAt.millisecondsSinceEpoch,
        start.millisecondsSinceEpoch,
      );
      expect(decoded.plannedDuration, session.plannedDuration);
    });
  });

  test('AppSettings JSON round-trip and defaults', () {
    const settings = AppSettings(
      onboardingCompleted: true,
      themeMode: ThemeMode.dark,
      snoozeMinutes: 10,
      pauseSeconds: 20,
      pauseMessage: 'Breathe',
      defaultFocusMinutes: 45,
    );
    expect(AppSettings.fromJson(settings.toJson()), settings);
    expect(AppSettings.fromJson(const {}), const AppSettings());
    expect(settings.copyWith(clearPauseMessage: true).pauseMessage, isNull);
  });

  group('platform models', () {
    test('PermissionSnapshot derives stopped state', () {
      final snapshot = PermissionSnapshot.fromMap(const {
        'accessibilityEnabled': true,
        'accessibilityRunning': false,
        'usageAccessGranted': false,
        'sdkInt': 34,
      });
      expect(snapshot.accessibilityStopped, isTrue);
      expect(snapshot.mayNeedRestrictedSettings, isTrue);
      expect(PermissionSnapshot.unsupported.platformSupported, isFalse);
    });

    test('RuntimeState parses channel maps', () {
      final state = RuntimeState.fromMap(const {
        'snoozes': {'r1': 99},
        'endedFocusId': 'f',
        'endedFocusAtMs': 5,
        'events': [
          {'atMs': 1, 'ruleId': 'r1', 'packageName': 'p', 'kind': 'feed'},
          {'atMs': 2, 'ruleId': 'r1', 'packageName': 'p', 'kind': 'weird'},
        ],
      });
      expect(state.snoozes, {'r1': 99});
      expect(state.endedFocusId, 'f');
      expect(state.events.first.kind, InterventionKind.feed);
      expect(state.events.last.kind, InterventionKind.block);
    });

    test('DailyUsage parses dates and totals', () {
      final usage = DailyUsage.fromMap(const {
        'date': '2026-10-28',
        'usage': {'a': 10, 'b': 5},
      });
      expect(usage.day, DateTime(2026, 10, 28));
      expect(usage.totalMinutes, 15);
    });
  });

  group('Backup', () {
    test('round-trip keeps rules and settings but not onboarding', () {
      const backup = Backup(
        settings: AppSettings(onboardingCompleted: true, snoozeMinutes: 15),
        rules: [rule],
      );
      final decoded = Backup.decode(backup.encode());
      expect(decoded.rules, [rule]);
      expect(decoded.settings.snoozeMinutes, 15);
      expect(decoded.settings.onboardingCompleted, isFalse);
    });

    test('rejects other documents', () {
      expect(() => Backup.decode('nope'), throwsFormatException);
      expect(() => Backup.decode('{"format":"x"}'), throwsFormatException);
      expect(
        () => Backup.decode('{"format":"openblock-backup","version":99}'),
        throwsFormatException,
      );
    });

    test('drops invalid rules', () {
      final text = jsonEncode({
        'format': Backup.format,
        'version': 1,
        'rules': [
          rule.toJson(),
          {...rule.toJson(), 'name': ''},
          {'garbage': true},
        ],
      });
      expect(Backup.decode(text).rules, [rule]);
    });
  });
}
