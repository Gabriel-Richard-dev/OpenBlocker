# Adapter review process

App-specific feed adapters touch other apps' interfaces, so they get extra
review. This is the process for adding or changing one.

## 1. Proposal

Open an issue with the **App support / adapter** template including:

- app name, package name and version;
- the feed to block and what must keep working;
- the resource ids you observed (for example with Android Studio's Layout
  Inspector or `uiautomator dump` on a test account) — never share screenshots
  with private content.

## 2. Implementation checklist

- [ ] Detection uses only **resource ids** of the target app (no text, no
      content descriptions, no coordinates, no generic heuristics).
- [ ] The adapter extends `ViewIdFeedAdapter` or implements `FeedAdapter`
      without retaining nodes, and recycles nodes on API < 33.
- [ ] The feed id is registered in `FeedAdapters` (Kotlin) **and**
      `FeedTargets`/`KnownApps` (Dart) with `SupportLevel.experimental`.
- [ ] Labels are added to `app_en.arb` and `app_pt.arb` (`feedTargetLabel`).
- [ ] `docs/supported-apps.md` lists the ids, status and limitations.
- [ ] A doc page under `docs/adapters/` describes detection, what keeps working,
      known limitations and the test protocol.

## 3. Testing

- [ ] Unit/widget tests pass (`flutter test`, Kotlin unit tests).
- [ ] Tested on at least one real device; results added to
      `docs/tested-devices.md` with device, Android version and app version.
- [ ] Verified that the rest of the app keeps working (navigation, search,
      messages, playback).
- [ ] Verified behaviour when the rule is snoozed, paused and disabled.

## 4. Review

A maintainer checks the privacy constraints above, runs the protocol on a device
if possible and merges the adapter as **experimental**.

## 5. Promotion to verified

An adapter becomes **verified** when the test protocol passed on at least
**three real devices from two manufacturers** on the same app version. Update
`SupportLevel` in `lib/core/supported_apps.dart`, the status in
`docs/supported-apps.md`, and note it in `CHANGELOG.md`.

## 6. Maintenance

When an adapter stops working after an app update:

1. Confirm it with an issue report including the app version.
2. Update the ids (keep the old ones while both versions are common).
3. Mark the adapter experimental again until re-verified.
