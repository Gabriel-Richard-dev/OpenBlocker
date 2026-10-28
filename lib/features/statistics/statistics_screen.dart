import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../focus/focus_controller.dart';
import '../rules/rules_controller.dart';
import '../settings/permissions_screen.dart';
import 'statistics.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    final days = lastDays(now, statisticsDays);
    final events = ref.watch(runtimeStateProvider).value?.events ?? const [];
    final focus = ref.watch(focusProvider);
    final sessions = [?focus.active, ...focus.history];
    final rules = ref.watch(rulesProvider);
    final usage = ref.watch(dailyUsageProvider);

    final interventions = interventionsPerDay(events, days);
    final focusMinutes = focusMinutesPerDay(sessions, days, now);
    final completed = completedSessionsSince(sessions, days.first);
    final byRule = interventionsByRule(
      events.where((event) => !event.at.isBefore(days.first)).toList(),
    );
    final ruleNames = {for (final rule in rules) rule.id: rule.name};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabStatistics)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(runtimeStateProvider)
            ..invalidate(dailyUsageProvider);
          await ref.read(runtimeStateProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            SectionHeader(l10n.statsInterventionsTitle),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.statsTotalLast7Days(
                      interventions.fold(0, (a, b) => a + b),
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  BarChart(days: days, values: interventions),
                  const SizedBox(height: 8),
                  Text(
                    l10n.statsInterventionsSource,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SectionHeader(l10n.statsFocusTitle),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.statsSessionsCompleted(completed),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  BarChart(days: days, values: focusMinutes),
                  const SizedBox(height: 8),
                  Text(
                    l10n.statsFocusSource,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SectionHeader(l10n.statsUsageTitle),
            usage.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => InfoCard(child: Text(l10n.usageUnavailable)),
              data: (data) {
                if (data == null) {
                  return InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.usageNeedsPermission),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PermissionsScreen(),
                            ),
                          ),
                          child: Text(l10n.fixPermissions),
                        ),
                      ],
                    ),
                  );
                }
                if (rules.isEmpty || data.isEmpty) {
                  return InfoCard(child: Text(l10n.usageNoRules));
                }
                final totals = <String, int>{};
                for (final day in data) {
                  day.minutesByPackage.forEach((package, minutes) {
                    totals[package] = (totals[package] ?? 0) + minutes;
                  });
                }
                final today = data.last;
                final labels = {
                  for (final rule in rules)
                    rule.packageName: rule.displayAppName,
                };
                final packages = labels.keys.toList()
                  ..sort((a, b) => (totals[b] ?? 0).compareTo(totals[a] ?? 0));
                return InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.usageMeasuredNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      for (final package in packages)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AppIconAvatar(packageName: package),
                          title: Text(labels[package]!),
                          subtitle: Text(
                            l10n.usageWeekTotal(totals[package] ?? 0),
                          ),
                          trailing: Text(
                            l10n.usageToday(
                              isSameDay(today.day, now)
                                  ? today.minutesByPackage[package] ?? 0
                                  : 0,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (byRule.isNotEmpty) ...[
              SectionHeader(l10n.statsTopRules),
              Card(
                child: Column(
                  children: [
                    for (final entry in byRule.take(5))
                      ListTile(
                        title: Text(ruleNames[entry.key] ?? l10n.deletedRule),
                        trailing: Text('${entry.value}'),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Minimal accessible bar chart for one value per day.
class BarChart extends StatelessWidget {
  const BarChart({required this.days, required this.values, super.key});

  final List<DateTime> days;
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final max = values.fold(0, (a, b) => a > b ? a : b);
    final dayFormat = DateFormat.E(locale);
    final fullFormat = DateFormat.MMMEd(locale);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Semantics(
                label: '${fullFormat.format(days[i])}: ${values[i]}',
                excludeSemantics: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${values[i]}', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: max == 0 ? 2 : 2 + 70 * values[i] / max,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: i == days.length - 1
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayFormat.format(days[i]),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
