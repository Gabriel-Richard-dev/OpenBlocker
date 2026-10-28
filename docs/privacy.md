# Privacy policy

_Last updated: 2026-10-28 · applies to OpenBlock 0.1.0 and later._

OpenBlock is built to be private by default. This page describes exactly what
the app handles.

## Summary

- No account, no sign-up, no server.
- No analytics, telemetry, crash reporting or advertising SDKs.
- The release app does not request network access, so it cannot send data
  anywhere.
- Everything OpenBlock stores stays on your device and is removed when you
  delete the app's data or uninstall it.

## What is stored on your device

| Data | Where | Retention |
|---|---|---|
| Rules, settings, focus sessions (start, end, rules) | App storage (Jetpack DataStore) | Until you delete them |
| Last configuration synced to the enforcement service | Private SharedPreferences | Until you delete all data or uninstall |
| Intervention events: time, rule id, app package name, kind (block/limit/focus/feed/pause) | Private SharedPreferences | 30 days, at most 2,000 entries |
| Snoozes set from the intervention screen | Private SharedPreferences | Until they expire |

Android cloud backup and device-to-device transfer are disabled for OpenBlock,
so this data is not copied to Google's servers. Use **Settings › Your data ›
Export** if you want a copy of your rules; the export contains only rules and
settings, never statistics.

## What OpenBlock observes but does not store

- **Accessibility service:** the package name of the app on screen and, for
  apps with a *Block feed* rule, whether views with known resource ids are
  visible. It does not read text, messages, passwords, notifications or input,
  and it does not take screenshots.
- **Usage access:** foreground time of the apps that have rules, computed from
  Android's usage events when needed (daily limits and statistics).

## Your controls

- Delete statistics: Settings › Your data › Delete statistics.
- Delete everything: Settings › Your data › Delete all data.
- Turn the service off: Android Settings › Accessibility › OpenBlock.
- Revoke usage access: Android Settings › Apps › Special app access › Usage
  access.
- Uninstall the app to remove all of its data.

## Children

OpenBlock does not knowingly collect any personal data from anyone, including
children, because it does not collect personal data at all.

## Changes

Changes to this policy are tracked in the project's Git history and noted in
`CHANGELOG.md`. If a future version ever adds an optional feature that needs the
network (for example sync), it will be off by default and described here first.

## Contact

Questions: open an issue at
<https://github.com/Gabriel-Richard-dev/OpenBlocker/issues>. Security reports:
see [SECURITY.md](../SECURITY.md).
