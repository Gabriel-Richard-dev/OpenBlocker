import 'package:flutter/foundation.dart';

/// Snapshot of the OS permissions OpenBlock relies on.
@immutable
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.platformSupported,
    required this.accessibilityEnabled,
    required this.accessibilityRunning,
    required this.usageAccessGranted,
    this.secureSettingsGranted = false,
    this.sdkInt,
  });

  factory PermissionSnapshot.fromMap(Map<Object?, Object?> map) {
    return PermissionSnapshot(
      platformSupported: true,
      accessibilityEnabled: map['accessibilityEnabled'] as bool? ?? false,
      accessibilityRunning: map['accessibilityRunning'] as bool? ?? false,
      usageAccessGranted: map['usageAccessGranted'] as bool? ?? false,
      secureSettingsGranted: map['secureSettingsGranted'] as bool? ?? false,
      sdkInt: (map['sdkInt'] as num?)?.toInt(),
    );
  }

  static const unsupported = PermissionSnapshot(
    platformSupported: false,
    accessibilityEnabled: false,
    accessibilityRunning: false,
    usageAccessGranted: false,
  );

  final bool platformSupported;

  /// The user turned the service on in the system accessibility settings.
  final bool accessibilityEnabled;

  /// The system reports the service as bound and running. It can be enabled
  /// but not running, e.g. after a crash or when killed by the system.
  final bool accessibilityRunning;
  final bool usageAccessGranted;

  /// WRITE_SECURE_SETTINGS, granted through ADB, which the bank guard needs
  /// to turn the accessibility service back on.
  final bool secureSettingsGranted;
  final int? sdkInt;

  /// Android 13+ blocks accessibility for side-loaded apps until the user
  /// allows "restricted settings" in the app info screen.
  bool get mayNeedRestrictedSettings => (sdkInt ?? 0) >= 33;

  bool get accessibilityStopped =>
      accessibilityEnabled && !accessibilityRunning;

  /// The bank guard also needs usage access to notice when to turn the
  /// service back on.
  bool get bankGuardReady => secureSettingsGranted && usageAccessGranted;
}

@immutable
class InstalledApp {
  const InstalledApp({required this.packageName, required this.label});

  factory InstalledApp.fromMap(Map<Object?, Object?> map) => InstalledApp(
    packageName: map['packageName']! as String,
    label: map['label'] as String? ?? map['packageName']! as String,
  );

  final String packageName;
  final String label;
}

/// Measured foreground usage for one local calendar day.
@immutable
class DailyUsage {
  const DailyUsage({required this.day, required this.minutesByPackage});

  factory DailyUsage.fromMap(Map<Object?, Object?> map) {
    final usage = map['usage'] as Map<Object?, Object?>? ?? const {};
    return DailyUsage(
      day: DateTime.parse(map['date']! as String),
      minutesByPackage: {
        for (final entry in usage.entries)
          entry.key! as String: (entry.value! as num).toInt(),
      },
    );
  }

  final DateTime day;
  final Map<String, int> minutesByPackage;

  int get totalMinutes =>
      minutesByPackage.values.fold(0, (sum, minutes) => sum + minutes);
}

enum InterventionKind { block, limit, focus, feed, pause }

/// One time the native service showed an intervention screen.
@immutable
class InterventionEvent {
  const InterventionEvent({
    required this.at,
    required this.ruleId,
    required this.packageName,
    required this.kind,
  });

  factory InterventionEvent.fromMap(Map<Object?, Object?> map) {
    return InterventionEvent(
      at: DateTime.fromMillisecondsSinceEpoch(
        (map['atMs']! as num).toInt(),
        isUtc: true,
      ).toLocal(),
      ruleId: map['ruleId'] as String? ?? '',
      packageName: map['packageName'] as String? ?? '',
      kind: InterventionKind.values.firstWhere(
        (kind) => kind.name == map['kind'],
        orElse: () => InterventionKind.block,
      ),
    );
  }

  final DateTime at;
  final String ruleId;
  final String packageName;
  final InterventionKind kind;
}

/// State that the native service changes on its own (from the intervention
/// screen) and the Flutter side needs to read back.
@immutable
class RuntimeState {
  const RuntimeState({
    this.snoozes = const {},
    this.endedFocusId,
    this.endedFocusAtMs,
    this.events = const [],
  });

  factory RuntimeState.fromMap(Map<Object?, Object?> map) {
    final snoozes = map['snoozes'] as Map<Object?, Object?>? ?? const {};
    final events = map['events'] as List<Object?>? ?? const [];
    return RuntimeState(
      snoozes: {
        for (final entry in snoozes.entries)
          entry.key! as String: (entry.value! as num).toInt(),
      },
      endedFocusId: map['endedFocusId'] as String?,
      endedFocusAtMs: (map['endedFocusAtMs'] as num?)?.toInt(),
      events: [
        for (final event in events)
          InterventionEvent.fromMap(event! as Map<Object?, Object?>),
      ],
    );
  }

  static const empty = RuntimeState();

  /// Rule id → UTC epoch ms until which the rule is snoozed.
  final Map<String, int> snoozes;

  /// Focus session ended from the intervention screen, if any.
  final String? endedFocusId;
  final int? endedFocusAtMs;
  final List<InterventionEvent> events;
}
