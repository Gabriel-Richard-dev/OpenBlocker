import '../../data/models/block_rule.dart';
import '../../data/models/platform_models.dart';

enum ProtectionIssue {
  /// Enforcement is not implemented on this platform.
  unsupportedPlatform,

  /// The accessibility service is turned off; nothing is enforced.
  accessibilityOff,

  /// The service is enabled but the system is not running it.
  accessibilityStopped,

  /// Daily limits cannot be measured without usage access.
  usageAccessMissing,
}

enum ProtectionLevel { noRules, working, partial, notWorking, unknown }

class ProtectionStatus {
  const ProtectionStatus({required this.level, this.issues = const []});

  final ProtectionLevel level;
  final List<ProtectionIssue> issues;

  static ProtectionStatus compute(
    List<BlockRule> rules,
    PermissionSnapshot? permissions,
  ) {
    final enabled = rules.where((rule) => rule.enabled).toList();
    if (enabled.isEmpty) {
      return const ProtectionStatus(level: ProtectionLevel.noRules);
    }
    if (permissions == null) {
      return const ProtectionStatus(level: ProtectionLevel.unknown);
    }
    if (!permissions.platformSupported) {
      return const ProtectionStatus(
        level: ProtectionLevel.notWorking,
        issues: [ProtectionIssue.unsupportedPlatform],
      );
    }
    final issues = <ProtectionIssue>[];
    if (!permissions.accessibilityEnabled) {
      issues.add(ProtectionIssue.accessibilityOff);
    } else if (!permissions.accessibilityRunning) {
      issues.add(ProtectionIssue.accessibilityStopped);
    }
    final needsUsage = enabled.any((rule) => rule.mode == BlockMode.appLimit);
    if (needsUsage && !permissions.usageAccessGranted) {
      issues.add(ProtectionIssue.usageAccessMissing);
    }
    if (issues.contains(ProtectionIssue.accessibilityOff) ||
        issues.contains(ProtectionIssue.accessibilityStopped)) {
      return ProtectionStatus(
        level: ProtectionLevel.notWorking,
        issues: issues,
      );
    }
    return ProtectionStatus(
      level: issues.isEmpty ? ProtectionLevel.working : ProtectionLevel.partial,
      issues: issues,
    );
  }
}
