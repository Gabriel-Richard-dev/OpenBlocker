import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/platform_models.dart';
import '../../data/providers.dart';
import '../../data/repositories/focus_repository.dart';

export '../../data/repositories/focus_repository.dart' show FocusState;

final focusProvider = NotifierProvider<FocusController, FocusState>(
  FocusController.new,
);

class FocusController extends Notifier<FocusState> {
  static const presetsMinutes = [25, 45, 60];

  @override
  FocusState build() {
    ref.listen<AsyncValue<RuntimeState>>(runtimeStateProvider, (_, next) {
      final runtime = next.value;
      if (runtime != null) applyRuntime(runtime);
    });
    return _reconciled(ref.read(initialDataProvider).focus);
  }

  DateTime get _now => ref.read(clockProvider)();

  void _set(FocusState next) {
    state = next;
    unawaited(ref.read(focusRepositoryProvider).save(next));
  }

  /// The session that is running right now, if any.
  FocusSession? get activeSession {
    final active = state.active;
    return active != null && active.isActiveAt(_now) ? active : null;
  }

  FocusSession start({
    required Duration duration,
    required List<String> ruleIds,
  }) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must be positive');
    }
    final now = _now;
    final current = state.active;
    final history = current == null
        ? state.history
        : [current.finish(now), ...state.history];
    final session = FocusSession(
      id: generateId(),
      startedAt: now,
      plannedEndAt: now.add(duration),
      activeRuleIds: List.unmodifiable(ruleIds),
    );
    _set(FocusState(active: session, history: history));
    return session;
  }

  /// Ends the running session early. Rules activated only by the session stop
  /// applying immediately.
  void stop() => _finishAt(_now);

  /// Moves a session that passed its planned end into the history.
  void reconcile() {
    final next = _reconciled(state);
    if (!identical(next, state)) _set(next);
  }

  /// Applies an early end triggered from the native intervention screen.
  void applyRuntime(RuntimeState runtime) {
    final active = state.active;
    final endedAtMs = runtime.endedFocusAtMs;
    if (active == null ||
        runtime.endedFocusId != active.id ||
        endedAtMs == null) {
      return;
    }
    _finishAt(DateTime.fromMillisecondsSinceEpoch(endedAtMs));
  }

  void clearHistory() => _set(FocusState(active: state.active));

  /// Drops the running session and the history.
  void resetAll() => _set(FocusState.empty);

  void _finishAt(DateTime at) {
    final active = state.active;
    if (active == null) return;
    _set(FocusState(history: [active.finish(at), ...state.history]));
  }

  FocusState _reconciled(FocusState current) {
    final active = current.active;
    if (active == null || _now.isBefore(active.plannedEndAt)) return current;
    final finished = active.finish(active.plannedEndAt);
    return FocusState(history: [finished, ...current.history]);
  }
}
