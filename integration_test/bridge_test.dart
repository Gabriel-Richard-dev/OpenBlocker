import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openblock/app/app.dart';
import 'package:openblock/app/config_sync.dart';
import 'package:openblock/data/models/app_settings.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/platform/openblock_platform.dart';
import 'package:openblock/data/providers.dart';
import 'package:openblock/data/storage/key_value_store.dart';

/// Runs on a real device or emulator: exercises the Kotlin side of the
/// method channel and the real DataStore-backed storage.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = MethodChannelPlatform();

  testWidgets('native bridge answers every documented method', (tester) async {
    final permissions = await platform.getPermissions();
    expect(permissions.platformSupported, isTrue);
    expect(permissions.sdkInt, greaterThanOrEqualTo(26));

    final apps = await platform.getInstalledApps();
    expect(apps, isNotEmpty);
    expect(
      apps.map((app) => app.packageName),
      isNot(contains('dev.openblock.app')),
    );
    final icon = await platform.getAppIcon(apps.first.packageName);
    expect(icon, isNotNull);

    const rule = BlockRule(
      id: 'bridge-test',
      name: 'Bridge test',
      packageName: 'com.example.nothing',
      mode: BlockMode.scheduledBlock,
    );
    await platform.syncConfig(
      buildNativeConfig(
        rules: const [rule],
        focus: null,
        settings: const AppSettings(),
      ),
    );

    final usage = await platform.getDailyUsage(
      packages: [apps.first.packageName],
      days: 3,
    );
    if (permissions.usageAccessGranted) {
      expect(usage, hasLength(3));
    } else {
      expect(usage, isNull);
    }

    await platform.clearSnooze('bridge-test');
    await platform.clearRuntimeData();
    final runtime = await platform.getRuntimeState();
    expect(runtime.events, isEmpty);
    expect(runtime.snoozes, isEmpty);

    await platform.syncConfig(
      buildNativeConfig(
        rules: const [],
        focus: null,
        settings: const AppSettings(),
      ),
    );
  });

  testWidgets('real storage keeps rules across a restart', (tester) async {
    final store = SharedPreferencesStore();
    await store.clear();

    Future<void> launch() async {
      final initial = await InitialData.load(store);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          retry: (_, _) => null,
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            initialDataProvider.overrideWithValue(initial),
          ],
          child: const OpenBlockApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await launch();
    // Walk through onboarding.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('onboardingNext')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('onboardingNext')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    // Change a setting, then restart the app on the same storage.
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await launch();
    expect(find.byType(NavigationBar), findsOneWidget);
    final context = tester.element(find.byType(NavigationBar));
    expect(Theme.of(context).brightness, Brightness.dark);
    await store.clear();
  });
}
