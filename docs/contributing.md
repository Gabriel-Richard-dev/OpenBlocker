# Development guide

This guide covers local setup, the code layout and common tasks. For the
contribution process and principles see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Setup

- Flutter **3.41** (stable channel) — the version CI uses is in
  `.github/workflows/ci.yml`.
- JDK **17** (Android Gradle Plugin requirement).
- Android SDK with platform tools, and a device or emulator running Android 8.0+.

```sh
flutter pub get          # also generates lib/l10n/gen/
flutter run              # debug build on a connected device
```

Debug builds include the `INTERNET` permission (Flutter needs it for hot
reload); release builds do not.

## Project layout

See [architecture.md](architecture.md#repository-layout). The short version:
pure logic in `lib/core/`, data and the native bridge in `lib/data/`, screens
in `lib/features/`, native code in `android/app/src/main/kotlin/dev/openblock/app/`.

State management uses Riverpod 3 `Notifier`s. Local data is loaded before the
first frame (`InitialData`) so screens never wait for storage.

## Tests

```sh
flutter analyze
flutter test                                   # unit + widget tests
(cd android && ./gradlew :app:testDebugUnitTest)   # Kotlin, after one flutter build
flutter test integration_test/bridge_test.dart   # needs a device/emulator
./tool/ci/e2e.sh                                 # emulator end-to-end (uses adb)
```

The e2e script enables the accessibility service through `adb` and launches the
Settings app, so only run it on a test device or emulator.

## Changing the rule engine

1. Add a case to `test/fixtures/rule_engine_vectors.json` describing the new
   behaviour (rules, local time, epoch ms, usage, focus, snoozes, expected
   decision).
2. Update `lib/core/rule_engine.dart` and
   `android/.../engine/RuleEngine.kt`.
3. Run both test suites — they read the same file.
4. Update [rule-precedence.md](rule-precedence.md).

## Changing stored data

Rules are stored as `{"schemaVersion": N, "rules": [...]}`. When a change is
not backwards compatible:

1. Increase `RulesRepository.schemaVersion`.
2. Teach `RulesRepository.decode` to read the previous version.
3. Add a migration test in `test/data/repositories_test.dart`.
4. If the native config changes, bump `nativeConfigVersion` in
   `lib/app/config_sync.dart` and update `ConfigParser.kt`.

## Adding a feed adapter

1. Find stable resource ids for the feed container (Layout Inspector or
   `adb shell uiautomator dump` on a test account).
2. Add a class to `accessibility/adapters/FeedAdapters.kt`:

   ```kotlin
   class ExampleReelsAdapter : ViewIdFeedAdapter(
       packageName = "com.example.app",
       target = "example.reels",
       viewIds = listOf("reels_pager"),
   )
   ```

   and register it in `FeedAdapters.all`.
3. Register the feed in `lib/core/supported_apps.dart` (`FeedTargets` and the
   app's `KnownApp.feedTargets`) with `SupportLevel.experimental`.
4. Add the label to `feedTargetLabel` in `lib/features/rules/rule_texts.dart`
   and both ARB files.
5. Document it in [supported-apps.md](supported-apps.md) and follow the
   [adapter review process](adapter-review.md).

## Translations

- Flutter strings: `lib/l10n/app_en.arb` (template) and `lib/l10n/app_pt.arb`.
  Run `flutter gen-l10n` (or `flutter pub get`) after editing.
- Intervention screen strings (native): `android/app/src/main/res/values*/strings.xml`.

## Code style

- `dart format` and the lints in `analysis_options.yaml` (CI enforces both).
- Kotlin follows the official Kotlin style; keep the service free of blocking
  work on the main thread except tiny SharedPreferences reads.
- Comments explain *why*, not *what*.
