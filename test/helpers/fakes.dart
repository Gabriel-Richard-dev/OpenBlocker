import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/app/app.dart';
import 'package:openblock/data/models/app_settings.dart';
import 'package:openblock/data/models/platform_models.dart';
import 'package:openblock/data/platform/openblock_platform.dart';
import 'package:openblock/data/providers.dart';
import 'package:openblock/data/storage/key_value_store.dart';

class FakePlatform implements OpenBlockPlatform {
  FakePlatform({
    this.permissions = const PermissionSnapshot(
      platformSupported: true,
      accessibilityEnabled: true,
      accessibilityRunning: true,
      usageAccessGranted: true,
      sdkInt: 34,
    ),
    this.apps = const [
      InstalledApp(packageName: 'com.google.android.youtube', label: 'YouTube'),
      InstalledApp(packageName: 'com.instagram.android', label: 'Instagram'),
      InstalledApp(packageName: 'org.wikipedia', label: 'Wikipedia'),
    ],
    this.usage,
    this.runtime = RuntimeState.empty,
  });

  PermissionSnapshot permissions;
  List<InstalledApp> apps;
  List<DailyUsage>? usage;
  RuntimeState runtime;

  final List<Map<String, Object?>> syncedConfigs = [];
  final List<String> openedSettings = [];
  final List<String> clearedSnoozes = [];
  int clearRuntimeCalls = 0;

  Map<String, Object?>? get lastConfig =>
      syncedConfigs.isEmpty ? null : syncedConfigs.last;

  @override
  bool get isSupported => true;

  @override
  Future<PermissionSnapshot> getPermissions() async => permissions;

  @override
  Future<void> openAccessibilitySettings() async =>
      openedSettings.add('accessibility');

  @override
  Future<void> openUsageAccessSettings() async => openedSettings.add('usage');

  @override
  Future<void> openAppDetailsSettings() async => openedSettings.add('details');

  @override
  Future<List<InstalledApp>> getInstalledApps() async => apps;

  @override
  Future<Uint8List?> getAppIcon(String packageName) async => null;

  @override
  Future<void> syncConfig(Map<String, Object?> config) async {
    // Round-trip through JSON like the real channel does.
    syncedConfigs.add(jsonDecode(jsonEncode(config)) as Map<String, Object?>);
  }

  @override
  Future<List<DailyUsage>?> getDailyUsage({
    required List<String> packages,
    required int days,
  }) async => usage;

  @override
  Future<RuntimeState> getRuntimeState() async => runtime;

  @override
  Future<void> clearSnooze(String ruleId) async => clearedSnoozes.add(ruleId);

  @override
  Future<void> clearRuntimeData() async => clearRuntimeCalls++;
}

class TestClock {
  TestClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

/// Creates a container backed by in-memory storage.
Future<ProviderContainer> makeContainer({
  MemoryStore? store,
  FakePlatform? platform,
  TestClock? clock,
}) async {
  final memory = store ?? MemoryStore();
  final container = ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [
      keyValueStoreProvider.overrideWithValue(memory),
      initialDataProvider.overrideWithValue(await InitialData.load(memory)),
      platformProvider.overrideWithValue(platform ?? FakePlatform()),
      if (clock != null) clockProvider.overrideWithValue(clock.call),
    ],
  );
  return container;
}

/// Pumps the whole app with in-memory storage and a fake platform.
Future<void> pumpApp(
  WidgetTester tester, {
  required MemoryStore store,
  FakePlatform? platform,
  bool onboarded = true,
  Locale locale = const Locale('en'),
}) async {
  if (onboarded && !store.values.containsKey('openblock.settings')) {
    store.values['openblock.settings'] = jsonEncode(
      const AppSettings(onboardingCompleted: true).toJson(),
    );
  }
  final initial = await InitialData.load(store);
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        initialDataProvider.overrideWithValue(initial),
        platformProvider.overrideWithValue(platform ?? FakePlatform()),
      ],
      child: const OpenBlockApp(),
    ),
  );
  await tester.pumpAndSettle();
}
