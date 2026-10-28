import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/models/platform_models.dart';
import 'package:openblock/data/repositories/rules_repository.dart';
import 'package:openblock/data/storage/key_value_store.dart';
import 'package:openblock/features/rules/rule_editor_screen.dart';

import '../helpers/fakes.dart';

const youtubeRule = BlockRule(
  id: 'r1',
  name: 'No YouTube',
  packageName: 'com.google.android.youtube',
  appLabel: 'YouTube',
  mode: BlockMode.scheduledBlock,
);

Finder editorScrollable() => find
    .descendant(
      of: find.byType(RuleEditorScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding explains permissions and can be completed', (
    tester,
  ) async {
    final store = MemoryStore();
    final platform = FakePlatform();
    await pumpApp(tester, store: store, platform: platform, onboarded: false);

    expect(find.text('Take back your attention'), findsOneWidget);
    final next = find.byKey(const Key('onboardingNext'));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Permissions you grant'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('What OpenBlock can see'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('You stay in control'), findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Set up permissions'), findsOneWidget);

    // Permission buttons only open system settings.
    await tester.tap(find.text('Open system settings').first);
    expect(platform.openedSettings, ['accessibility']);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      store.values['openblock.settings'],
      contains('"onboardingCompleted":true'),
    );
  });

  testWidgets('create, edit and delete a rule from the UI', (tester) async {
    final store = MemoryStore();
    await pumpApp(tester, store: store);
    await openTab(tester, 'Rules');
    expect(find.text('No rules yet'), findsOneWidget);

    await tester.tap(find.text('New rule'));
    await tester.pumpAndSettle();

    // Saving without an app shows validation errors.
    await tester.tap(find.byKey(const Key('saveRule')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Choose an app.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pickApp')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const Key('mode-appLimit')));
    expect(find.text('Daily limit'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('45 min'),
      200,
      scrollable: editorScrollable(),
    );
    await tapVisible(tester, find.text('45 min'));

    await tester.tap(find.byKey(const Key('saveRule')));
    await tester.pumpAndSettle();

    expect(find.text('YouTube · Daily limit'), findsOneWidget);
    var saved = RulesRepository.decode(
      store.values[RulesRepository.storageKey]!,
    );
    expect(saved.single.mode, BlockMode.appLimit);
    expect(saved.single.dailyLimitMinutes, 45);

    // Edit the name.
    await tester.tap(find.text('YouTube · Daily limit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ruleName')), 'Less YouTube');
    await tester.tap(find.byKey(const Key('saveRule')));
    await tester.pumpAndSettle();
    expect(find.text('Less YouTube'), findsOneWidget);
    saved = RulesRepository.decode(store.values[RulesRepository.storageKey]!);
    expect(saved.single.name, 'Less YouTube');

    // Delete it.
    await tester.tap(find.text('Less YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Less YouTube'), findsNothing);
    expect(
      RulesRepository.decode(store.values[RulesRepository.storageKey]!),
      isEmpty,
    );
  });

  testWidgets('selective feed is offered only for supported apps', (
    tester,
  ) async {
    await pumpApp(tester, store: MemoryStore());
    await openTab(tester, 'Rules');
    await tester.tap(find.text('New rule'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pickApp')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wikipedia'));
    await tester.pumpAndSettle();
    expect(find.text('Not available for this app.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pickApp')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();
    expect(find.text('Not available for this app.'), findsNothing);
    await tapVisible(tester, find.byKey(const Key('mode-selectiveFeed')));
    await tester.scrollUntilVisible(
      find.text('YouTube Shorts'),
      200,
      scrollable: editorScrollable(),
    );
    expect(find.text('YouTube Shorts'), findsOneWidget);
    expect(find.text('Experimental'), findsOneWidget);
  });

  testWidgets('applying a preset creates rules for installed apps', (
    tester,
  ) async {
    final store = MemoryStore();
    await pumpApp(tester, store: store);
    await openTab(tester, 'Rules');
    await tester.tap(find.text('No Shorts'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Supported on: Android'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    final saved = RulesRepository.decode(
      store.values[RulesRepository.storageKey]!,
    );
    expect(saved.map((rule) => rule.packageName), [
      'com.google.android.youtube',
      'com.instagram.android',
    ]);
    expect(saved.every((rule) => rule.mode == BlockMode.selectiveFeed), isTrue);
  });

  testWidgets('a focus session can be started and ended', (tester) async {
    final store = MemoryStore({
      RulesRepository.storageKey: RulesRepository.encode([youtubeRule]),
    });
    final platform = FakePlatform();
    await pumpApp(tester, store: store, platform: platform);

    await tester.tap(find.byKey(const Key('focus-25')));
    await tester.pumpAndSettle();
    expect(find.text('No YouTube'), findsOneWidget);
    await tester.tap(find.byKey(const Key('startFocus')));
    await tester.pump();

    expect(find.text('Focus session in progress'), findsOneWidget);
    expect(find.byKey(const Key('focusCountdown')), findsOneWidget);
    final focus = platform.lastConfig!['focus']! as Map<String, Object?>;
    expect(focus['activeRuleIds'], ['r1']);

    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('endFocus')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'End session'));
    await tester.pumpAndSettle();

    expect(find.text('Focus session in progress'), findsNothing);
    expect(platform.lastConfig!['focus'], isNull);
    expect(
      store.values['openblock.focus.history'],
      contains('"completed":false'),
    );
  });

  testWidgets('home shows when blocking is not working', (tester) async {
    final store = MemoryStore({
      RulesRepository.storageKey: RulesRepository.encode([youtubeRule]),
    });
    final platform = FakePlatform(
      permissions: const PermissionSnapshot(
        platformSupported: true,
        accessibilityEnabled: true,
        accessibilityRunning: false,
        usageAccessGranted: true,
      ),
    );
    await pumpApp(tester, store: store, platform: platform);
    expect(find.text('Blocking is not working'), findsOneWidget);
    expect(find.textContaining('Android is not running it'), findsOneWidget);

    // The user fixes it in system settings and comes back.
    platform.permissions = const PermissionSnapshot(
      platformSupported: true,
      accessibilityEnabled: true,
      accessibilityRunning: true,
      usageAccessGranted: true,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('OpenBlock is active'), findsOneWidget);
  });

  testWidgets('statistics show interventions and missing usage access', (
    tester,
  ) async {
    final store = MemoryStore({
      RulesRepository.storageKey: RulesRepository.encode([youtubeRule]),
    });
    final platform = FakePlatform(
      runtime: RuntimeState(
        events: [
          InterventionEvent(
            at: DateTime.now(),
            ruleId: 'r1',
            packageName: 'com.google.android.youtube',
            kind: InterventionKind.block,
          ),
        ],
      ),
    );
    await pumpApp(tester, store: store, platform: platform);
    await openTab(tester, 'Statistics');
    expect(find.text('1 in the last 7 days'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Grant usage access'),
      200,
    );
    await tester.scrollUntilVisible(find.text('Most triggered rules'), 200);
    expect(find.text('No YouTube'), findsOneWidget);
  });

  testWidgets('delete all data returns to onboarding', (tester) async {
    final store = MemoryStore({
      RulesRepository.storageKey: RulesRepository.encode([youtubeRule]),
    });
    final platform = FakePlatform();
    await pumpApp(tester, store: store, platform: platform);
    await openTab(tester, 'Settings');
    await tester.scrollUntilVisible(find.text('Delete all data'), 200);
    await tapVisible(tester, find.text('Delete all data'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Take back your attention'), findsOneWidget);
    expect(platform.clearRuntimeCalls, 1);
    expect(platform.lastConfig!['rules'], isEmpty);
  });

  testWidgets('the UI is translated to Portuguese', (tester) async {
    await pumpApp(tester, store: MemoryStore(), locale: const Locale('pt'));
    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Regras'), findsOneWidget);
    expect(find.text('Nenhuma regra ativa'), findsOneWidget);
  });
}
