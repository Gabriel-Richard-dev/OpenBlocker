import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rule_engine.dart';
import '../../core/widgets/common.dart';
import '../../data/models/block_rule.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../focus/focus_controller.dart';
import '../statistics/statistics.dart';
import 'presets_sheet.dart';
import 'rule_editor_screen.dart';
import 'rule_texts.dart';
import 'rules_controller.dart';

/// Measured minutes today for [packageName], or `null` when unknown.
int? todayUsageFor(WidgetRef ref, String packageName) {
  final usage = ref.watch(dailyUsageProvider).value;
  if (usage == null || usage.isEmpty) return null;
  final today = ref.read(clockProvider)();
  final last = usage.last;
  if (!isSameDay(last.day, today)) return 0;
  return last.minutesByPackage[packageName] ?? 0;
}

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rules = ref.watch(rulesProvider);
    final restricting = rules.where((rule) => rule.mode.restricts).toList();
    final exceptions = rules.where((rule) => !rule.mode.restricts).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabRules),
        actions: [
          IconButton(
            tooltip: l10n.precedenceTitle,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showPrecedenceDialog(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openRuleEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.newRule),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          SectionHeader(l10n.presetsTitle),
          const PresetsCarousel(),
          SectionHeader(l10n.rulesSectionTitle),
          if (restricting.isEmpty)
            EmptyState(
              icon: Icons.rule_rounded,
              title: l10n.rulesEmptyTitle,
              message: l10n.rulesEmptyMessage,
            )
          else
            for (final rule in restricting) ...[
              RuleTile(rule: rule),
              const SizedBox(height: 8),
            ],
          SectionHeader(l10n.exceptionsSectionTitle),
          if (exceptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l10n.exceptionsEmptyMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final rule in exceptions) ...[
              RuleTile(rule: rule),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

Future<void> openRuleEditor(BuildContext context, {BlockRule? rule}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => RuleEditorScreen(initial: rule)),
  );
}

Future<void> showPrecedenceDialog(BuildContext context) {
  final l10n = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.precedenceTitle),
      content: SingleChildScrollView(child: Text(l10n.precedenceBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionClose),
        ),
      ],
    ),
  );
}

enum _RuleMenu { pause15, pause60, pauseTomorrow, resume, delete }

class RuleTile extends ConsumerWidget {
  const RuleTile({required this.rule, super.key});

  final BlockRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = ref.read(clockProvider)();
    final focus = ref.watch(focusProvider).active;
    final snoozes = ref.watch(runtimeStateProvider).value?.snoozes ?? const {};
    final usage = rule.mode == BlockMode.appLimit
        ? todayUsageFor(ref, rule.packageName)
        : null;
    final activation = RuleEngine.activation(
      rule,
      EvaluationContext.at(
        now,
        packageName: rule.packageName,
        focus: focus,
        snoozes: snoozes,
      ),
    );
    final status = activationLabel(
      context,
      rule,
      activation,
      snoozedUntilMs: snoozes[rule.id],
      usageMinutes: usage,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openRuleEditor(context, rule: rule),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              AppIconAvatar(packageName: rule.packageName),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      ruleSummary(context, rule),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Pill(
                      status,
                      color: activation.isActive
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      foreground: activation.isActive
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              Switch(
                value: rule.enabled,
                onChanged: (value) =>
                    ref.read(rulesProvider.notifier).setEnabled(rule.id, value),
              ),
              PopupMenuButton<_RuleMenu>(
                tooltip: l10n.moreOptions,
                onSelected: (choice) => _onMenu(context, ref, choice),
                itemBuilder: (context) => [
                  if (activation == RuleActivation.paused)
                    PopupMenuItem(
                      value: _RuleMenu.resume,
                      child: Text(l10n.resumeRule),
                    )
                  else if (rule.enabled) ...[
                    PopupMenuItem(
                      value: _RuleMenu.pause15,
                      child: Text(l10n.pauseFor(15)),
                    ),
                    PopupMenuItem(
                      value: _RuleMenu.pause60,
                      child: Text(l10n.pauseFor(60)),
                    ),
                    PopupMenuItem(
                      value: _RuleMenu.pauseTomorrow,
                      child: Text(l10n.pauseUntilTomorrow),
                    ),
                  ],
                  PopupMenuItem(
                    value: _RuleMenu.delete,
                    child: Text(l10n.actionDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _RuleMenu choice,
  ) async {
    final rules = ref.read(rulesProvider.notifier);
    final now = ref.read(clockProvider)();
    switch (choice) {
      case _RuleMenu.pause15:
        rules.pauseUntil(rule.id, now.add(const Duration(minutes: 15)));
      case _RuleMenu.pause60:
        rules.pauseUntil(rule.id, now.add(const Duration(hours: 1)));
      case _RuleMenu.pauseTomorrow:
        rules.pauseUntil(rule.id, DateTime(now.year, now.month, now.day + 1));
      case _RuleMenu.resume:
        rules.resume(rule.id);
      case _RuleMenu.delete:
        await confirmDeleteRule(context, ref, rule);
    }
  }
}

Future<bool> confirmDeleteRule(
  BuildContext context,
  WidgetRef ref,
  BlockRule rule,
) async {
  final l10n = context.l10n;
  final ok = await confirm(
    context,
    title: l10n.deleteRuleTitle,
    message: l10n.deleteRuleMessage(rule.name),
    confirmLabel: l10n.actionDelete,
    cancelLabel: l10n.actionCancel,
    destructive: true,
  );
  if (ok) ref.read(rulesProvider.notifier).remove(rule.id);
  return ok;
}
