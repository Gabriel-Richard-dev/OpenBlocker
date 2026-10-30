import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/app/config_sync.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/models/platform_models.dart';
import 'package:openblock/data/providers.dart';
import 'package:openblock/data/storage/key_value_store.dart';
import 'package:openblock/features/focus/focus_controller.dart';
import 'package:openblock/features/rules/rules_controller.dart';
import 'package:openblock/features/settings/settings_controller.dart';

import '../helpers/fakes.dart';

const rule = BlockRule(
  id: 'r1',
  name: 'Block YouTube',
  packageName: 'com.google.android.youtube',
  mode: BlockMode.scheduledBlock,
);

void main() {
  group('RulesController', () {
    test('create, edit and delete persist across restarts', () async {
      final store = MemoryStore();
      var container = await makeContainer(store: store);
      final rules = container.read(rulesProvider.notifier);

      rules.upsert(rule);
      rules.upsert(rule.copyWith(name: 'Renamed'));
      expect(container.read(rulesProvider).single.name, 'Renamed');
      await pumpEventQueue();

      // "Close and reopen" the app with the same storage.
      container.dispose();
      container = await makeContainer(store: store);
      expect(container.read(rulesProvider).single.name, 'Renamed');

      container.read(rulesProvider.notifier).remove('r1');
      await pumpEventQueue();
      container.dispose();
      container = await makeContainer(store: store);
      expect(container.read(rulesProvider), isEmpty);
    });

    test('rejects invalid rules', () async {
      final container = await makeContainer();
      expect(
        () => container
            .read(rulesProvider.notifier)
            .upsert(rule.copyWith(name: '')),
        throwsA(isA<InvalidRuleException>()),
      );
      expect(container.read(rulesProvider), isEmpty);
    });

    test('addAll skips invalid rules', () async {
      final container = await makeContainer();
      final added = container.read(rulesProvider.notifier).addAll([
        rule,
        rule.copyWith(id: 'bad', packageName: ''),
      ]);
      expect(added, 1);
    });

    test('pause, resume and toggle', () async {
      final platform = FakePlatform();
      final container = await makeContainer(platform: platform);
      final rules = container.read(rulesProvider.notifier)..upsert(rule);
      rules.pauseUntil('r1', DateTime(2030));
      expect(container.read(rulesProvider).single.pausedUntilMs, isNotNull);
      rules.resume('r1');
      expect(container.read(rulesProvider).single.pausedUntilMs, isNull);
      expect(platform.clearedSnoozes, ['r1']);
      rules.setEnabled('r1', false);
      expect(container.read(rulesProvider).single.enabled, isFalse);
    });
  });

  group('FocusController', () {
    test('start, stop and history', () async {
      final clock = TestClock(DateTime(2026, 10, 28, 10));
      final container = await makeContainer(clock: clock);
      final focus = container.read(focusProvider.notifier);

      final session = focus.start(
        duration: const Duration(minutes: 25),
        ruleIds: const ['r1'],
      );
      expect(focus.activeSession?.id, session.id);

      clock.advance(const Duration(minutes: 10));
      focus.stop();
      final state = container.read(focusProvider);
      expect(state.active, isNull);
      expect(state.history.single.completed, isFalse);
      expect(
        state.history.single.elapsedAt(clock.now),
        const Duration(minutes: 10),
      );
    });

    test('reconcile completes a session that reached its end', () async {
      final clock = TestClock(DateTime(2026, 10, 28, 10));
      final container = await makeContainer(clock: clock);
      final focus = container.read(focusProvider.notifier)
        ..start(duration: const Duration(minutes: 25), ruleIds: const []);
      clock.advance(const Duration(minutes: 30));
      focus.reconcile();
      final state = container.read(focusProvider);
      expect(state.active, isNull);
      expect(state.history.single.completed, isTrue);
    });

    test(
      'a session survives a restart and completes if it expired meanwhile',
      () async {
        final store = MemoryStore();
        final clock = TestClock(DateTime(2026, 10, 28, 10));
        var container = await makeContainer(store: store, clock: clock);
        container
            .read(focusProvider.notifier)
            .start(duration: const Duration(minutes: 25), ruleIds: const []);
        await pumpEventQueue();
        container.dispose();

        clock.advance(const Duration(minutes: 5));
        container = await makeContainer(store: store, clock: clock);
        expect(container.read(focusProvider).active, isNotNull);
        container.dispose();

        // Device was off past the planned end.
        clock.advance(const Duration(hours: 3));
        container = await makeContainer(store: store, clock: clock);
        final state = container.read(focusProvider);
        expect(state.active, isNull);
        expect(state.history.single.completed, isTrue);
      },
    );

    test('applies an early end from the native intervention screen', () async {
      final clock = TestClock(DateTime(2026, 10, 28, 10));
      final container = await makeContainer(clock: clock);
      final session = container
          .read(focusProvider.notifier)
          .start(duration: const Duration(minutes: 25), ruleIds: const []);
      container
          .read(focusProvider.notifier)
          .applyRuntime(
            RuntimeState(
              endedFocusId: session.id,
              endedFocusAtMs: clock.now
                  .add(const Duration(minutes: 3))
                  .millisecondsSinceEpoch,
            ),
          );
      final finished = container.read(focusProvider).history.single;
      expect(finished.completed, isFalse);
      expect(
        finished.elapsedAt(clock.now.add(const Duration(hours: 1))),
        const Duration(minutes: 3),
      );
    });

    test('ignores early ends for other sessions', () async {
      final container = await makeContainer();
      container
          .read(focusProvider.notifier)
          .start(duration: const Duration(minutes: 25), ruleIds: const []);
      container
          .read(focusProvider.notifier)
          .applyRuntime(
            const RuntimeState(endedFocusId: 'other', endedFocusAtMs: 1),
          );
      expect(container.read(focusProvider).active, isNotNull);
    });

    test('rejects non-positive durations', () async {
      final container = await makeContainer();
      expect(
        () => container
            .read(focusProvider.notifier)
            .start(duration: Duration.zero, ruleIds: const []),
        throwsArgumentError,
      );
    });
  });

  group('SettingsController', () {
    test('clamps values and resets', () async {
      final container = await makeContainer();
      final settings = container.read(settingsProvider.notifier)
        ..setPauseSeconds(-3)
        ..setPauseMessage('   ');
      expect(container.read(settingsProvider).pauseSeconds, 0);
      expect(container.read(settingsProvider).pauseMessage, isNull);
      settings.completeOnboarding();
      expect(container.read(settingsProvider).onboardingCompleted, isTrue);
      settings.reset();
      expect(container.read(settingsProvider).onboardingCompleted, isFalse);
    });
  });

  group('config sync', () {
    test('pushes rules, focus and settings to the native side', () async {
      final platform = FakePlatform();
      final container = await makeContainer(platform: platform);
      container.listen(configSyncProvider, (_, _) {});
      expect(platform.lastConfig?['rules'], isEmpty);

      container.read(rulesProvider.notifier).upsert(rule);
      final rules = platform.lastConfig!['rules']! as List<Object?>;
      expect((rules.single! as Map<String, Object?>)['id'], 'r1');

      final session = container
          .read(focusProvider.notifier)
          .start(duration: const Duration(minutes: 25), ruleIds: const ['r1']);
      final focus = platform.lastConfig!['focus']! as Map<String, Object?>;
      expect(focus['id'], session.id);
      expect(focus['activeRuleIds'], ['r1']);

      final settings = container.read(settingsProvider.notifier)
        ..removeBankPackage('com.nu.production')
        ..addBankPackage('com.example.bank');
      final banks = platform.lastConfig!['bankPackages']! as List<Object?>;
      expect(banks, isNot(contains('com.nu.production')));
      expect(banks.last, 'com.example.bank');
      settings.setBankGuardEnabled(false);
      expect(platform.lastConfig!['bankPackages'], isEmpty);
      expect(platform.lastConfig!['version'], nativeConfigVersion);
    });

    test('does not resend identical configs', () async {
      final platform = FakePlatform();
      final container = await makeContainer(platform: platform);
      container.listen(configSyncProvider, (_, _) {});
      final count = platform.syncedConfigs.length;
      container.read(settingsProvider.notifier).completeOnboarding();
      expect(platform.syncedConfigs.length, count);
    });
  });

  test('permissions provider reflects revoked permissions', () async {
    final platform = FakePlatform();
    final container = await makeContainer(platform: platform);
    expect(
      (await container.read(permissionsProvider.future)).accessibilityEnabled,
      isTrue,
    );
    platform.permissions = const PermissionSnapshot(
      platformSupported: true,
      accessibilityEnabled: false,
      accessibilityRunning: false,
      usageAccessGranted: false,
    );
    container.invalidate(permissionsProvider);
    expect(
      (await container.read(permissionsProvider.future)).accessibilityEnabled,
      isFalse,
    );
  });
}
