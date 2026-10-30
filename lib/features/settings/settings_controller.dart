import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/providers.dart';

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialDataProvider).settings;

  void _set(AppSettings next) {
    if (next == state) return;
    state = next;
    unawaited(ref.read(settingsRepositoryProvider).save(next));
  }

  void completeOnboarding() => _set(state.copyWith(onboardingCompleted: true));

  void restartOnboarding() => _set(state.copyWith(onboardingCompleted: false));

  void setThemeMode(ThemeMode mode) => _set(state.copyWith(themeMode: mode));

  void setPauseSeconds(int seconds) =>
      _set(state.copyWith(pauseSeconds: seconds.clamp(0, 60)));

  void setPauseMessage(String? message) {
    final trimmed = message?.trim();
    _set(
      trimmed == null || trimmed.isEmpty
          ? state.copyWith(clearPauseMessage: true)
          : state.copyWith(pauseMessage: trimmed),
    );
  }

  void setDefaultFocusMinutes(int minutes) =>
      _set(state.copyWith(defaultFocusMinutes: minutes.clamp(1, 600)));

  void setBankGuardEnabled(bool enabled) =>
      _set(state.copyWith(bankGuardEnabled: enabled));

  void addBankPackage(String packageName) {
    if (state.bankPackages.contains(packageName)) return;
    _set(state.copyWith(bankPackages: [...state.bankPackages, packageName]));
  }

  void removeBankPackage(String packageName) => _set(
    state.copyWith(
      bankPackages: [
        for (final p in state.bankPackages)
          if (p != packageName) p,
      ],
    ),
  );

  /// Replaces all settings, e.g. after an import. Onboarding state is kept.
  void replace(AppSettings settings) =>
      _set(settings.copyWith(onboardingCompleted: state.onboardingCompleted));

  void reset() => _set(const AppSettings());
}
