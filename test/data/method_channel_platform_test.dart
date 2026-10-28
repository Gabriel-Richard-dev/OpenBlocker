import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/data/platform/openblock_platform.dart';

/// Checks the Dart side of the channel contract documented in
/// docs/architecture.md. The native side is covered by the Android build and
/// the integration test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(MethodChannelPlatform.channelName);
  final calls = <MethodCall>[];
  late Object? Function(MethodCall call) reply;

  setUp(() {
    calls.clear();
    reply = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final platform = MethodChannelPlatform();

  test('getPermissions parses the native map', () async {
    reply = (_) => {
      'accessibilityEnabled': true,
      'accessibilityRunning': false,
      'usageAccessGranted': true,
      'sdkInt': 35,
    };
    final snapshot = await platform.getPermissions();
    expect(calls.single.method, 'getPermissions');
    expect(snapshot.platformSupported, isTrue);
    expect(snapshot.accessibilityStopped, isTrue);
    expect(snapshot.sdkInt, 35);
  });

  test('syncConfig sends a JSON string', () async {
    await platform.syncConfig({'version': 1, 'rules': <Object?>[]});
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(jsonDecode(args['config']! as String), {
      'version': 1,
      'rules': <Object?>[],
    });
  });

  test('getInstalledApps and getDailyUsage parse lists', () async {
    reply = (call) => switch (call.method) {
      'getInstalledApps' => [
        {'packageName': 'a.b', 'label': 'AB'},
      ],
      'getDailyUsage' => [
        {
          'date': '2026-10-28',
          'usage': {'a.b': 12},
        },
      ],
      _ => null,
    };
    final apps = await platform.getInstalledApps();
    expect(apps.single.label, 'AB');
    final usage = await platform.getDailyUsage(packages: ['a.b'], days: 7);
    expect(usage!.single.minutesByPackage['a.b'], 12);
    expect((calls.last.arguments as Map<Object?, Object?>)['days'], 7);
  });

  test('getDailyUsage returns null without usage access', () async {
    expect(await platform.getDailyUsage(packages: ['a'], days: 1), isNull);
  });

  test('getRuntimeState tolerates a missing reply', () async {
    final state = await platform.getRuntimeState();
    expect(state.events, isEmpty);
  });

  test('simple commands use the documented method names', () async {
    await platform.openAccessibilitySettings();
    await platform.openUsageAccessSettings();
    await platform.openAppDetailsSettings();
    await platform.clearSnooze('r1');
    await platform.clearRuntimeData();
    expect(calls.map((c) => c.method), [
      'openAccessibilitySettings',
      'openUsageAccessSettings',
      'openAppDetailsSettings',
      'clearSnooze',
      'clearRuntimeData',
    ]);
  });
}
