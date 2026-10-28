## What does this change?

<!-- A short description and the issue it closes, e.g. "Closes #12". -->

## How was it tested?

- [ ] `flutter analyze` and `flutter test` pass
- [ ] Kotlin unit tests pass (`cd android && ./gradlew :app:testDebugUnitTest`)
- [ ] Tested on a real device (model, Android version): …

## Checklist

- [ ] Rule engine changes are applied to **both** `lib/core/rule_engine.dart` and `RuleEngine.kt`, with new cases in `test/fixtures/rule_engine_vectors.json`
- [ ] New or changed adapters follow docs/adapter-review.md and update docs/supported-apps.md
- [ ] No new permissions, network access, analytics or logging of screen content
- [ ] User-facing strings are added to both `app_en.arb` and `app_pt.arb` (and Android `strings.xml` for the overlay)
- [ ] Documentation and CHANGELOG.md are updated
