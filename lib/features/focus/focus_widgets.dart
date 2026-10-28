import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../data/models/focus_session.dart';
import '../../data/providers.dart';
import '../../l10n/l10n.dart';
import '../rules/rules_controller.dart';
import '../settings/settings_controller.dart';
import 'focus_controller.dart';

String formatCountdown(Duration duration) {
  final total = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// Shows the running session with a live countdown, or a way to start one.
class FocusCard extends ConsumerStatefulWidget {
  const FocusCard({super.key});

  @override
  ConsumerState<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends ConsumerState<FocusCard> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool running) {
    if (running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final session = ref.read(focusProvider).active;
        if (session != null && !session.isActiveAt(ref.read(clockProvider)())) {
          ref.read(focusProvider.notifier).reconcile();
        }
        setState(() {});
      });
    } else if (!running && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(focusProvider).active;
    final now = ref.read(clockProvider)();
    final running = session != null && session.isActiveAt(now);
    _syncTicker(running);

    if (!running) {
      return InfoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.center_focus_strong_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l10n.focusTitle, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.focusIdleMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in FocusController.presetsMinutes)
                  ActionChip(
                    key: Key('focus-$minutes'),
                    avatar: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(l10n.minutesShort(minutes)),
                    onPressed: () =>
                        showFocusStartSheet(context, initialMinutes: minutes),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(l10n.focusCustom),
                  onPressed: () => showFocusStartSheet(context),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final remaining = session.remainingAt(now);
    return InfoCard(
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.focusActiveTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: false,
            label: l10n.focusRemainingSemantics(remaining.inMinutes + 1),
            child: ExcludeSemantics(
              child: Text(
                formatCountdown(remaining),
                key: const Key('focusCountdown'),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: session.progressAt(now),
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.focusRulesActive(session.activeRuleIds.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('endFocus'),
              icon: const Icon(Icons.stop_rounded),
              label: Text(l10n.focusEnd),
              onPressed: () => _confirmEnd(context, ref, session),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEnd(
    BuildContext context,
    WidgetRef ref,
    FocusSession session,
  ) async {
    final l10n = context.l10n;
    final ok = await confirm(
      context,
      title: l10n.focusEndTitle,
      message: l10n.focusEndMessage,
      confirmLabel: l10n.focusEnd,
      cancelLabel: l10n.focusKeepGoing,
    );
    if (ok) ref.read(focusProvider.notifier).stop();
  }
}

Future<void> showFocusStartSheet(BuildContext context, {int? initialMinutes}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FocusStartSheet(initialMinutes: initialMinutes),
  );
}

class FocusStartSheet extends ConsumerStatefulWidget {
  const FocusStartSheet({this.initialMinutes, super.key});

  final int? initialMinutes;

  @override
  ConsumerState<FocusStartSheet> createState() => _FocusStartSheetState();
}

class _FocusStartSheetState extends ConsumerState<FocusStartSheet> {
  late int _minutes;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _minutes =
        widget.initialMinutes ?? ref.read(settingsProvider).defaultFocusMinutes;
    final rules = ref
        .read(rulesProvider)
        .where((rule) => rule.enabled && rule.mode.restricts)
        .toList();
    final focusOnly = rules.where((rule) => rule.focusOnly);
    _selected = {
      for (final rule in focusOnly.isNotEmpty ? focusOnly : rules) rule.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rules = ref
        .watch(rulesProvider)
        .where((rule) => rule.enabled && rule.mode.restricts)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.focusStartTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(
            l10n.minutesLong(_minutes),
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          Slider(
            value: _minutes.toDouble().clamp(5, 180),
            min: 5,
            max: 180,
            divisions: 35,
            label: l10n.minutesShort(_minutes),
            onChanged: (value) => setState(() => _minutes = value.round()),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final minutes in FocusController.presetsMinutes)
                ChoiceChip(
                  label: Text(l10n.minutesShort(minutes)),
                  selected: _minutes == minutes,
                  onSelected: (_) => setState(() => _minutes = minutes),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.focusRulesToApply, style: theme.textTheme.titleSmall),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.focusNoRules),
            )
          else
            for (final rule in rules)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(rule.id),
                title: Text(rule.name),
                subtitle: Text(rule.displayAppName),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _selected.add(rule.id);
                  } else {
                    _selected.remove(rule.id);
                  }
                }),
              ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('startFocus'),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.focusStart),
            onPressed: () {
              ref
                  .read(focusProvider.notifier)
                  .start(
                    duration: Duration(minutes: _minutes),
                    ruleIds: [
                      for (final rule in rules)
                        if (_selected.contains(rule.id)) rule.id,
                    ],
                  );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
