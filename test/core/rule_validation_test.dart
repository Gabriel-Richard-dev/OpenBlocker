import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/core/presets.dart';
import 'package:openblock/core/rule_validation.dart';
import 'package:openblock/core/supported_apps.dart';
import 'package:openblock/data/models/block_rule.dart';

const youtube = 'com.google.android.youtube';

BlockRule base({BlockMode mode = BlockMode.scheduledBlock}) =>
    BlockRule(id: 'r', name: 'Rule', packageName: youtube, mode: mode);

void main() {
  group('RuleValidation.validate', () {
    test('accepts a simple rule', () {
      expect(RuleValidation.validate(base()), isEmpty);
    });

    test('requires a name and an app', () {
      final errors = RuleValidation.validate(
        base().copyWith(name: '  ', packageName: ''),
      );
      expect(
        errors,
        containsAll([
          RuleValidationError.missingName,
          RuleValidationError.missingApp,
        ]),
      );
    });

    test('limits need a value between 1 and 1440', () {
      final rule = base(mode: BlockMode.appLimit);
      expect(
        RuleValidation.validate(rule),
        contains(RuleValidationError.invalidLimit),
      );
      expect(
        RuleValidation.validate(rule.copyWith(dailyLimitMinutes: 0)),
        contains(RuleValidationError.invalidLimit),
      );
      expect(
        RuleValidation.validate(rule.copyWith(dailyLimitMinutes: 1441)),
        contains(RuleValidationError.invalidLimit),
      );
      expect(
        RuleValidation.validate(rule.copyWith(dailyLimitMinutes: 30)),
        isEmpty,
      );
    });

    test('time windows need both ends and valid times', () {
      expect(
        RuleValidation.validate(base().copyWith(startTime: '09:00')),
        contains(RuleValidationError.incompleteTimeWindow),
      );
      expect(
        RuleValidation.validate(
          base().copyWith(startTime: '09:00', endTime: '25:00'),
        ),
        contains(RuleValidationError.invalidTime),
      );
      expect(
        RuleValidation.validate(
          base().copyWith(startTime: '22:00', endTime: '06:00'),
        ),
        isEmpty,
      );
    });

    test('weekdays must be ISO weekdays', () {
      expect(
        RuleValidation.validate(base().copyWith(activeWeekdays: [0, 8])),
        contains(RuleValidationError.invalidWeekday),
      );
    });

    test('feed rules need supported targets for the app', () {
      final feed = base(mode: BlockMode.selectiveFeed);
      expect(
        RuleValidation.validate(feed),
        contains(RuleValidationError.missingFeedTarget),
      );
      expect(
        RuleValidation.validate(
          feed.copyWith(feedTargets: ['instagram.reels']),
        ),
        contains(RuleValidationError.unsupportedFeedTarget),
      );
      expect(
        RuleValidation.validate(feed.copyWith(feedTargets: ['youtube.shorts'])),
        isEmpty,
      );
    });
  });

  test('selective feed is only offered for apps with an adapter', () {
    expect(
      RuleValidation.availableModes(youtube),
      contains(BlockMode.selectiveFeed),
    );
    expect(
      RuleValidation.availableModes('org.wikipedia'),
      isNot(contains(BlockMode.selectiveFeed)),
    );
  });

  test('every mode declares its permissions', () {
    expect(
      RuleValidation.requiredPermissions(BlockMode.appLimit),
      containsAll([
        RequiredPermission.accessibility,
        RequiredPermission.usageAccess,
      ]),
    );
    expect(
      RuleValidation.requiredPermissions(BlockMode.allowException),
      isEmpty,
    );
    for (final mode in BlockMode.values.where((m) => m.restricts)) {
      expect(
        RuleValidation.requiredPermissions(mode),
        contains(RequiredPermission.accessibility),
      );
    }
  });

  group('presets', () {
    final installed = {
      youtube: 'YouTube',
      'com.instagram.android': 'Instagram',
      'com.zhiliaoapp.musically': 'TikTok',
      'org.wikipedia': 'Wikipedia',
    };
    var counter = 0;
    String nextId() => 'id${counter++}';

    List<BlockRule> build(PresetId id) => Presets.all
        .firstWhere((preset) => preset.id == id)
        .build(
          installed: installed,
          ruleName: (app) => 'Preset $app',
          newId: nextId,
        );

    test('every generated rule is valid', () {
      for (final preset in Presets.all) {
        for (final rule in build(preset.id)) {
          expect(RuleValidation.validate(rule), isEmpty, reason: '$rule');
        }
      }
    });

    test('presets only target distracting installed apps', () {
      for (final preset in Presets.all) {
        for (final rule in build(preset.id)) {
          expect(KnownApps.isDistracting(rule.packageName), isTrue);
          expect(installed, contains(rule.packageName));
        }
      }
    });

    test(
      'No Shorts blocks feeds where supported and pauses short-video apps',
      () {
        final rules = build(PresetId.noShorts);
        final byPackage = {for (final rule in rules) rule.packageName: rule};
        expect(byPackage[youtube]!.mode, BlockMode.selectiveFeed);
        expect(byPackage[youtube]!.feedTargets, ['youtube.shorts']);
        expect(byPackage['com.instagram.android']!.feedTargets, [
          'instagram.reels',
        ]);
        expect(
          byPackage['com.zhiliaoapp.musically']!.mode,
          BlockMode.pauseScreen,
        );
      },
    );

    test('Deep Focus rules apply only during focus sessions', () {
      final rules = build(PresetId.deepFocus);
      expect(rules, isNotEmpty);
      expect(rules.every((rule) => rule.focusOnly), isTrue);
    });

    test('Custom builds nothing and all presets are Android-only for now', () {
      expect(build(PresetId.custom), isEmpty);
      for (final preset in Presets.all) {
        expect(preset.support.android, isTrue);
        expect(preset.support.ios, isFalse);
      }
    });

    test('no installed distracting apps means no rules', () {
      final preset = Presets.all.first;
      expect(
        preset.build(
          installed: {'org.wikipedia': 'Wikipedia'},
          ruleName: (app) => app,
        ),
        isEmpty,
      );
    });
  });

  test('every feed target belongs to a known app', () {
    for (final target in FeedTargets.all) {
      expect(KnownApps.feedTargetsFor(target.packageName), contains(target));
      expect(FeedTargets.byId(target.id), target);
    }
  });
}
