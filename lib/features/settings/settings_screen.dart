import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/version.dart';
import '../../core/bank_apps.dart';
import '../../core/widgets/common.dart';
import '../../data/backup.dart';
import '../../data/models/platform_models.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../focus/focus_controller.dart';
import '../rules/rules_controller.dart';
import '../statistics/statistics.dart';
import 'bank_apps_screen.dart';
import 'permissions_screen.dart';
import 'privacy_screen.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final permissions = ref.watch(permissionsProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          SectionHeader(l10n.settingsPermissions),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(l10n.permissionsTitle),
              subtitle: Text(l10n.permissionsSubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PermissionsScreen(),
                ),
              ),
            ),
          ),
          SectionHeader(l10n.settingsAppearance),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
                icon: const Icon(Icons.brightness_auto_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
                icon: const Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.themeDark),
                icon: const Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
          SectionHeader(l10n.settingsIntervention),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: Text(l10n.pauseLength),
                  trailing: DropdownButton<int>(
                    value: settings.pauseSeconds,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final seconds in {
                        0,
                        5,
                        10,
                        20,
                        30,
                        settings.pauseSeconds,
                      })
                        DropdownMenuItem(
                          value: seconds,
                          child: Text(l10n.secondsShort(seconds)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) controller.setPauseSeconds(value);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: Text(l10n.pauseMessage),
                  subtitle: Text(
                    settings.pauseMessage ?? l10n.pauseMessageDefault,
                  ),
                  onTap: () => _editPauseMessage(context, ref),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.settingsBanking),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.account_balance_outlined),
                  title: Text(l10n.bankGuardTitle),
                  subtitle: Text(l10n.bankGuardSubtitle),
                  value: settings.bankGuardEnabled,
                  onChanged: controller.setBankGuardEnabled,
                ),
                ListTile(
                  leading: const Icon(Icons.list_alt_rounded),
                  title: Text(l10n.bankAppsTitle),
                  subtitle: Text(
                    l10n.bankAppsCount(settings.bankPackages.length),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  enabled: settings.bankGuardEnabled,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BankAppsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (settings.bankGuardEnabled &&
              permissions != null &&
              permissions.platformSupported &&
              !permissions.bankGuardReady)
            _BankGuardSetup(permissions: permissions),
          SectionHeader(l10n.settingsPrivacy),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(l10n.privacyTitle),
              subtitle: Text(l10n.privacySubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
              ),
            ),
          ),
          SectionHeader(l10n.settingsData),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_rounded),
                  title: Text(l10n.exportConfig),
                  subtitle: Text(l10n.exportConfigSubtitle),
                  onTap: () => _export(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(l10n.importConfig),
                  subtitle: Text(l10n.importConfigSubtitle),
                  onTap: () => _import(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart_rounded),
                  title: Text(l10n.deleteStatistics),
                  onTap: () => _deleteStatistics(context, ref),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    l10n.deleteAllData,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => _deleteAll(context, ref),
                ),
              ],
            ),
          ),
          SectionHeader(l10n.settingsAbout),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l10n.appName),
                  subtitle: Text(l10n.aboutVersion(appVersion)),
                ),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: Text(l10n.sourceCode),
                  subtitle: const Text(sourceCodeUrl),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      const ClipboardData(text: sourceCodeUrl),
                    );
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.copiedToClipboard)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: Text(l10n.licenses),
                  subtitle: Text(l10n.licenseMit),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: l10n.appName,
                    applicationVersion: appVersion,
                    applicationLegalese: l10n.licenseMit,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.replay_rounded),
                  title: Text(l10n.showOnboarding),
                  onTap: controller.restartOnboarding,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPauseMessage(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final text = TextEditingController(
      text: ref.read(settingsProvider).pauseMessage ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pauseMessage),
        content: TextField(
          controller: text,
          maxLength: 140,
          maxLines: 3,
          decoration: InputDecoration(hintText: l10n.pauseMessageDefault),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.actionReset),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    text.dispose();
    if (result != null) {
      ref.read(settingsProvider.notifier).setPauseMessage(result);
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final backup = Backup(
      settings: ref.read(settingsProvider),
      rules: ref.read(rulesProvider),
    );
    await Clipboard.setData(ClipboardData(text: backup.encode()));
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone)));
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final Backup backup;
    try {
      backup = Backup.decode(data?.text ?? '');
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importInvalid)));
      return;
    }
    if (!context.mounted) return;
    final ok = await confirm(
      context,
      title: l10n.importConfig,
      message: l10n.importConfirm(backup.rules.length),
      confirmLabel: l10n.actionReplace,
      cancelLabel: l10n.actionCancel,
      destructive: true,
    );
    if (!ok) return;
    ref.read(rulesProvider.notifier).replaceAll(backup.rules);
    ref.read(settingsProvider.notifier).replace(backup.settings);
    messenger.showSnackBar(SnackBar(content: Text(l10n.importDone)));
  }

  Future<void> _deleteStatistics(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirm(
      context,
      title: l10n.deleteStatistics,
      message: l10n.deleteStatisticsMessage,
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.actionCancel,
      destructive: true,
    );
    if (!ok) return;
    ref.read(focusProvider.notifier).clearHistory();
    await ref.read(platformProvider).clearRuntimeData();
    ref
      ..invalidate(runtimeStateProvider)
      ..invalidate(dailyUsageProvider);
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirm(
      context,
      title: l10n.deleteAllData,
      message: l10n.deleteAllDataMessage,
      confirmLabel: l10n.actionDelete,
      cancelLabel: l10n.actionCancel,
      destructive: true,
    );
    if (!ok) return;
    ref.read(focusProvider.notifier).resetAll();
    ref.read(rulesProvider.notifier).replaceAll(const []);
    await ref.read(platformProvider).clearRuntimeData();
    await ref.read(keyValueStoreProvider).clear();
    ref.invalidate(runtimeStateProvider);
    // Resetting settings last returns the app to onboarding.
    ref.read(settingsProvider.notifier).reset();
  }
}

/// Explains the one-time ADB grant the bank guard needs.
class _BankGuardSetup extends ConsumerWidget {
  const _BankGuardSetup({required this.permissions});

  final PermissionSnapshot permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return InfoCard(
      color: theme.colorScheme.tertiaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bankGuardSetupTitle, style: theme.textTheme.titleSmall),
          if (!permissions.secureSettingsGranted) ...[
            const SizedBox(height: 4),
            Text(l10n.bankGuardSetupMessage),
            const SizedBox(height: 8),
            const Text(
              BankApps.adbGrantCommand,
              style: TextStyle(fontFamily: 'monospace'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: Text(l10n.copyCommand),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                    const ClipboardData(text: BankApps.adbGrantCommand),
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.copiedToClipboard)),
                  );
                },
              ),
            ),
          ],
          if (!permissions.usageAccessGranted) ...[
            const SizedBox(height: 4),
            Text(l10n.bankGuardNeedsUsage),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    ref.read(platformProvider).openUsageAccessSettings(),
                child: Text(l10n.openSystemSettings),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.refreshStatus),
              onPressed: () => ref.invalidate(permissionsProvider),
            ),
          ),
        ],
      ),
    );
  }
}
