# Architecture

OpenBlock has two halves that run in the same Android process:

- a **Flutter app** (Dart) that owns the UI, the rules and all persistent user
  data;
- a **native enforcement layer** (Kotlin) with an accessibility service that
  applies the rules while other apps are in the foreground.

There is no backend. Nothing leaves the device.

```text
┌──────────────────────── Flutter (lib/) ─────────────────────────┐
│ features/ (UI)  →  controllers (Riverpod)  →  repositories      │
│                          │                     (DataStore via   │
│                          │ configSyncProvider    shared_prefs)  │
│                          ▼                                       │
│                 data/platform/openblock_platform.dart            │
└──────────────────────────┬──────────────────────────────────────┘
          MethodChannel "dev.openblock.app/platform"
┌──────────────────────────┴──────── Android (android/app/…) ─────┐
│ bridge/PlatformChannel ──► storage/NativeStore (SharedPrefs)     │
│                                   ▲        │ change listener     │
│ usage/UsageReader                 │        ▼                     │
│ apps/InstalledApps    accessibility/OpenBlockAccessibilityService│
│                         ├─ engine/RuleEngine (Kotlin port)       │
│                         ├─ accessibility/adapters/* (feeds)      │
│                         └─ overlay/InterventionOverlay           │
└──────────────────────────────────────────────────────────────────┘
```

## Repository layout

| Path | Contents |
|---|---|
| `lib/app/` | App root, theme, version, config sync to native |
| `lib/core/` | Pure logic: rule engine, validation, presets, supported apps, time helpers, shared widgets |
| `lib/data/` | Models, storage, repositories, platform bridge, providers, backup |
| `lib/features/` | `home`, `rules`, `focus`, `statistics`, `settings`, `onboarding`, `shell` |
| `lib/l10n/` | ARB translations (`en`, `pt`); generated code goes to `lib/l10n/gen/` |
| `android/app/src/main/kotlin/dev/openblock/app/` | `engine/`, `storage/`, `usage/`, `apps/`, `bridge/`, `accessibility/`, `overlay/` |
| `test/` | Dart unit and widget tests; `test/fixtures/rule_engine_vectors.json` |
| `android/app/src/test/` | Kotlin unit tests (run the same vectors) |
| `integration_test/` | On-device tests: bridge, storage and end-to-end enforcement |
| `tool/ci/` | CI scripts (emulator end-to-end, permission check) |

The spec suggested an `app/` folder for the Flutter code; the standard Flutter
layout was kept instead because platform code is already isolated under
`android/`.

## Data ownership

- **Flutter is the source of truth** for rules, settings and focus history.
  They are stored as versioned JSON documents with `SharedPreferencesAsync`,
  which uses Jetpack DataStore on Android. See
  `lib/data/repositories/rules_repository.dart` for the schema history and
  migrations.
- On every change, `configSyncProvider` sends the full configuration to the
  native side (`syncConfig`). The native store keeps the last config so the
  service works while the Flutter UI is not running, including after a reboot.
- **Native runtime state** is written by the service and read back by Flutter
  through `getRuntimeState`: snoozes set from the intervention screen, a focus
  session ended from the intervention screen, and intervention events used for
  statistics (30 days, at most 2,000 entries, no screen content).

Native storage uses plain `SharedPreferences` instead of DataStore because the
service needs synchronous reads when an accessibility event arrives and the
data is tiny.

## Time handling

- Instants (focus start/end, snoozes, temporary pauses, events) are UTC epoch
  milliseconds, so they are unaffected by time zone changes and reboots.
- Schedules (weekdays and `HH:mm` windows) are evaluated in the device's current
  local time. An overnight window such as 22:00–06:00 belongs to the weekday on
  which it starts.
- A focus session that ended while the app was closed (or the device was off)
  is completed when the app next starts.

## Rule evaluation

Rules are evaluated by two implementations with identical behaviour:

- `lib/core/rule_engine.dart` — for the UI (status badges, home card).
- `android/.../engine/RuleEngine.kt` — for enforcement in the service.

Both run the vectors in `test/fixtures/rule_engine_vectors.json` in CI. The
precedence is described in [rule-precedence.md](rule-precedence.md).

## Enforcement flow

