import 'dart:convert';

import '../core/rule_validation.dart';
import 'models/app_settings.dart';
import 'models/block_rule.dart';

/// Plain JSON export of the user's configuration. Statistics are not
/// included; the file contains only what the user configured.
class Backup {
  const Backup({required this.settings, required this.rules});

  static const format = 'openblock-backup';
  static const version = 1;

  final AppSettings settings;
  final List<BlockRule> rules;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': format,
    'version': version,
    'settings': settings.toJson()..remove('onboardingCompleted'),
    'rules': [for (final rule in rules) rule.toJson()],
  });

  /// Parses an exported document. Throws [FormatException] when the text is
  /// not an OpenBlock backup. Invalid rules are dropped.
  static Backup decode(String text) {
    final Object? document;
    try {
      document = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Not valid JSON');
    }
    if (document is! Map<String, Object?> || document['format'] != format) {
      throw const FormatException('Not an OpenBlock backup');
    }
    final version = (document['version'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > Backup.version) {
      throw FormatException('Unsupported backup version $version');
    }
    final settingsJson = document['settings'];
    final rules = <BlockRule>[];
    for (final entry in document['rules'] as List<Object?>? ?? const []) {
      try {
        final rule = BlockRule.fromJson(entry! as Map<String, Object?>);
        if (RuleValidation.validate(rule).isEmpty) rules.add(rule);
      } on Object {
        // Skip entries that do not describe a valid rule.
      }
    }
    return Backup(
      settings: settingsJson is Map<String, Object?>
          ? AppSettings.fromJson(settingsJson)
          : const AppSettings(),
      rules: rules,
    );
  }
}
