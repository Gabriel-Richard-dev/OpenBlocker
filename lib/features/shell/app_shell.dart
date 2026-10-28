import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../focus/focus_controller.dart';
import '../home/home_screen.dart';
import '../rules/rules_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/statistics.dart';
import '../statistics/statistics_screen.dart';

/// Bottom navigation with the four main areas: Home, Rules, Statistics and
/// Settings.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Permissions can be revoked and the service can be stopped while the app
    // is in the background, so refresh everything when coming back.
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  void _refresh() {
    ref
      ..invalidate(permissionsProvider)
      ..invalidate(runtimeStateProvider)
      ..invalidate(dailyUsageProvider);
    ref.read(focusProvider.notifier).reconcile();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = [
      HomeScreen(onOpenRules: () => setState(() => _index = 1)),
      const RulesScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.rule_outlined),
            selectedIcon: const Icon(Icons.rule_rounded),
            label: l10n.tabRules,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: l10n.tabStatistics,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
