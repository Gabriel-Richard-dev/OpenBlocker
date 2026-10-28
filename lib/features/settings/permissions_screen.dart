import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/models/platform_models.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.permissionsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [PermissionPanel()],
      ),
    );
  }
}

/// Status and controls for every permission OpenBlock uses. Nothing is
/// granted from here: each button opens the system screen where the user
/// decides.
class PermissionPanel extends ConsumerWidget {
  const PermissionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final platform = ref.watch(platformProvider);
    final snapshot = ref.watch(permissionsProvider);
    final permissions = snapshot.value;

    if (permissions != null && !permissions.platformSupported) {
      return InfoCard(child: Text(l10n.issueUnsupportedPlatform));
    }

    final accessibilityStatus = permissions == null
        ? l10n.permissionChecking
        : permissions.accessibilityStopped
        ? l10n.permissionStopped
        : permissions.accessibilityEnabled
        ? l10n.permissionGranted
        : l10n.permissionNotGranted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PermissionTile(
          icon: Icons.accessibility_new_rounded,
          title: l10n.permissionAccessibility,
          status: accessibilityStatus,
          granted: permissions?.accessibilityRunning ?? false,
          why: l10n.permissionAccessibilityWhy,
          observes: l10n.permissionAccessibilityObserves,
          actionLabel: l10n.openSystemSettings,
          onAction: () => platform.openAccessibilitySettings(),
        ),
        const SizedBox(height: 12),
        _PermissionTile(
          icon: Icons.query_stats_rounded,
          title: l10n.permissionUsageAccess,
          status: permissions == null
              ? l10n.permissionChecking
              : permissions.usageAccessGranted
              ? l10n.permissionGranted
              : l10n.permissionNotGranted,
          granted: permissions?.usageAccessGranted ?? false,
          why: l10n.permissionUsageWhy,
          observes: l10n.permissionUsageObserves,
          actionLabel: l10n.openSystemSettings,
          onAction: () => platform.openUsageAccessSettings(),
        ),
        const SizedBox(height: 12),
        InfoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.layers_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.permissionOverlayNotNeeded)),
            ],
          ),
        ),
        if (permissions?.mayNeedRestrictedSettings ?? false) ...[
          const SizedBox(height: 12),
          _RestrictedSettingsHint(permissions: permissions!),
        ],
        const SizedBox(height: 12),
        Text(
          l10n.permissionsRevokeHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.refreshStatus),
          onPressed: () => ref.invalidate(permissionsProvider),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.granted,
    required this.why,
    required this.observes,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool granted;
  final String why;
  final String observes;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              Pill(
                status,
                color: granted
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.errorContainer,
                foreground: granted
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onErrorContainer,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.permissionWhyLabel, style: theme.textTheme.labelLarge),
          Text(why),
          const SizedBox(height: 8),
          Text(l10n.permissionObservesLabel, style: theme.textTheme.labelLarge),
          Text(observes),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestrictedSettingsHint extends ConsumerWidget {
  const _RestrictedSettingsHint({required this.permissions});

  final PermissionSnapshot permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return InfoCard(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.restrictedSettingsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(l10n.restrictedSettingsMessage),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  ref.read(platformProvider).openAppDetailsSettings(),
              child: Text(l10n.openAppInfo),
            ),
          ),
        ],
      ),
    );
  }
}
