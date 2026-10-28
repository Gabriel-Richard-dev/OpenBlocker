import '../data/models/block_rule.dart';
import 'supported_apps.dart';
import 'time_utils.dart';

enum RuleValidationError {
  missingName,
  missingApp,
  invalidLimit,
  incompleteTimeWindow,
  invalidTime,
  invalidWeekday,
  missingFeedTarget,
  unsupportedFeedTarget,
}

enum RequiredPermission { accessibility, usageAccess }

const int maxDailyLimitMinutes = 24 * 60;

abstract final class RuleValidation {
  static List<RuleValidationError> validate(BlockRule rule) {
    final errors = <RuleValidationError>[];
    if (rule.name.trim().isEmpty) errors.add(RuleValidationError.missingName);
    if (rule.packageName.trim().isEmpty) {
      errors.add(RuleValidationError.missingApp);
    }
    if (rule.mode == BlockMode.appLimit) {
      final limit = rule.dailyLimitMinutes;
      if (limit == null || limit < 1 || limit > maxDailyLimitMinutes) {
        errors.add(RuleValidationError.invalidLimit);
      }
    }
    if ((rule.startTime == null) != (rule.endTime == null)) {
      errors.add(RuleValidationError.incompleteTimeWindow);
    } else if (rule.hasTimeWindow &&
        (parseHm(rule.startTime) == null || parseHm(rule.endTime) == null)) {
      errors.add(RuleValidationError.invalidTime);
    }
    if (rule.activeWeekdays.any((day) => day < 1 || day > 7)) {
      errors.add(RuleValidationError.invalidWeekday);
    }
    if (rule.mode == BlockMode.selectiveFeed) {
      if (rule.feedTargets.isEmpty) {
        errors.add(RuleValidationError.missingFeedTarget);
      } else {
        final supported = KnownApps.feedTargetsFor(
          rule.packageName,
        ).map((target) => target.id).toSet();
        if (!rule.feedTargets.every(supported.contains)) {
          errors.add(RuleValidationError.unsupportedFeedTarget);
        }
      }
    }
    return errors;
  }

  /// Permissions the rule needs to be enforced on Android.
  static List<RequiredPermission> requiredPermissions(BlockMode mode) {
    return switch (mode) {
      BlockMode.appLimit => const [
        RequiredPermission.accessibility,
        RequiredPermission.usageAccess,
      ],
      BlockMode.scheduledBlock ||
      BlockMode.selectiveFeed ||
      BlockMode.pauseScreen => const [RequiredPermission.accessibility],
      BlockMode.allowException => const [],
    };
  }

  /// Modes that are available for [packageName].
  static List<BlockMode> availableModes(String packageName) => [
    for (final mode in BlockMode.values)
      if (mode != BlockMode.selectiveFeed ||
          KnownApps.feedTargetsFor(packageName).isNotEmpty)
        mode,
  ];
}
