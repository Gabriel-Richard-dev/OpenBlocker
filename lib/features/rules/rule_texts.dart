import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/presets.dart';
import '../../core/rule_engine.dart';
import '../../core/rule_validation.dart';
import '../../core/supported_apps.dart';
import '../../core/time_utils.dart';
import '../../data/models/block_rule.dart';
import '../../l10n/l10n.dart';

extension BlockModeTexts on BlockMode {
  String label(AppLocalizations l10n) => switch (this) {
    BlockMode.appLimit => l10n.modeAppLimit,
    BlockMode.scheduledBlock => l10n.modeScheduledBlock,
    BlockMode.selectiveFeed => l10n.modeSelectiveFeed,
    BlockMode.pauseScreen => l10n.modePauseScreen,
    BlockMode.allowException => l10n.modeAllowException,
  };

  /// What the mode effectively controls, shown before saving a rule.
  String description(AppLocalizations l10n) => switch (this) {
    BlockMode.appLimit => l10n.modeAppLimitDescription,
    BlockMode.scheduledBlock => l10n.modeScheduledBlockDescription,
    BlockMode.selectiveFeed => l10n.modeSelectiveFeedDescription,
    BlockMode.pauseScreen => l10n.modePauseScreenDescription,
    BlockMode.allowException => l10n.modeAllowExceptionDescription,
  };

  IconData get icon => switch (this) {
    BlockMode.appLimit => Icons.hourglass_bottom_rounded,
    BlockMode.scheduledBlock => Icons.block_rounded,
    BlockMode.selectiveFeed => Icons.view_day_rounded,
    BlockMode.pauseScreen => Icons.self_improvement_rounded,
    BlockMode.allowException => Icons.check_circle_outline_rounded,
  };
}

String feedTargetLabel(AppLocalizations l10n, String id) => switch (id) {
  'youtube.shorts' => l10n.feedYoutubeShorts,
  'instagram.reels' => l10n.feedInstagramReels,
  _ => id,
};

String supportLevelLabel(AppLocalizations l10n, SupportLevel level) =>
    switch (level) {
      SupportLevel.verified => l10n.supportVerified,
      SupportLevel.experimental => l10n.supportExperimental,
    };

String permissionLabel(AppLocalizations l10n, RequiredPermission permission) =>
    switch (permission) {
      RequiredPermission.accessibility => l10n.permissionAccessibility,
      RequiredPermission.usageAccess => l10n.permissionUsageAccess,
    };

String validationMessage(
  AppLocalizations l10n,
  RuleValidationError error,
) => switch (error) {
  RuleValidationError.missingName => l10n.errorMissingName,
  RuleValidationError.missingApp => l10n.errorMissingApp,
  RuleValidationError.invalidLimit => l10n.errorInvalidLimit,
  RuleValidationError.incompleteTimeWindow => l10n.errorIncompleteTimeWindow,
  RuleValidationError.invalidTime => l10n.errorInvalidTime,
  RuleValidationError.invalidWeekday => l10n.errorInvalidWeekday,
  RuleValidationError.missingFeedTarget => l10n.errorMissingFeedTarget,
  RuleValidationError.unsupportedFeedTarget => l10n.errorUnsupportedFeedTarget,
};

String presetName(AppLocalizations l10n, PresetId id) => switch (id) {
  PresetId.studyMode => l10n.presetStudyMode,
  PresetId.noShorts => l10n.presetNoShorts,
  PresetId.socialMediaLimit => l10n.presetSocialMediaLimit,
  PresetId.deepFocus => l10n.presetDeepFocus,
  PresetId.custom => l10n.presetCustom,
};

String presetDescription(AppLocalizations l10n, PresetId id) => switch (id) {
  PresetId.studyMode => l10n.presetStudyModeDescription,
  PresetId.noShorts => l10n.presetNoShortsDescription,
  PresetId.socialMediaLimit => l10n.presetSocialMediaLimitDescription,
  PresetId.deepFocus => l10n.presetDeepFocusDescription,
  PresetId.custom => l10n.presetCustomDescription,
};

