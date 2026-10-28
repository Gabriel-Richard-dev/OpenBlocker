# Permissions

OpenBlock asks for as little as possible and never grants anything silently:
every permission is turned on by the user in Android's own settings screens.

| Permission | Type | Used for | What happens without it |
|---|---|---|---|
| Accessibility service (`BIND_ACCESSIBILITY_SERVICE`) | User-enabled service | Detect the foreground app, draw the intervention screen, detect feeds in supported apps | Nothing is enforced. Home shows "Blocking is not working". |
| Usage access (`PACKAGE_USAGE_STATS`) | Special app access | Measure minutes per app for daily limits and statistics | Daily limits are not enforced (Home shows "Partially working"); usage statistics are hidden. |

Permissions OpenBlock deliberately does **not** request:

| Permission | Why not |
|---|---|
| `INTERNET` | Nothing needs the network. CI fails if a release APK requests it. Flutter adds it to **debug** builds only, for hot reload. |
| `SYSTEM_ALERT_WINDOW` ("Display over other apps") | The intervention is an accessibility overlay (`TYPE_ACCESSIBILITY_OVERLAY`), which the accessibility service may draw without it. |
| `QUERY_ALL_PACKAGES` | Only launchable apps are listed, through a `<queries>` element for launcher intents. |
| Notifications, foreground service, boot receiver | Not needed: the system keeps the accessibility service running while it is enabled. |

## Accessibility service

- **Why:** Android provides no other API for a third-party app to react when
  another app comes to the foreground, or to recognise a specific screen
  inside it.
- **What it receives:** window-state events for every app (to know which app is
  in front). While at least one *Block feed* rule is enabled it also receives
  content-change and scroll events; these are discarded immediately for apps
  without such a rule.
- **What it reads:** the package name of the foreground app. In apps with a
  feed rule, whether views with specific resource ids (for example
  `com.google.android.youtube:id/reel_recycler`) exist and are visible. It
  never reads text, content descriptions, passwords or input fields.
- **What it stores:** nothing from the screen. Only an intervention event
  (time, rule id, package name, kind) when it shows a pause/block screen.
- **How to turn it off:** Settings › Accessibility › OpenBlock › Off.

### Android 13+ restricted settings

Apps installed outside an app store (for example an APK from GitHub) cannot
enable an accessibility service until the user allows it. If the switch is
greyed out: Settings › Apps › OpenBlock › ⋮ › **Allow restricted settings**,
then go back to the accessibility settings. OpenBlock's permission screen shows
this hint and a shortcut to the app info page.

## Usage access

- **Why:** daily limits must be based on time actually spent in the app.
- **What it reads:** activity resume/pause events for the packages that have
  rules, from which foreground minutes per day are computed locally.
- **How to revoke:** Settings › Apps › Special app access › Usage access ›
  OpenBlock › Off.

## Revocation and failures

OpenBlock re-checks permissions every time it returns to the foreground. The
Home screen reports:

- *Blocking is not working* — the service is off, or enabled but not running
  (for example after a crash or aggressive battery management).
- *Partially working* — limit rules exist but usage access is missing.

The rules stay saved; enforcement resumes as soon as the permission is back.

## Google Play policy considerations

Before publishing on Google Play, maintainers must review the current
[Accessibility API policy](https://support.google.com/googleplay/android-developer/answer/10964491)
and [permissions policy](https://support.google.com/googleplay/android-developer/answer/9888170).
In particular:

- Apps that use the Accessibility API for purposes other than helping users
  with disabilities must make a **prominent disclosure** and get **affirmative
  consent** before the user enables the service. The onboarding pages and the
  permissions screen are designed for this, but the wording and flow may need
  adjustments for review.
- The service is declared with `android:isAccessibilityTool="false"`, as
  OpenBlock is not an accessibility tool.
- Usage access (`PACKAGE_USAGE_STATS`) requires a declared, user-facing core
  purpose (here: daily limits).
- A store listing must explain that the core functionality depends on these
  permissions.

Technical availability of an API does not guarantee store approval. Until this
review is done, OpenBlock is distributed through GitHub releases.
