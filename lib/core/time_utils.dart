/// Helpers for the `HH:mm` wall-clock strings used by rule schedules.
///
/// Schedules are evaluated in the device's local time zone. Instants such as
/// focus session boundaries are stored as UTC epoch milliseconds, so they are
/// not affected by time zone changes or device reboots.
library;

const int minutesPerDay = 24 * 60;

/// Parses `HH:mm` into minutes since midnight. Returns `null` when [value] is
/// `null` or malformed.
int? parseHm(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// Formats minutes since midnight as `HH:mm`.
String formatHm(int minuteOfDay) {
  final normalized = minuteOfDay % minutesPerDay;
  final h = (normalized ~/ 60).toString().padLeft(2, '0');
  final m = (normalized % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// ISO weekday (1 = Monday … 7 = Sunday) of the day before [weekday].
int previousWeekday(int weekday) => weekday == 1 ? 7 : weekday - 1;

/// Local midnight of the day containing [time].
DateTime startOfDay(DateTime time) => DateTime(time.year, time.month, time.day);
