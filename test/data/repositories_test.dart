import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openblock/data/models/app_settings.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/models/focus_session.dart';
import 'package:openblock/data/repositories/focus_repository.dart';
import 'package:openblock/data/repositories/rules_repository.dart';
import 'package:openblock/data/repositories/settings_repository.dart';
import 'package:openblock/data/storage/key_value_store.dart';

void main() {
  const rule = BlockRule(
    id: 'r1',
    name: 'Block',
    packageName: 'app',
    mode: BlockMode.scheduledBlock,
  );

  group('RulesRepository', () {
    test('saves and loads the current schema', () async {
      final store = MemoryStore();
      final repo = RulesRepository(store);
      await repo.save([rule]);
      final raw =
          jsonDecode(store.values[RulesRepository.storageKey]!)
              as Map<String, Object?>;
      expect(raw['schemaVersion'], RulesRepository.schemaVersion);
      expect(await repo.load(), [rule]);
    });

    test('empty storage loads no rules', () async {
      expect(await RulesRepository(MemoryStore()).load(), isEmpty);
    });

    test('migrates schema 0 (bare list)', () async {
      final store = MemoryStore({
        RulesRepository.storageKey: jsonEncode([rule.toJson()]),
      });
      expect(await RulesRepository(store).load(), [rule]);
    });

    test('skips invalid entries instead of losing every rule', () {
      final raw = jsonEncode({
        'schemaVersion': 1,
        'rules': [
          rule.toJson(),
          {'id': 'broken'},
          {...rule.toJson(), 'id': 'r2', 'mode': 'unknownMode'},
        ],
      });
      expect(RulesRepository.decode(raw), [rule]);
    });

    test('reads known fields of a newer schema', () {
      final raw = jsonEncode({
        'schemaVersion': 99,
        'rules': [
          {...rule.toJson(), 'futureField': 1},
        ],
      });
      expect(RulesRepository.decode(raw), [rule]);
    });

    test('corrupted document loads nothing', () {
      expect(RulesRepository.decode('{not json'), isEmpty);
      expect(RulesRepository.decode('42'), isEmpty);
    });
  });

  test('SettingsRepository round-trip and corrupted fallback', () async {
    final store = MemoryStore();
    final repo = SettingsRepository(store);
    expect(await repo.load(), const AppSettings());
    const settings = AppSettings(themeMode: ThemeMode.light, pauseSeconds: 5);
    await repo.save(settings);
    expect(await repo.load(), settings);
    store.values[SettingsRepository.storageKey] = 'garbage';
    expect(await repo.load(), const AppSettings());
  });

  group('FocusRepository', () {
    final start = DateTime(2026, 10, 28, 9);
    FocusSession session(String id) => FocusSession(
      id: id,
      startedAt: start,
      plannedEndAt: start.add(const Duration(minutes: 25)),
      activeRuleIds: const ['r1'],
    );

    test('persists the active session and history', () async {
      final store = MemoryStore();
      final repo = FocusRepository(store);
      await repo.save(
        FocusState(active: session('a'), history: [session('b').finish(start)]),
      );
      final loaded = await repo.load();
      expect(loaded.active?.id, 'a');
      expect(loaded.history.single.id, 'b');

      await repo.save(FocusState(history: loaded.history));
      expect((await repo.load()).active, isNull);
      expect(store.values.containsKey(FocusRepository.activeKey), isFalse);
    });

    test('caps history length', () async {
      final repo = FocusRepository(MemoryStore());
      await repo.save(
        FocusState(
          history: [
            for (var i = 0; i < FocusRepository.maxHistory + 10; i++)
              session('$i'),
          ],
        ),
      );
      expect(
        (await repo.load()).history,
        hasLength(FocusRepository.maxHistory),
      );
    });

    test('corrupted data is ignored', () async {
      final store = MemoryStore({
        FocusRepository.activeKey: '{"id":',
        FocusRepository.historyKey: '[1,2]',
      });
      final loaded = await FocusRepository(store).load();
      expect(loaded.active, isNull);
      expect(loaded.history, isEmpty);
    });
  });
}
