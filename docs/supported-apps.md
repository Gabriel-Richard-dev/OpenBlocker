# Supported apps

Every app with a launcher icon supports the whole-app modes: **Block app**,
**Daily limit**, **Pause screen** and **Exception**. These only depend on the
package name and work the same for any app.

**Block feed** needs an app-specific adapter. Adapters live in
`android/app/src/main/kotlin/dev/openblock/app/accessibility/adapters/` and are
registered on the Dart side in `lib/core/supported_apps.dart`.

## Feed adapters

| App | Package | Feed id | Detection | Status |
|---|---|---|---|---|
| YouTube | `com.google.android.youtube` | `youtube.shorts` | Visible view with id `reel_recycler`, `reel_player_page_container` or `reel_watch_player` | Experimental — [details](adapters/youtube-shorts.md) |
| Instagram | `com.instagram.android` | `instagram.reels` | Visible view with id `clips_viewer_view_pager` or `clips_viewer_pager` | Experimental |

**Status levels**

- **Experimental** — implemented, tested on the emulator at most. Detection may
  fail on some devices or app versions.
- **Verified** — confirmed on at least three real devices from two
  manufacturers, on the app version listed in [tested-devices.md](tested-devices.md),
  following the [adapter review process](adapter-review.md).

No adapter is verified yet.

### What adapters do and do not do

- They check only for the **presence and visibility of views with known
  resource ids**. They never read text and do not use screen coordinates or
  generic heuristics.
- When the feed is detected, OpenBlock shows the feed intervention; "Go back"
  sends the system back action to leave the feed. The rest of the app (search,
  subscriptions, regular videos, messages, profile) keeps working.
- When the target app changes its views, detection silently stops: the feed is
  no longer blocked, but nothing else breaks. Please report it with the
  [app support template](../.github/ISSUE_TEMPLATE/app_support.yml).

## Apps known to the presets

The presets target these apps when installed (category in parentheses):
YouTube (video), Instagram (social), TikTok (video, `com.zhiliaoapp.musically`
and `com.ss.android.ugc.trill`), TikTok Lite (video), Kwai (video), Facebook,
X, Reddit, Snapchat, Pinterest, Threads and Bluesky (social).

TikTok is a short-video feed as a whole, so the *No Shorts* preset adds a pause
screen for it rather than a feed adapter.

## Adding an app

See [adapter-review.md](adapter-review.md) for the checklist and
[contributing.md](contributing.md#adding-a-feed-adapter) for the code changes.
