import 'dart:convert';

import '../models/app_settings.dart';
import '../storage/key_value_store.dart';

class SettingsRepository {
  SettingsRepository(this._store);

  static const storageKey = 'openblock.settings';

  final KeyValueStore _store;

  Future<AppSettings> load() async {
    final raw = await _store.getString(storageKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) =>
      _store.setString(storageKey, jsonEncode(settings.toJson()));
}
