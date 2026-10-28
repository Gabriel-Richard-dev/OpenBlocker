import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/models/block_rule.dart';
import '../data/models/focus_session.dart';
import '../data/providers.dart';
import '../features/focus/focus_controller.dart';
import '../features/rules/rules_controller.dart';
import '../features/settings/settings_controller.dart';

/// Version of the JSON document sent to the native service.
const nativeConfigVersion = 1;

Map<String, Object?> buildNativeConfig({
  required List<BlockRule> rules,
  required FocusSession? focus,
  required AppSettings settings,
}) => {
  'version': nativeConfigVersion,
  'rules': [for (final rule in rules) rule.toJson()],
  'focus': focus?.toJson(),
  'snoozeMinutes': settings.snoozeMinutes,
  'pauseSeconds': settings.pauseSeconds,
  'pauseMessage': settings.pauseMessage,
};

/// Pushes the configuration to the native service whenever rules, the focus
/// session or the intervention settings change. Watch it once from the root.
final configSyncProvider = Provider<void>((ref) {
  var lastSent = '';

  void push() {
    final config = buildNativeConfig(
      rules: ref.read(rulesProvider),
      focus: ref.read(focusProvider).active,
      settings: ref.read(settingsProvider),
    );
    final fingerprint = config.toString();
    if (fingerprint == lastSent) return;
    lastSent = fingerprint;
    unawaited(
      ref
          .read(platformProvider)
          .syncConfig(config)
          .catchError(
            (Object error) =>
                debugPrint('OpenBlock: failed to sync config: $error'),
          ),
    );
  }

  ref.listen(rulesProvider, (_, _) => push());
  ref.listen(focusProvider, (_, _) => push());
  ref.listen(settingsProvider, (_, _) => push());
  push();
});
