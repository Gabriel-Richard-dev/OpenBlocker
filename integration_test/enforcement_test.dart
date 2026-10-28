import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openblock/app/config_sync.dart';
import 'package:openblock/data/models/app_settings.dart';
import 'package:openblock/data/models/block_rule.dart';
import 'package:openblock/data/platform/openblock_platform.dart';

/// End-to-end enforcement check used by CI (tool/ci/e2e.sh).
///
/// The CI script enables the accessibility service through adb and keeps
/// opening the system Settings app. This test configures a rule that blocks
/// Settings and waits until the native service records an intervention.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final platform = MethodChannelPlatform();
  const target = 'com.android.settings';

  // A plain test: enabling an accessibility service mid-test turns on Flutter
  // semantics, which testWidgets reports as a leaked SemanticsHandle.
  test(
    'the service blocks an app with an active rule',
    () async {
      await platform.clearRuntimeData();
      await platform.syncConfig(
        buildNativeConfig(
          rules: const [
            BlockRule(
              id: 'e2e-block-settings',
              name: 'E2E block Settings',
              packageName: target,
              mode: BlockMode.scheduledBlock,
            ),
          ],
          focus: null,
          settings: const AppSettings(),
        ),
      );

      final deadline = DateTime.now().add(const Duration(minutes: 6));
      var running = false;
      var blocked = false;
      while (DateTime.now().isBefore(deadline) && !blocked) {
        running = (await platform.getPermissions()).accessibilityRunning;
        if (running) {
          final runtime = await platform.getRuntimeState();
          blocked = runtime.events.any(
            (event) =>
                event.packageName == target &&
                event.ruleId == 'e2e-block-settings',
          );
        }
        if (!blocked) await Future<void>.delayed(const Duration(seconds: 3));
      }

      // Clean up before asserting so a failure leaves the emulator usable.
      await platform.syncConfig(
        buildNativeConfig(
          rules: const [],
          focus: null,
          settings: const AppSettings(),
        ),
      );
      expect(running, isTrue, reason: 'accessibility service never started');
      expect(blocked, isTrue, reason: 'no intervention recorded for $target');
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
