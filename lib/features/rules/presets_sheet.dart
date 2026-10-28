import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/presets.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import 'rule_editor_screen.dart';
import 'rule_texts.dart';
import 'rules_controller.dart';

class PresetsCarousel extends StatelessWidget {
  const PresetsCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: Presets.all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            SizedBox(width: 200, child: PresetCard(preset: Presets.all[index])),
      ),
    );
  }
}

class PresetCard extends ConsumerWidget {
  const PresetCard({required this.preset, super.key});

  final Preset preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return InfoCard(
      onTap: () => applyPreset(context, ref, preset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(presetIcon(preset.id), color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(presetName(l10n, preset.id), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              presetDescription(l10n, preset.id),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> applyPreset(
  BuildContext context,
  WidgetRef ref,
  Preset preset,
) async {
  final l10n = context.l10n;
  if (preset.id == PresetId.custom) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RuleEditorScreen()));
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final apps = await ref.read(installedAppsProvider.future);
  final rules = preset.build(
    installed: {for (final app in apps) app.packageName: app.label},
    ruleName: (label) =>
        l10n.presetRuleName(presetName(l10n, preset.id), label),
  );
  if (!context.mounted) return;
  if (rules.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.presetNoApps)));
    return;
  }
  final support = [
    if (preset.support.android) 'Android',
    if (preset.support.ios) 'iOS',
  ].join(', ');
  final ok = await confirm(
    context,
    title: presetName(l10n, preset.id),
    message: l10n.presetConfirm(
      rules.length,
      rules.map((rule) => rule.displayAppName).toSet().join(', '),
      support,
    ),
    confirmLabel: l10n.actionAdd,
    cancelLabel: l10n.actionCancel,
  );
  if (!ok) return;
  final added = ref.read(rulesProvider.notifier).addAll(rules);
  messenger.showSnackBar(SnackBar(content: Text(l10n.presetAdded(added))));
}