IconData presetIcon(PresetId id) => switch (id) {
  PresetId.studyMode => Icons.school_rounded,
  PresetId.noShorts => Icons.video_library_rounded,
  PresetId.socialMediaLimit => Icons.timer_rounded,
  PresetId.deepFocus => Icons.center_focus_strong_rounded,
  PresetId.custom => Icons.tune_rounded,
};

/// "Mon, Tue, Wed" style list using the locale's narrow weekday names.
String weekdaysLabel(BuildContext context, List<int> weekdays) {
  final l10n = context.l10n;
  if (weekdays.isEmpty || weekdays.toSet().length == 7) return l10n.everyDay;
  final sorted = weekdays.toSet().toList()..sort();
  if (sorted.length == 5 && sorted.every((day) => day <= 5)) {
    return l10n.weekdaysOnly;
  }
  if (sorted.length == 2 && sorted.first == 6 && sorted.last == 7) {
    return l10n.weekendsOnly;
  }
  return sorted.map((day) => shortWeekdayName(context, day)).join(', ');
}

/// Short weekday name for an ISO weekday (1 = Monday).
String shortWeekdayName(BuildContext context, int weekday) {
  final locale = Localizations.localeOf(context).toString();
  // 1 January 2024 was a Monday.
  return DateFormat.E(locale).format(DateTime(2024, 1, weekday));
}

String formatMinuteOfDay(BuildContext context, int minuteOfDay) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// One-line summary such as "30 min per day · Mon–Fri · 09:00–17:00".
String ruleSummary(BuildContext context, BlockRule rule) {
  final l10n = context.l10n;
  final parts = <String>[rule.mode.label(l10n)];
  if (rule.mode == BlockMode.appLimit && rule.dailyLimitMinutes != null) {
    parts.add(l10n.limitPerDay(rule.dailyLimitMinutes!));
  }
  if (rule.mode == BlockMode.selectiveFeed) {
    parts.add(
      rule.feedTargets.map((id) => feedTargetLabel(l10n, id)).join(', '),
    );
  }
  if (rule.focusOnly) {
    parts.add(l10n.onlyDuringFocusShort);
  } else {
    parts.add(weekdaysLabel(context, rule.activeWeekdays));
    final start = parseHm(rule.startTime);
    final end = parseHm(rule.endTime);
    if (start != null && end != null && start != end) {
      parts.add(
        '${formatMinuteOfDay(context, start)}–${formatMinuteOfDay(context, end)}',
      );
    }
  }
  return parts.join(' · ');
}

String activationLabel(
  BuildContext context,
  BlockRule rule,
  RuleActivation activation, {
  int? snoozedUntilMs,
  int? usageMinutes,
}) {
  final l10n = context.l10n;
  switch (activation) {
    case RuleActivation.disabled:
      return l10n.ruleStatusDisabled;
    case RuleActivation.paused:
      final untilMs = [
        ?rule.pausedUntilMs,
        ?snoozedUntilMs,
      ].fold<int>(0, (max, value) => value > max ? value : max);
      final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
      return l10n.ruleStatusPausedUntil(
        formatMinuteOfDay(context, until.hour * 60 + until.minute),
      );
    case RuleActivation.focusOnlyIdle:
      return l10n.ruleStatusWaitingForFocus;
    case RuleActivation.outsideSchedule:
      return l10n.ruleStatusOutsideSchedule;
    case RuleActivation.active:
    case RuleActivation.activeByFocus:
      if (rule.mode == BlockMode.appLimit) {
        final limit = rule.dailyLimitMinutes ?? 0;
        if (usageMinutes == null) return l10n.ruleStatusLimitUnknown;
        if (usageMinutes >= limit) return l10n.ruleStatusLimitReached;
        return l10n.ruleStatusLimitProgress(usageMinutes, limit);
      }
      return activation == RuleActivation.activeByFocus
          ? l10n.ruleStatusActiveFocus
          : l10n.ruleStatusActive;
  }
}
