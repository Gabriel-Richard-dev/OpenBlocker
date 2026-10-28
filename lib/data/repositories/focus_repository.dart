import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/focus_session.dart';
import '../storage/key_value_store.dart';

@immutable
class FocusState {
  const FocusState({this.active, this.history = const []});

  static const empty = FocusState();

  /// The running session, if any. It may already be past its planned end
  /// until the controller reconciles it.
  final FocusSession? active;

  /// Finished sessions, most recent first.
  final List<FocusSession> history;
}

class FocusRepository {
  FocusRepository(this._store);

  static const activeKey = 'openblock.focus.active';
  static const historyKey = 'openblock.focus.history';

  /// History is capped to keep local storage small.
  static const maxHistory = 500;

  final KeyValueStore _store;

  Future<FocusState> load() async {
    final active = await _store.getString(activeKey);
    final history = await _store.getString(historyKey);
    return FocusState(
      active: active == null ? null : _decodeSession(active),
      history: history == null ? const [] : _decodeHistory(history),
    );
  }

  Future<void> save(FocusState state) async {
    final active = state.active;
    if (active == null) {
      await _store.remove(activeKey);
    } else {
      await _store.setString(activeKey, jsonEncode(active.toJson()));
    }
    await _store.setString(
      historyKey,
      jsonEncode([
        for (final session in state.history.take(maxHistory)) session.toJson(),
      ]),
    );
  }

  Future<void> clearHistory() => _store.remove(historyKey);

  static FocusSession? _decodeSession(String raw) {
    try {
      return FocusSession.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  static List<FocusSession> _decodeHistory(String raw) {
    try {
      return [
        for (final entry in jsonDecode(raw) as List<Object?>)
          FocusSession.fromJson(entry! as Map<String, Object?>),
      ];
    } on Object {
      return const [];
    }
  }
}
