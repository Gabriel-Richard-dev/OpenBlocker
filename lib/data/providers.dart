import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'models/block_rule.dart';
import 'models/platform_models.dart';
import 'platform/openblock_platform.dart';
import 'repositories/focus_repository.dart';
import 'repositories/rules_repository.dart';
import 'repositories/settings_repository.dart';
import 'storage/key_value_store.dart';

typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);

final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider must be overridden'),
);

final platformProvider = Provider<OpenBlockPlatform>(
  (ref) => createDefaultPlatform(),
);

final rulesRepositoryProvider = Provider(
  (ref) => RulesRepository(ref.watch(keyValueStoreProvider)),
);

final settingsRepositoryProvider = Provider(
  (ref) => SettingsRepository(ref.watch(keyValueStoreProvider)),
);

final focusRepositoryProvider = Provider(
  (ref) => FocusRepository(ref.watch(keyValueStoreProvider)),
);

/// Everything read from local storage before the first frame, so the UI never
/// has to show loading states for local data.
@immutable
class InitialData {
  const InitialData({
    this.settings = const AppSettings(),
    this.rules = const [],
    this.focus = FocusState.empty,
  });

  static Future<InitialData> load(KeyValueStore store) async {
    return InitialData(
      settings: await SettingsRepository(store).load(),
      rules: await RulesRepository(store).load(),
      focus: await FocusRepository(store).load(),
    );
  }

  final AppSettings settings;
  final List<BlockRule> rules;
  final FocusState focus;
}

final initialDataProvider = Provider<InitialData>(
  (ref) => throw UnimplementedError('initialDataProvider must be overridden'),
);

final permissionsProvider = FutureProvider<PermissionSnapshot>(
  (ref) => ref.watch(platformProvider).getPermissions(),
);

final installedAppsProvider = FutureProvider<List<InstalledApp>>(
  (ref) => ref.watch(platformProvider).getInstalledApps(),
);

final appIconProvider = FutureProvider.family<Uint8List?, String>(
  (ref, packageName) => ref.watch(platformProvider).getAppIcon(packageName),
);

final runtimeStateProvider = FutureProvider<RuntimeState>(
  (ref) => ref.watch(platformProvider).getRuntimeState(),
);
