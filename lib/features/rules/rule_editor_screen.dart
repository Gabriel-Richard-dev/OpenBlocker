import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../core/rule_validation.dart';
import '../../core/supported_apps.dart';
import '../../core/time_utils.dart';
import '../../core/widgets/common.dart';
import '../../data/models/block_rule.dart';
import '../../l10n/l10n.dart';
import '../settings/settings_controller.dart';
import 'app_picker.dart';
import 'rule_texts.dart';
import 'rules_controller.dart';
import 'rules_screen.dart';

const limitChoices = [15, 30, 45, 60, 90, 120];

class RuleEditorScreen extends ConsumerStatefulWidget {
  const RuleEditorScreen({this.initial, super.key});

  /// Rule being edited, or `null` to create a new one.
  final BlockRule? initial;

  @override
  ConsumerState<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends ConsumerState<RuleEditorScreen> {
  late final TextEditingController _name;
  late String _packageName;
  String? _appLabel;
  late bool _nameEdited;
  late BlockMode _mode;
  late int _limit;
  late Set<int> _weekdays;
  late bool _allDay;
  late int _start;
  late int _end;
  late Set<String> _feedTargets;
  late bool _focusOnly;
  List<RuleValidationError> _errors = const [];

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final rule = widget.initial;
    _name = TextEditingController(text: rule?.name ?? '');
    _packageName = rule?.packageName ?? '';
    _appLabel = rule?.appLabel;
    _nameEdited = rule != null;
    _mode = rule?.mode ?? BlockMode.scheduledBlock;
    _limit = rule?.dailyLimitMinutes ?? 30;
    _weekdays = {...?rule?.activeWeekdays};
    _allDay = rule == null || !rule.hasTimeWindow;
    _start = rule?.startMinute ?? 9 * 60;
    _end = rule?.endMinute ?? 17 * 60;
    _feedTargets = {...?rule?.feedTargets};
    _focusOnly = rule?.focusOnly ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  BlockRule _draft() {
    final base =
        widget.initial ??
        BlockRule(id: generateId(), name: '', packageName: '', mode: _mode);
    return base.copyWith(
      name: _name.text.trim(),
      packageName: _packageName,
      appLabel: _appLabel,
      mode: _mode,
      dailyLimitMinutes: _mode == BlockMode.appLimit ? _limit : null,
      activeWeekdays: _weekdays.toList()..sort(),
      startTime: _allDay ? null : formatHm(_start),
      endTime: _allDay ? null : formatHm(_end),
      feedTargets: _mode == BlockMode.selectiveFeed
          ? (_feedTargets.toList()..sort())
          : const [],
      focusOnly: _focusOnly,
    );
  }

  void _autoName() {
    if (_nameEdited || _packageName.isEmpty) return;
    final app = _appLabel ?? _packageName;
    _name.text = context.l10n.defaultRuleName(_mode.label(context.l10n), app);
  }

  Future<void> _pickApp() async {
    final app = await pickApp(context);
    if (app == null || !mounted) return;
    setState(() {
      _packageName = app.packageName;
      _appLabel = app.label;
      final modes = RuleValidation.availableModes(_packageName);
      if (!modes.contains(_mode)) _mode = BlockMode.scheduledBlock;
      _feedTargets = _feedTargets
          .where(
            (id) => KnownApps.feedTargetsFor(
              _packageName,
            ).any((target) => target.id == id),
          )
          .toSet();
      if (_mode == BlockMode.selectiveFeed && _feedTargets.isEmpty) {
        _feedTargets = {
          for (final target in KnownApps.feedTargetsFor(_packageName))
            target.id,
        };
      }
      _autoName();
    });
  }

  void _setMode(BlockMode mode) {
    setState(() {
      _mode = mode;
      if (mode == BlockMode.selectiveFeed && _feedTargets.isEmpty) {
        _feedTargets = {
          for (final target in KnownApps.feedTargetsFor(_packageName))
            target.id,
        };
      }
      _autoName();
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (start) {
        _start = minutes;
      } else {
        _end = minutes;
      }
    });
  }

  void _save() {
    final rule = _draft();
    final errors = RuleValidation.validate(rule);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    ref.read(rulesProvider.notifier).upsert(rule);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final deleted = await confirmDeleteRule(context, ref, widget.initial!);
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final modes = RuleValidation.availableModes(_packageName);
    final feedTargets = KnownApps.feedTargetsFor(_packageName);
    final pauseSeconds = ref.watch(settingsProvider).pauseSeconds;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newRule : l10n.editRule),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: l10n.actionDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            key: const Key('saveRule'),
            onPressed: _save,
            child: Text(l10n.actionSave),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final error in _errors)
                      Text(
                        '• ${validationMessage(l10n, error)}',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          SectionHeader(l10n.ruleAppSection),
          Card(
            child: ListTile(
              key: const Key('pickApp'),
              leading: _packageName.isEmpty
                  ? const Icon(Icons.apps_rounded)
                  : AppIconAvatar(packageName: _packageName),
              title: Text(
                _packageName.isEmpty
                    ? l10n.chooseApp
                    : (_appLabel ?? _packageName),
              ),
              subtitle: _packageName.isEmpty ? null : Text(_packageName),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickApp,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('ruleName'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.ruleNameLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _nameEdited = true,
          ),
          SectionHeader(l10n.ruleModeSection),
          Card(
            child: RadioGroup<BlockMode>(
              groupValue: _mode,
              onChanged: (mode) {
                if (mode != null) _setMode(mode);
              },
              child: Column(
                children: [
                  for (final mode in BlockMode.values)
                    RadioListTile<BlockMode>(
                      key: Key('mode-${mode.name}'),
                      value: mode,
                      enabled: modes.contains(mode),
                      secondary: Icon(mode.icon),
                      title: Text(mode.label(l10n)),
                      subtitle: Text(
                        modes.contains(mode)
                            ? mode.description(l10n)
                            : l10n.modeUnavailableForApp,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_mode == BlockMode.appLimit) ...[
            SectionHeader(l10n.dailyLimitSection),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in limitChoices)
                  ChoiceChip(
                    label: Text(l10n.minutesShort(minutes)),
                    selected: _limit == minutes,
                    onSelected: (_) => setState(() => _limit = minutes),
                  ),
              ],
            ),
            Slider(
              value: _limit.toDouble().clamp(5, 240),
              min: 5,
              max: 240,
              divisions: 47,
              label: l10n.minutesShort(_limit),
              onChanged: (value) => setState(() => _limit = value.round()),
            ),
            Text(
              l10n.limitPerDay(_limit),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (_mode == BlockMode.selectiveFeed) ...[
            SectionHeader(l10n.feedSection),
            for (final target in feedTargets)
              CheckboxListTile(
                value: _feedTargets.contains(target.id),
                title: Text(feedTargetLabel(l10n, target.id)),
                subtitle: Text(supportLevelLabel(l10n, target.level)),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _feedTargets.add(target.id);
                  } else {
                    _feedTargets.remove(target.id);
                  }
                }),
              ),
            Text(
              l10n.feedExperimentalNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_mode == BlockMode.pauseScreen)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                l10n.pauseLengthNote(pauseSeconds),
                style: theme.textTheme.bodySmall,
              ),
            ),
          SectionHeader(l10n.scheduleSection),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.onlyDuringFocus),
            subtitle: Text(l10n.onlyDuringFocusDescription),
            value: _focusOnly,
            onChanged: (value) => setState(() => _focusOnly = value),
          ),
          if (!_focusOnly) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(shortWeekdayName(context, day)),
                    selected: _weekdays.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _weekdays.add(day);
                      } else {
                        _weekdays.remove(day);
                      }
                    }),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _weekdays.isEmpty
                    ? l10n.everyDay
                    : weekdaysLabel(context, _weekdays.toList()),
                style: theme.textTheme.bodySmall,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.allDay),
              value: _allDay,
              onChanged: (value) => setState(() => _allDay = value),
            ),
            if (!_allDay)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        l10n.fromTime(formatMinuteOfDay(context, _start)),
                      ),
                      onPressed: () => _pickTime(start: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        l10n.untilTime(formatMinuteOfDay(context, _end)),
                      ),
                      onPressed: () => _pickTime(start: false),
                    ),
                  ),
                ],
              ),
            if (!_allDay && _end < _start)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.overnightNote,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          SectionHeader(l10n.capabilitySection),
          _CapabilityCard(mode: _mode),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.mode});

  final BlockMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final permissions = RuleValidation.requiredPermissions(mode);
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.whatItControls, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(mode.description(l10n)),
          const SizedBox(height: 12),
          Text(l10n.requiredPermissions, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            permissions.isEmpty
                ? l10n.noPermissionsNeeded
                : permissions.map((p) => permissionLabel(l10n, p)).join(', '),
          ),
          if (mode == BlockMode.allowException) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => showPrecedenceDialog(context),
              child: Text(l10n.precedenceTitle),
            ),
          ],
        ],
      ),
    );
  }
}
