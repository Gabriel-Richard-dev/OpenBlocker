import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/bank_apps.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.themeMode = ThemeMode.system,
    this.pauseSeconds = 10,
    this.pauseMessage,
    this.defaultFocusMinutes = 25,
    this.bankGuardEnabled = true,
    List<String>? bankPackages,
  }) : _bankPackages = bankPackages;

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      pauseSeconds: (json['pauseSeconds'] as num?)?.toInt() ?? 10,
      pauseMessage: json['pauseMessage'] as String?,
      defaultFocusMinutes: (json['defaultFocusMinutes'] as num?)?.toInt() ?? 25,
      bankGuardEnabled: json['bankGuardEnabled'] as bool? ?? true,
      bankPackages: (json['bankPackages'] as List<Object?>?)?.cast<String>(),
    );
  }

  final bool onboardingCompleted;
  final ThemeMode themeMode;

  /// Countdown on the pause screen before "Continue" is enabled.
  final int pauseSeconds;

  /// Optional custom message on the intervention screen.
  final String? pauseMessage;
  final int defaultFocusMinutes;

  /// Turn the accessibility service off while a banking app is in front.
  final bool bankGuardEnabled;

  final List<String>? _bankPackages;

  /// Banking apps the guard steps aside for. Defaults to [BankApps.defaults].
  List<String> get bankPackages => _bankPackages ?? BankApps.defaults;

  AppSettings copyWith({
    bool? onboardingCompleted,
    ThemeMode? themeMode,
    int? pauseSeconds,
    String? pauseMessage,
    bool clearPauseMessage = false,
    int? defaultFocusMinutes,
    bool? bankGuardEnabled,
    List<String>? bankPackages,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      themeMode: themeMode ?? this.themeMode,
      pauseSeconds: pauseSeconds ?? this.pauseSeconds,
      pauseMessage: clearPauseMessage
          ? null
          : (pauseMessage ?? this.pauseMessage),
      defaultFocusMinutes: defaultFocusMinutes ?? this.defaultFocusMinutes,
      bankGuardEnabled: bankGuardEnabled ?? this.bankGuardEnabled,
      bankPackages: bankPackages ?? _bankPackages,
    );
  }

  Map<String, Object?> toJson() => {
    'onboardingCompleted': onboardingCompleted,
    'themeMode': themeMode.name,
    'pauseSeconds': pauseSeconds,
    'pauseMessage': pauseMessage,
    'defaultFocusMinutes': defaultFocusMinutes,
    'bankGuardEnabled': bankGuardEnabled,
    'bankPackages': _bankPackages,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.onboardingCompleted == onboardingCompleted &&
      other.themeMode == themeMode &&
      other.pauseSeconds == pauseSeconds &&
      other.pauseMessage == pauseMessage &&
      other.defaultFocusMinutes == defaultFocusMinutes &&
      other.bankGuardEnabled == bankGuardEnabled &&
      listEquals(other.bankPackages, bankPackages);

  @override
  int get hashCode => Object.hash(
    onboardingCompleted,
    themeMode,
    pauseSeconds,
    pauseMessage,
    defaultFocusMinutes,
    bankGuardEnabled,
    Object.hashAll(bankPackages),
  );
}
