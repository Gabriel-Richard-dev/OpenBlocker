import 'package:flutter/foundation.dart';

import '../../core/time_utils.dart';

/// How a rule acts on its target app.
///
/// The JSON names of these values are shared with the native Android rule
/// engine (`RuleModels.kt`). Renaming one is a breaking change that needs a
/// storage migration.
enum BlockMode {
  /// Block the app once its measured usage today reaches a daily limit.
  appLimit,

  /// Block the whole app while the rule is active.
  scheduledBlock,

  /// Block only a specific feed (e.g. YouTube Shorts) through an app adapter.
  selectiveFeed,

  /// Show a short pause screen before the app can be used.
  pauseScreen,

  /// Exception: while active, no other rule applies to the app.
  allowException;

  static BlockMode fromName(String name) => BlockMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => throw FormatException('Unknown block mode: $name'),
  );

  /// Whether this mode restricts the app (everything except exceptions).
  bool get restricts => this != allowException;
}

const Object _unset = Object();

/// A user-defined rule for one installed app.
@immutable
class BlockRule {
  const BlockRule({
    required this.id,
    required this.name,
    required this.packageName,
    required this.mode,
    this.appLabel,
    this.enabled = true,
    this.dailyLimitMinutes,
    this.activeWeekdays = const [],
    this.startTime,
    this.endTime,
    this.feedTargets = const [],
    this.focusOnly = false,
    this.pausedUntilMs,
  });

  factory BlockRule.fromJson(Map<String, Object?> json) {
    return BlockRule(
      id: json['id']! as String,
      name: json['name']! as String,
      packageName: json['packageName']! as String,
      appLabel: json['appLabel'] as String?,
      mode: BlockMode.fromName(json['mode']! as String),
      enabled: json['enabled'] as bool? ?? true,
      dailyLimitMinutes: (json['dailyLimitMinutes'] as num?)?.toInt(),
      activeWeekdays: [
        for (final day in json['activeWeekdays'] as List<Object?>? ?? const [])
          (day! as num).toInt(),
      ],
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      feedTargets: [
        for (final target in json['feedTargets'] as List<Object?>? ?? const [])
          target! as String,
      ],
      focusOnly: json['focusOnly'] as bool? ?? false,
      pausedUntilMs: (json['pausedUntilMs'] as num?)?.toInt(),
    );
  }

  final String id;
  final String name;

  /// Android package name of the target app, e.g. `com.google.android.youtube`.
  final String packageName;

  /// Human readable app name captured when the rule was created.
  final String? appLabel;
  final BlockMode mode;
  final bool enabled;

  /// Daily limit for [BlockMode.appLimit].
  final int? dailyLimitMinutes;

  /// ISO weekdays (1 = Monday … 7 = Sunday). Empty means every day.
  final List<int> activeWeekdays;

  /// Start of the daily window as `HH:mm`. When [startTime] or [endTime] is
  /// `null` the rule applies all day. A window where start > end crosses
  /// midnight; start == end means all day.
  final String? startTime;
  final String? endTime;

  /// Feed identifiers for [BlockMode.selectiveFeed], e.g. `youtube.shorts`.
  final List<String> feedTargets;

  /// When true the rule only applies during focus sessions that include it.
  final bool focusOnly;

  /// The rule is temporarily disabled until this UTC epoch millisecond.
  final int? pausedUntilMs;

  bool get hasTimeWindow => startTime != null && endTime != null;

  int? get startMinute => parseHm(startTime);
  int? get endMinute => parseHm(endTime);

  bool isPausedAt(int nowMs) => pausedUntilMs != null && pausedUntilMs! > nowMs;

  String get displayAppName => appLabel ?? packageName;

  BlockRule copyWith({
    String? id,
    String? name,
    String? packageName,
    Object? appLabel = _unset,
    BlockMode? mode,
    bool? enabled,
    Object? dailyLimitMinutes = _unset,
    List<int>? activeWeekdays,
    Object? startTime = _unset,
    Object? endTime = _unset,
    List<String>? feedTargets,
    bool? focusOnly,
    Object? pausedUntilMs = _unset,
  }) {
    return BlockRule(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      appLabel: identical(appLabel, _unset)
          ? this.appLabel
          : appLabel as String?,
      mode: mode ?? this.mode,
      enabled: enabled ?? this.enabled,
      dailyLimitMinutes: identical(dailyLimitMinutes, _unset)
          ? this.dailyLimitMinutes
          : dailyLimitMinutes as int?,
      activeWeekdays: activeWeekdays ?? this.activeWeekdays,
      startTime: identical(startTime, _unset)
          ? this.startTime
          : startTime as String?,
      endTime: identical(endTime, _unset) ? this.endTime : endTime as String?,
      feedTargets: feedTargets ?? this.feedTargets,
      focusOnly: focusOnly ?? this.focusOnly,
      pausedUntilMs: identical(pausedUntilMs, _unset)
          ? this.pausedUntilMs
          : pausedUntilMs as int?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'packageName': packageName,
    'appLabel': appLabel,
    'mode': mode.name,
    'enabled': enabled,
    'dailyLimitMinutes': dailyLimitMinutes,
    'activeWeekdays': activeWeekdays,
    'startTime': startTime,
    'endTime': endTime,
    'feedTargets': feedTargets,
    'focusOnly': focusOnly,
    'pausedUntilMs': pausedUntilMs,
  };

  @override
  bool operator ==(Object other) =>
      other is BlockRule &&
      other.id == id &&
      other.name == name &&
      other.packageName == packageName &&
      other.appLabel == appLabel &&
      other.mode == mode &&
      other.enabled == enabled &&
      other.dailyLimitMinutes == dailyLimitMinutes &&
      listEquals(other.activeWeekdays, activeWeekdays) &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      listEquals(other.feedTargets, feedTargets) &&
      other.focusOnly == focusOnly &&
      other.pausedUntilMs == pausedUntilMs;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    packageName,
    appLabel,
    mode,
    enabled,
    dailyLimitMinutes,
    Object.hashAll(activeWeekdays),
    startTime,
    endTime,
    Object.hashAll(feedTargets),
    focusOnly,
    pausedUntilMs,
  );

  @override
  String toString() => 'BlockRule($id, $name, $packageName, ${mode.name})';
}
