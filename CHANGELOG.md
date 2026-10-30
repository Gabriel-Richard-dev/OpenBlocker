# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **Bank guard**: OpenBlock turns its accessibility service off while a listed
  banking app (Nubank, Itaú, Banco do Brasil and others, editable) is open, and
  back on when an app with rules or OpenBlock is opened. Needs a one-time
  `WRITE_SECURE_SETTINGS` grant through ADB.
- **Progress widget** for the home screen: today's screen time, the change
  against your usual by this time of day and the last seven days.

### Removed

- The **Snooze** and **End focus session** buttons on the intervention screen,
  and the snooze length setting. They made every block a one-tap escape. Rules
  can still be paused and focus sessions ended from inside OpenBlock.

## [0.1.0] - 2026-10-28

First public pre-release (MVP) for Android 8.0+.

### Added

- Rules per app: **block app** (on a schedule or during focus), **daily limit**,
  **block feed** (YouTube Shorts and Instagram Reels, experimental),
  **pause screen** and **exceptions**, with weekdays, time windows (including
  overnight windows), temporary pause and documented precedence.
- **Focus sessions** (25/45/60 minutes or custom) that activate the rules you
  choose and survive app restarts and device reboots.
- **Presets**: Study Mode, No Shorts, Social Media Limit, Deep Focus and Custom,
  each stating the platforms where it works.
- Native Android **accessibility service** that enforces rules with a
  full-screen pause/block screen drawn as an accessibility overlay
  (no "Display over other apps" permission), with go back, snooze and end
  focus actions.
- **Usage access** integration for measured daily limits and statistics.
- **Statistics**: interventions per day, focus minutes, completed sessions,
  measured usage of apps with rules and most triggered rules.
- **Onboarding** that explains what OpenBlock does, each permission, what it can
  observe and how to turn it off; a permissions screen that reports when the
  service is off or stopped by the system.
- Settings: light/dark/system theme, snooze length, pause countdown, custom
  pause message, JSON export/import through the clipboard, delete statistics
  and delete all data.
- English and Brazilian Portuguese translations.
- Shared rule engine test vectors run by both the Dart and Kotlin test suites,
  widget tests for the critical flows and emulator end-to-end tests in CI.
- Open-source documentation: architecture, privacy, permissions, supported apps,
  rule precedence, threat model, tested devices, adapter review and release
  process.

### Known limitations

- Feed adapters are **experimental**: they have not been verified on real
  devices yet and can break when the target app changes its interface.
- Only tested on the Android emulator in CI so far (see
  `docs/tested-devices.md`).
- No iOS version yet.

[Unreleased]: https://github.com/Gabriel-Richard-dev/OpenBlocker/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Gabriel-Richard-dev/OpenBlocker/releases/tag/v0.1.0
