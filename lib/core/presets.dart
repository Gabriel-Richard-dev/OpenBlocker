import '../data/models/block_rule.dart';
import 'ids.dart';
import 'supported_apps.dart';

enum PresetId { studyMode, noShorts, socialMediaLimit, deepFocus, custom }

/// Platforms on which a preset's rules can actually be enforced.
class PresetSupport {
  const PresetSupport({required this.android, required this.ios});

  final bool android;
  final bool ios;
}

class Preset {
  const Preset({required this.id, required this.support});

  final PresetId id;
  final PresetSupport support;

  /// Builds the preset's rules for the apps that are installed.
  ///
  /// [installed] maps package names to the app names shown by the launcher.
  /// [ruleName] produces a localized rule name for the given app label.
  List<BlockRule> build({
    required Map<String, String> installed,
    required String Function(String appLabel) ruleName,
    IdGenerator newId = generateId,
  }) {
    BlockRule rule(
      String packageName,
      BlockMode mode, {
      int? limit,
      List<int> weekdays = const [],
      String? start,
      String? end,
      List<String> feedTargets = const [],
      bool focusOnly = false,
    }) {
      final label = installed[packageName] ?? packageName;
      return BlockRule(
        id: newId(),
        name: ruleName(label),
        packageName: packageName,
        appLabel: label,
        mode: mode,
        dailyLimitMinutes: limit,
        activeWeekdays: weekdays,
        startTime: start,
        endTime: end,
        feedTargets: feedTargets,
        focusOnly: focusOnly,
      );
    }

    final distracting = [
      for (final packageName in installed.keys)
        if (KnownApps.isDistracting(packageName)) packageName,
    ];

    switch (id) {
      case PresetId.studyMode:
        return [
          for (final packageName in distracting)
            rule(
              packageName,
              BlockMode.pauseScreen,
              weekdays: const [1, 2, 3, 4, 5],
              start: '08:00',
              end: '18:00',
            ),
        ];
      case PresetId.noShorts:
        return [
          for (final packageName in distracting)
            if (KnownApps.feedTargetsFor(packageName).isNotEmpty)
              rule(
                packageName,
                BlockMode.selectiveFeed,
                feedTargets: [
                  for (final target in KnownApps.feedTargetsFor(packageName))
                    target.id,
                ],
              )
            else if (KnownApps.byPackage(packageName)?.category ==
                AppCategory.video)
              rule(packageName, BlockMode.pauseScreen),
        ];
      case PresetId.socialMediaLimit:
        return [
          for (final packageName in distracting)
            rule(packageName, BlockMode.appLimit, limit: 30),
        ];
      case PresetId.deepFocus:
        return [
          for (final packageName in distracting)
            rule(packageName, BlockMode.scheduledBlock, focusOnly: true),
        ];
      case PresetId.custom:
        return const [];
    }
  }
}

abstract final class Presets {
  static const _androidOnly = PresetSupport(android: true, ios: false);

  static const all = [
    Preset(id: PresetId.studyMode, support: _androidOnly),
    Preset(id: PresetId.noShorts, support: _androidOnly),
    Preset(id: PresetId.socialMediaLimit, support: _androidOnly),
    Preset(id: PresetId.deepFocus, support: _androidOnly),
    Preset(id: PresetId.custom, support: _androidOnly),
  ];
}
