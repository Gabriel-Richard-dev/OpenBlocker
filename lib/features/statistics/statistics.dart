import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_utils.dart';
import '../../data/models/focus_session.dart';
import '../../data/models/platform_models.dart';
import '../../data/providers.dart';
import '../rules/rules_controller.dart';

const statisticsDays = 7;

/// Measured usage for the apps that have rules, oldest day first. `null` when
/// usage access is not granted.
final dailyUsageProvider = FutureProvider<List<DailyUsage>?>((ref) async {
  final packagesKey = ref.watch(
    rulesProvider.select(
      (rules) =>
          (rules.map((rule) => rule.packageName).toSet().toList()..sort()).join(
            ',',
          ),
    ),
  );
  if (packagesKey.isEmpty) return const [];
  return ref
      .watch(platformProvider)
      .getDailyUsage(packages: packagesKey.split(','), days: statisticsDays);
});

/// Local days ending today, oldest first.
List<DateTime> lastDays(DateTime today, int count) {
  final end = startOfDay(today);
  return [
    for (var offset = count - 1; offset >= 0; offset--)
      DateTime(end.year, end.month, end.day - offset),
  ];
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<int> interventionsPerDay(
  List<InterventionEvent> events,
  List<DateTime> days,
) => [
  for (final day in days)
    events.where((event) => isSameDay(event.at, day)).length,
];

/// Minutes spent in focus sessions per day. A session is attributed to the day
/// it started.
List<int> focusMinutesPerDay(
  List<FocusSession> sessions,
  List<DateTime> days,
  DateTime now,
) => [
  for (final day in days)
    sessions
        .where((session) => isSameDay(session.startedAt, day))
        .fold(0, (sum, session) => sum + session.elapsedAt(now).inMinutes),
];

int completedSessionsSince(List<FocusSession> sessions, DateTime since) =>
    sessions
        .where(
          (session) => session.completed && !session.startedAt.isBefore(since),
        )
        .length;

/// Number of interventions per rule id, most frequent first.
List<MapEntry<String, int>> interventionsByRule(
  List<InterventionEvent> events,
) {
  final counts = <String, int>{};
  for (final event in events) {
    counts[event.ruleId] = (counts[event.ruleId] ?? 0) + 1;
  }
  return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
