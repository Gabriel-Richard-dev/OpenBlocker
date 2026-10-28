import 'package:flutter/material.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.themeMode = ThemeMode.system,
    this.snoozeMinutes = 5,
    this.pauseSeconds = 10,
    this.pauseMessage,
    this.defaultFocusMinutes = 25,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      snoozeMinutes: (json['snoozeMinutes'] as num?)?.toInt() ?? 5,
      pauseSeconds: (json['pauseSeconds'] as num?)?.toInt() ?? 10,
      pauseMessage: json['pauseMessage'] as String?,
      defaultFocusMinutes: (json['defaultFocusMinutes'] as num?)?.toInt() ?? 25,
    );
  }

  final bool onboardingCompleted;
  final ThemeMode themeMode;

  /// How long "Snooze" on the intervention screen disables the rule.
  final int snoozeMinutes;

  /// Countdown on the pause screen before "Continue" is enabled.
  final int pauseSeconds;

  /// Optional custom message on the intervention screen.
  final String? pauseMessage;
  final int defaultFocusMinutes;

  AppSettings copyWith({
    bool? onboardingCompleted,
    ThemeMode? themeMode,
    int? snoozeMinutes,
    int? pauseSeconds,
    String? pauseMessage,
    bool clearPauseMessage = false,
    int? defaultFocusMinutes,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      themeMode: themeMode ?? this.themeMode,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      pauseSeconds: pauseSeconds ?? this.pauseSeconds,
      pauseMessage: clearPauseMessage
          ? null
          : (pauseMessage ?? this.pauseMessage),
      defaultFocusMinutes: defaultFocusMinutes ?? this.defaultFocusMinutes,
    );
  }

  Map<String, Object?> toJson() => {
    'onboardingCompleted': onboardingCompleted,
    'themeMode': themeMode.name,
    'snoozeMinutes': snoozeMinutes,
    'pauseSeconds': pauseSeconds,
    'pauseMessage': pauseMessage,
    'defaultFocusMinutes': defaultFocusMinutes,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.onboardingCompleted == onboardingCompleted &&
      other.themeMode == themeMode &&
      other.snoozeMinutes == snoozeMinutes &&
      other.pauseSeconds == pauseSeconds &&
      other.pauseMessage == pauseMessage &&
      other.defaultFocusMinutes == defaultFocusMinutes;

  @override
  int get hashCode => Object.hash(
    onboardingCompleted,
    themeMode,
    snoozeMinutes,
    pauseSeconds,
    pauseMessage,
    defaultFocusMinutes,
  );
}
