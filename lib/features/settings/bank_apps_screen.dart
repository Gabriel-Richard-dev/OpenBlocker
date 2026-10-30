import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bank_apps.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../rules/app_picker.dart';
import 'settings_controller.dart';

/// Banking apps the accessibility service steps aside for.
class BankAppsScreen extends ConsumerWidget {
  const BankAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final packages = ref.watch(settingsProvider).bankPackages;
    final installed = ref.watch(installedAppsProvider).value ?? const [];
    final labels = {
      ...BankApps.labels,
      for (final app in installed) app.packageName: app.label,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bankAppsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.bankAppsAdd),
        onPressed: () async {
          final app = await pickApp(context);
          if (app != null) {
            ref.read(settingsProvider.notifier).addBankPackage(app.packageName);
          }
        },
      ),
      body: packages.isEmpty
          ? EmptyState(
              icon: Icons.account_balance_outlined,
              title: l10n.bankAppsEmpty,
              message: l10n.bankGuardSubtitle,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final packageName in packages)
                  ListTile(
                    leading: AppIconAvatar(packageName: packageName),
                    title: Text(labels[packageName] ?? packageName),
                    subtitle: Text(packageName),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: l10n.actionDelete,
                      onPressed: () => ref
                          .read(settingsProvider.notifier)
                          .removeBankPackage(packageName),
                    ),
                  ),
              ],
            ),
    );
  }
}
