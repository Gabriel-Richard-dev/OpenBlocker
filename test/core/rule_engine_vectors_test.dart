import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/core/rule_engine.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/models/focus_session.dart';

/// Runs the vectors shared with the Kotlin engine
/// (android/app/src/test/.../RuleEngineVectorsTest.kt).
void main() {
  final document =
      jsonDecode(
            File('test/fixtures/rule_engine_vectors.json').readAsStringSync(),
          )
          as Map<String, Object?>;
  final cases = (document['cases']! as List<Object?>)
      .cast<Map<String, Object?>>();

  test('vector file is not empty', () => expect(cases, isNotEmpty));

  for (final vector in cases) {
    test(vector['name']! as String, () {
      final rules = [
        for (final rule in vector['rules']! as List<Object?>)
          BlockRule.fromJson(rule! as Map<String, Object?>),
      ];
      final local = DateTime.parse(vector['nowLocal']! as String);
      final focusJson = vector['focus'] as Map<String, Object?>?;
      final snoozes = (vector['snoozes']! as Map<String, Object?>).map(
        (key, value) => MapEntry(key, (value! as num).toInt()),
      );
      final ctx = EvaluationContext(
        packageName: vector['packageName']! as String,
        nowMs: (vector['nowMs']! as num).toInt(),
        weekday: local.weekday,
        minuteOfDay: local.hour * 60 + local.minute,
        usageMinutes: (vector['usageMinutes'] as num?)?.toInt(),
        focus: focusJson == null ? null : FocusSession.fromJson(focusJson),
        snoozes: snoozes,
      );

      final decision = RuleEngine.evaluate(rules, ctx);
      final expected = vector['expect']! as Map<String, Object?>;

      expect(decision.action.name, expected['action']);
      expect(decision.reason.name, expected['reason']);
      expect(decision.ruleId, expected['ruleId']);
      expect(decision.feedTargets, expected['feedTargets']);
    });
  }
}
