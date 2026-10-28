import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/models/block_rule.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../focus/focus_controller.dart';
import '../focus/focus_widgets.dart';
import '../rules/rules_controller.dart';
import '../rules/rules_screen.dart';
import '../settings/permissions_screen.dart';
import '../statistics/statistics.dart';
import 'protection_status.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({this.onOpenRules, super.key});

  /// Switches the shell to the Rules tab.
  final VoidCallback? onOpenRules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(permissionsProvider)
            ..invalidate(runtimeStateProvider)
            ..invalidate(dailyUsageProvider);
          await ref.read(permissionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ProtectionCard(),
            const SizedBox(height: 12),
            const FocusCard(),
            SectionHeader(l10n.todayTitle),
            const TodaySummary(),
            SectionHeader(l10n.quickActions),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.newRule),
                  onPressed: () => openRuleEditor(context),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.rule_rounded),
                  label: Text(l10n.editRules),
                  onPressed: onOpenRules,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProtectionCard extends ConsumerWidget {
  const ProtectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rules = ref.watch(rulesProvider);
    final permissions = ref.watch(permissionsProvider).value;
    final status = ProtectionStatus.compute(rules, permissions);
    final enabledCount = rules.where((rule) => rule.enabled).length;

    final (
      IconData icon,
      String title,
      String message,
      Color bg,
      Color fg,
    ) = switch (status.level) {
      ProtectionLevel.noRules => (
        Icons.shield_outlined,
        l10n.statusNoRulesTitle,
        l10n.statusNoRulesMessage,
        theme.colorScheme.surfaceContainerLow,
        theme.colorScheme.onSurface,
      ),
      ProtectionLevel.working => (
        Icons.shield_rounded,
        l10n.statusWorkingTitle,
        l10n.statusWorkingMessage(enabledCount),
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
      ),
      ProtectionLevel.partial => (
        Icons.shield_outlined,
        l10n.statusPartialTitle,
        l10n.statusPartialMessage,
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
      ProtectionLevel.notWorking => (
        Icons.gpp_bad_outlined,
        l10n.statusNotWorkingTitle,
        l10n.statusNotWorkingMessage,
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      ProtectionLevel.unknown => (
        Icons.shield_outlined,
        l10n.statusCheckingTitle,
        '',
        theme.colorScheme.surfaceContainerLow,
        theme.colorScheme.onSurface,
      ),
    };

    return InfoCard(
      key: const Key('protectionCard'),
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(color: fg),
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: fg)),
          ],
          for (final issue in status.issues) ...[
            const SizedBox(height: 8),
            Text('• ${issueMessage(l10n, issue)}', style: TextStyle(color: fg)),
          ],
          if (status.issues.isNotEmpty &&
              !status.issues.contains(ProtectionIssue.unsupportedPlatform)) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PermissionsScreen(),
                ),
              ),
              child: Text(l10n.fixPermissions),
            ),
          ],
        ],
      ),
    );
  }
}

String issueMessage(AppLocalizations l10n, ProtectionIssue issue) =>
    switch (issue) {
      ProtectionIssue.unsupportedPlatform => l10n.issueUnsupportedPlatform,
      ProtectionIssue.accessibilityOff => l10n.issueAccessibilityOff,
      ProtectionIssue.accessibilityStopped => l10n.issueAccessibilityStopped,
      ProtectionIssue.usageAccessMissing => l10n.issueUsageAccessMissing,
    };

class TodaySummary extends ConsumerWidget {
  const TodaySummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    final events = ref.watch(runtimeStateProvider).value?.events ?? const [];
    final focus = ref.watch(focusProvider);
    final rules = ref.watch(rulesProvider);
    final today = lastDays(now, 1);
    final interventions = interventionsPerDay(events, today).first;
    final focusMinutes = focusMinutesPerDay(
      [?focus.active, ...focus.history],
      today,
      now,
    ).first;
    final limits = rules
        .where((rule) => rule.enabled && rule.mode == BlockMode.appLimit)
        .toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: l10n.metricInterventions,
                value: '$interventions',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metric(
                label: l10n.metricFocusMinutes,
                value: l10n.minutesShort(focusMinutes),
              ),
            ),
          ],
        ),
        if (limits.isNotEmpty) ...[
          const SizedBox(height: 12),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.limitsToday, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  l10n.usageMeasuredNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final rule in limits)
                  _LimitRow(
                    label: rule.displayAppName,
                    used: todayUsageFor(ref, rule.packageName),
                    limit: rule.dailyLimitMinutes ?? 0,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.label,
    required this.used,
    required this.limit,
  });

  final String label;
  final int? used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final used = this.used;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                used == null
                    ? l10n.usageUnknown
                    : l10n.usageOfLimit(used, limit),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: used == null || limit == 0
                ? 0
                : (used / limit).clamp(0.0, 1.0),
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}
