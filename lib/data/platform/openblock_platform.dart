import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/platform_models.dart';

/// Bridge to the native enforcement layer.
///
/// Everything here stays on the device: the native side never talks to the
/// network. See docs/architecture.md for the channel contract.
abstract interface class OpenBlockPlatform {
  /// Whether enforcement is available on this platform (Android only for now).
  bool get isSupported;

  Future<PermissionSnapshot> getPermissions();
  Future<void> openAccessibilitySettings();
  Future<void> openUsageAccessSettings();
  Future<void> openAppDetailsSettings();
  Future<List<InstalledApp>> getInstalledApps();
  Future<Uint8List?> getAppIcon(String packageName);

  /// Sends the full configuration (rules, focus session, intervention
  /// settings) to the native service.
  Future<void> syncConfig(Map<String, Object?> config);

  /// Measured foreground minutes per day for [packages], most recent day last.
  /// Returns `null` when usage access is not granted.
  Future<List<DailyUsage>?> getDailyUsage({
    required List<String> packages,
    required int days,
  });

  Future<RuntimeState> getRuntimeState();

  /// Removes a snooze set from the intervention screen.
  Future<void> clearSnooze(String ruleId);

  /// Deletes intervention history and snoozes kept by the native side.
  Future<void> clearRuntimeData();
}

OpenBlockPlatform createDefaultPlatform() {
  if (!kIsWeb && Platform.isAndroid) return MethodChannelPlatform();
  return UnsupportedPlatform();
}

class MethodChannelPlatform implements OpenBlockPlatform {
  MethodChannelPlatform([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'dev.openblock.app/platform';

  final MethodChannel _channel;

  @override
  bool get isSupported => true;

  @override
  Future<PermissionSnapshot> getPermissions() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'getPermissions',
    );
    return map == null
        ? PermissionSnapshot.unsupported
        : PermissionSnapshot.fromMap(map);
  }

  @override
  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  @override
  Future<void> openUsageAccessSettings() =>
      _channel.invokeMethod<void>('openUsageAccessSettings');

  @override
  Future<void> openAppDetailsSettings() =>
      _channel.invokeMethod<void>('openAppDetailsSettings');

  @override
  Future<List<InstalledApp>> getInstalledApps() async {
    final list =
        await _channel.invokeListMethod<Object?>('getInstalledApps') ??
        const [];
    return [
      for (final item in list)
        InstalledApp.fromMap(item! as Map<Object?, Object?>),
    ];
  }

  @override
  Future<Uint8List?> getAppIcon(String packageName) => _channel
      .invokeMethod<Uint8List>('getAppIcon', {'packageName': packageName});

  @override
  Future<void> syncConfig(Map<String, Object?> config) =>
      _channel.invokeMethod<void>('syncConfig', {'config': jsonEncode(config)});

  @override
  Future<List<DailyUsage>?> getDailyUsage({
    required List<String> packages,
    required int days,
  }) async {
    final list = await _channel.invokeListMethod<Object?>('getDailyUsage', {
      'packages': packages,
      'days': days,
    });
    if (list == null) return null;
    return [
      for (final item in list)
        DailyUsage.fromMap(item! as Map<Object?, Object?>),
    ];
  }

  @override
  Future<RuntimeState> getRuntimeState() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>(
      'getRuntimeState',
    );
    return map == null ? RuntimeState.empty : RuntimeState.fromMap(map);
  }

  @override
  Future<void> clearSnooze(String ruleId) =>
      _channel.invokeMethod<void>('clearSnooze', {'ruleId': ruleId});

  @override
  Future<void> clearRuntimeData() =>
      _channel.invokeMethod<void>('clearRuntimeData');
}

/// Used on platforms without an enforcement layer. The UI still works so the
/// app can be explored, but it clearly reports that blocking is unavailable.
class UnsupportedPlatform implements OpenBlockPlatform {
  @override
  bool get isSupported => false;

  @override
  Future<PermissionSnapshot> getPermissions() async =>
      PermissionSnapshot.unsupported;

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<void> openAppDetailsSettings() async {}

  @override
  Future<List<InstalledApp>> getInstalledApps() async => const [];

  @override
  Future<Uint8List?> getAppIcon(String packageName) async => null;

  @override
  Future<void> syncConfig(Map<String, Object?> config) async {}

  @override
  Future<List<DailyUsage>?> getDailyUsage({
    required List<String> packages,
    required int days,
  }) async => null;

  @override
  Future<RuntimeState> getRuntimeState() async => RuntimeState.empty;

  @override
  Future<void> clearSnooze(String ruleId) async {}

  @override
  Future<void> clearRuntimeData() async {}
}
