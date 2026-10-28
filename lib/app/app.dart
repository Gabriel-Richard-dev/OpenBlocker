import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_controller.dart';
import '../features/shell/app_shell.dart';
import '../l10n/l10n.dart';
import 'config_sync.dart';
import 'theme.dart';

class OpenBlockApp extends ConsumerWidget {
  const OpenBlockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(configSyncProvider);
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: settings.onboardingCompleted
          ? const AppShell()
          : const OnboardingScreen(),
    );
  }
}
