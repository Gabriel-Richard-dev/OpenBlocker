import 'package:flutter/foundation.dart';

/// A focus session. Instants are stored as UTC epoch milliseconds so a session
/// survives time zone changes and device reboots unchanged.
@immutable
class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.plannedEndAt,
    required this.activeRuleIds,
    this.completed = false,
    this.endedAt,
  });

  factory FocusSession.fromJson(Map<String, Object?> json) {
    final endedAtMs = (json['endedAtMs'] as num?)?.toInt();
    return FocusSession(
      id: json['id']! as String,
      startedAt: _fromMs((json['startedAtMs']! as num).toInt()),
      plannedEndAt: _fromMs((json['plannedEndAtMs']! as num).toInt()),
      activeRuleIds: [
        for (final id in json['activeRuleIds'] as List<Object?>? ?? const [])
          id! as String,
      ],
      completed: json['completed'] as bool? ?? false,
      endedAt: endedAtMs == null ? null : _fromMs(endedAtMs),
    );
  }

  final String id;
  final DateTime startedAt;
  final DateTime plannedEndAt;

  /// Rules enforced during the session regardless of their own schedule.
  final List<String> activeRuleIds;

  /// True when the session reached [plannedEndAt] without being stopped.
  final bool completed;

  /// When the session finished (planned end or early stop). `null` while the
  /// session is still running.
  final DateTime? endedAt;

  Duration get plannedDuration => plannedEndAt.difference(startedAt);

  bool isActiveAt(DateTime now) =>
      endedAt == null && !now.isBefore(startedAt) && now.isBefore(plannedEndAt);

  /// Time left before the planned end, never negative.
  Duration remainingAt(DateTime now) {
    if (!isActiveAt(now)) return Duration.zero;
    return plannedEndAt.difference(now);
  }

  /// Time actually spent in the session, never negative and never more than
  /// planned.
  Duration elapsedAt(DateTime now) {
    final end = endedAt ?? (now.isBefore(plannedEndAt) ? now : plannedEndAt);
    final elapsed = end.difference(startedAt);
    if (elapsed.isNegative) return Duration.zero;
    return elapsed > plannedDuration ? plannedDuration : elapsed;
  }

  /// Fraction of the planned duration already elapsed, between 0 and 1.
  double progressAt(DateTime now) {
    final planned = plannedDuration.inMilliseconds;
    if (planned <= 0) return 1;
    return (elapsedAt(now).inMilliseconds / planned).clamp(0.0, 1.0);
  }

  FocusSession finish(DateTime at) {
    final reachedEnd = !at.isBefore(plannedEndAt);
    return FocusSession(
      id: id,
      startedAt: startedAt,
      plannedEndAt: plannedEndAt,
      activeRuleIds: activeRuleIds,
      completed: reachedEnd,
      endedAt: reachedEnd ? plannedEndAt : at,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'startedAtMs': startedAt.millisecondsSinceEpoch,
    'plannedEndAtMs': plannedEndAt.millisecondsSinceEpoch,
    'activeRuleIds': activeRuleIds,
    'completed': completed,
    'endedAtMs': endedAt?.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is FocusSession &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.plannedEndAt == plannedEndAt &&
      listEquals(other.activeRuleIds, activeRuleIds) &&
      other.completed == completed &&
      other.endedAt == endedAt;

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    plannedEndAt,
    Object.hashAll(activeRuleIds),
    completed,
    endedAt,
  );
}

DateTime _fromMs(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
