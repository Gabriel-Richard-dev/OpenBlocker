import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rule_validation.dart';
import '../../data/models/block_rule.dart';
import '../../data/providers.dart';

final rulesProvider = NotifierProvider<RulesController, List<BlockRule>>(
  RulesController.new,
);

class InvalidRuleException implements Exception {
  const InvalidRuleException(this.errors);

  final List<RuleValidationError> errors;

  @override
  String toString() => 'InvalidRuleException($errors)';
}

class RulesController extends Notifier<List<BlockRule>> {
  @override
  List<BlockRule> build() => ref.read(initialDataProvider).rules;

  void _set(List<BlockRule> next) {
    state = List.unmodifiable(next);
    unawaited(ref.read(rulesRepositoryProvider).save(state));
  }

  BlockRule? byId(String id) {
    for (final rule in state) {
      if (rule.id == id) return rule;
    }
    return null;
  }

  /// Adds or replaces a rule. Throws [InvalidRuleException] when invalid.
  void upsert(BlockRule rule) {
    final errors = RuleValidation.validate(rule);
    if (errors.isNotEmpty) throw InvalidRuleException(errors);
    final index = state.indexWhere((existing) => existing.id == rule.id);
    if (index == -1) {
      _set([...state, rule]);
    } else {
      _set([...state]..[index] = rule);
    }
  }

  /// Adds several valid rules at once (presets, imports). Invalid rules are
  /// skipped; the number of added rules is returned.
  int addAll(Iterable<BlockRule> rules) {
    final valid = [
      for (final rule in rules)
        if (RuleValidation.validate(rule).isEmpty) rule,
    ];
    if (valid.isNotEmpty) _set([...state, ...valid]);
    return valid.length;
  }

  void replaceAll(Iterable<BlockRule> rules) => _set([
    for (final rule in rules)
      if (RuleValidation.validate(rule).isEmpty) rule,
  ]);

  void remove(String id) => _set([
    for (final rule in state)
      if (rule.id != id) rule,
  ]);

  void setEnabled(String id, bool enabled) => _update(
    id,
    (rule) => rule.copyWith(enabled: enabled, pausedUntilMs: null),
  );

  /// Temporarily disables a rule until [until].
  void pauseUntil(String id, DateTime until) => _update(
    id,
    (rule) => rule.copyWith(pausedUntilMs: until.millisecondsSinceEpoch),
  );

  /// Ends a temporary pause and any snooze set from the intervention screen.
  void resume(String id) {
    _update(id, (rule) => rule.copyWith(pausedUntilMs: null));
    unawaited(ref.read(platformProvider).clearSnooze(id));
    ref.invalidate(runtimeStateProvider);
  }

  void _update(String id, BlockRule Function(BlockRule rule) change) {
    _set([for (final rule in state) rule.id == id ? change(rule) : rule]);
  }
}
