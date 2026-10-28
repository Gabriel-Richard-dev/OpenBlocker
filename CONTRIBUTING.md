# Contributing to OpenBlock

Thanks for helping! OpenBlock is a small, local-first project, and every bug
report, device test, translation and pull request makes a difference.

By participating you agree to follow the [code of conduct](CODE_OF_CONDUCT.md).

## Ways to help

- **Test on a real device** and report the results with the
  [app support template](.github/ISSUE_TEMPLATE/app_support.yml). Real-device
  reports are what move an adapter from *experimental* to *verified*
  (see [docs/tested-devices.md](docs/tested-devices.md)).
- **Report bugs** with the bug template. Please never attach screenshots or logs
  that show private content.
- **Translate** the app: add `lib/l10n/app_<locale>.arb` and
  `android/app/src/main/res/values-<locale>/strings.xml`.
- **Write code**: pick an issue labelled `good first issue` or `help wanted`.
- **Propose a new app adapter** following [docs/adapter-review.md](docs/adapter-review.md).

## Principles

Changes must keep these properties:

1. **Local-first.** No accounts, servers, analytics or telemetry. The release
   build must not request the Internet permission (CI enforces it).
2. **Minimal observation.** The accessibility service only looks at the
   foreground package and, for feed rules, the presence of known view ids. Never
   read, log or store text or screen content.
3. **Honest about limits.** If something only works sometimes, the UI and docs
   must say so.
4. **The user stays in control.** No dark patterns, guilt messages or ways to
   lock the owner out of their device.

## Development workflow

The full development guide — setup, project layout, tests and how to add an
adapter — is in [docs/contributing.md](docs/contributing.md).

1. Fork the repository and create a branch from `main`.
2. Make your change with tests.
3. Run the checks:

   ```sh
   dart format lib test integration_test
   flutter analyze
   flutter test
   (cd android && ./gradlew :app:testDebugUnitTest)
   ```

4. Update the documentation and `CHANGELOG.md` (under *Unreleased*).
5. Open a pull request and fill in the template.

### Rule engine changes

The rules are evaluated twice: in Dart (`lib/core/rule_engine.dart`, for the
UI) and in Kotlin (`android/.../engine/RuleEngine.kt`, for enforcement). Any
behaviour change must be made in **both** and covered by a new case in
`test/fixtures/rule_engine_vectors.json`, which both test suites run.

### Commit messages

Use short, imperative subject lines (for example `Add Instagram Reels adapter`)
and explain the *why* in the body when it is not obvious.

## Reviews

Maintainers aim to review pull requests within a week. Adapter changes need a
test report from at least one real device before merging; see the review
checklist in [docs/adapter-review.md](docs/adapter-review.md).