1. The accessibility service receives `TYPE_WINDOW_STATE_CHANGED` and confirms
   the foreground package with the active window. Our own package, System UI
   and keyboards are ignored.
2. If the package has no rules, nothing else happens.
3. Otherwise the service builds an `EvaluationContext` (local weekday and
   minute, measured usage if a limit rule exists, the focus session, snoozes)
   and asks `RuleEngine` for a decision.
4. Depending on the decision it shows the **block**, **limit**, **focus**,
   **pause** or — if an adapter sees the feed on screen — **feed** intervention.
5. While an app with rules is in front, it re-evaluates every 30 seconds so
   schedules, limits and focus sessions take effect without new events.
6. Content-change and scroll events are only subscribed to while an enabled
   feed rule exists, and feed checks are debounced (400 ms).

The intervention is a `TYPE_ACCESSIBILITY_OVERLAY` window. It is not
focusable, so the system back/home gestures still reach the app below and the
user can always leave. Actions: go home (or back, for feeds), snooze the rule,
continue (pause screen, after the countdown) and end the focus session.

## Method channel contract

Channel: `dev.openblock.app/platform`. All calls are local.

| Method | Arguments | Result |
|---|---|---|
| `getPermissions` | — | `{accessibilityEnabled, accessibilityRunning, usageAccessGranted, sdkInt}` |
| `openAccessibilitySettings` | — | opens system settings |
| `openUsageAccessSettings` | — | opens system settings |
| `openAppDetailsSettings` | — | opens OpenBlock's app info (restricted settings) |
| `getInstalledApps` | — | `[{packageName, label}]` launchable apps, excluding OpenBlock |
| `getAppIcon` | `{packageName}` | PNG bytes or `null` |
| `syncConfig` | `{config: String}` JSON, see below | `null` |
| `getDailyUsage` | `{packages: [String], days: int}` | `[{date: "yyyy-MM-dd", usage: {pkg: minutes}}]` oldest first, or `null` without usage access |
| `getRuntimeState` | — | `{snoozes: {ruleId: ms}, endedFocusId, endedFocusAtMs, events: [{atMs, ruleId, packageName, kind}]}` |
| `clearSnooze` | `{ruleId}` | `null` |
| `clearRuntimeData` | — | deletes events, snoozes and the ended-focus marker |

Config document (`version` 1):

```json
{
  "version": 1,
  "rules": [
    {
      "id": "…", "name": "No Shorts", "packageName": "com.google.android.youtube",
      "appLabel": "YouTube", "mode": "selectiveFeed", "enabled": true,
      "dailyLimitMinutes": null, "activeWeekdays": [1, 2, 3, 4, 5],
      "startTime": "08:00", "endTime": "18:00",
      "feedTargets": ["youtube.shorts"], "focusOnly": false, "pausedUntilMs": null
    }
  ],
  "focus": {
    "id": "…", "startedAtMs": 0, "plannedEndAtMs": 0,
    "activeRuleIds": ["…"], "completed": false, "endedAtMs": null
  },
  "snoozeMinutes": 5,
  "pauseSeconds": 10,
  "pauseMessage": null
}
```

`mode` is one of `appLimit`, `scheduledBlock`, `selectiveFeed`, `pauseScreen`,
`allowException`. Unknown modes are ignored by the native parser.

## Background work

No foreground service, alarm or WorkManager job is used. The accessibility
service is kept alive by the system while it is enabled, and focus sessions are
plain timestamps compared at evaluation time. This keeps battery use low and
avoids a permanently running process of our own.

## Testing

| Layer | Where |
|---|---|
| Rule engine (Dart and Kotlin, shared vectors) | `test/core/`, `android/app/src/test/` |
| Validation, presets, models, migrations, backup | `test/core/`, `test/data/` |
| Controllers, config sync, statistics, status | `test/features/` |
| UI flows (onboarding, rules CRUD, presets, focus, broken service, delete data, translations) | `test/features/app_flows_test.dart` |
| Method channel contract (Dart side) | `test/data/method_channel_platform_test.dart` |
| Real bridge and storage on Android | `integration_test/bridge_test.dart` |
| Service enforcement on an emulator | `integration_test/enforcement_test.dart` + `tool/ci/e2e.sh` |
