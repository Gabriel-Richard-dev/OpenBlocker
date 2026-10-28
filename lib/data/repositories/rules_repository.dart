import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/block_rule.dart';
import '../storage/key_value_store.dart';

/// Persists rules as a versioned JSON document.
///
/// Schema history:
///  * 0 — a bare JSON list of rules (development builds before 0.1.0).
///  * 1 — `{"schemaVersion": 1, "rules": [...]}`.
class RulesRepository {
  RulesRepository(this._store);

  static const storageKey = 'openblock.rules';
  static const schemaVersion = 1;

  final KeyValueStore _store;

  Future<List<BlockRule>> load() async {
    final raw = await _store.getString(storageKey);
    if (raw == null) return const [];
    return decode(raw);
  }

  Future<void> save(List<BlockRule> rules) =>
      _store.setString(storageKey, encode(rules));

  static String encode(List<BlockRule> rules) => jsonEncode({
    'schemaVersion': schemaVersion,
    'rules': [for (final rule in rules) rule.toJson()],
  });

  /// Decodes any known schema version. Entries that cannot be parsed are
  /// skipped instead of discarding the whole list.
  static List<BlockRule> decode(String raw) {
    final Object? document;
    try {
      document = jsonDecode(raw);
    } on FormatException catch (error) {
      debugPrint('OpenBlock: unreadable rules document: $error');
      return const [];
    }
    final List<Object?> entries;
    if (document is List<Object?>) {
      entries = document;
    } else if (document is Map<String, Object?>) {
      final version = (document['schemaVersion'] as num?)?.toInt() ?? 0;
      if (version > schemaVersion) {
        debugPrint(
          'OpenBlock: rules schema $version is newer than $schemaVersion; '
          'reading known fields only.',
        );
      }
      entries = document['rules'] as List<Object?>? ?? const [];
    } else {
      return const [];
    }
    final rules = <BlockRule>[];
    for (final entry in entries) {
      try {
        rules.add(BlockRule.fromJson(entry! as Map<String, Object?>));
      } on Object catch (error) {
        debugPrint('OpenBlock: skipping invalid rule: $error');
      }
    }
    return rules;
  }
}
