# Adapter: YouTube Shorts (reference adapter)

| | |
|---|---|
| App | YouTube (`com.google.android.youtube`) |
| Feed id | `youtube.shorts` |
| Code | `android/.../accessibility/adapters/FeedAdapters.kt` (`YouTubeShortsAdapter`) |
| Status | **Experimental** |
| Permissions | Accessibility service |

This is the first app-specific adapter (spec phase 3) and the template for
future ones.

## How detection works

The Shorts player is a vertical pager. In current YouTube versions its
containers expose these resource ids:

- `com.google.android.youtube:id/reel_recycler`
- `com.google.android.youtube:id/reel_player_page_container`
- `com.google.android.youtube:id/reel_watch_player`

The adapter calls `findAccessibilityNodeInfosByViewId` for each id on the active
window and reports the feed when any matching node is visible to the user. It
reads no text and no content descriptions.

The service only runs this check when:

1. YouTube is the foreground app,
2. an enabled *Block feed* rule for YouTube is active, and
3. a window or content change happened (debounced to once every 400 ms).

## Intervention

When Shorts are detected, the feed intervention appears with:

- **Go back** — hides the screen and sends the system back action, which leaves
  the Shorts player;
- **Snooze** — disables the rule for the configured number of minutes;
- **End focus session** — only when the rule is active because of a session.

## What keeps working

Home feed, search, subscriptions, regular videos (including full-screen),
library, comments and settings do not contain the `reel_*` ids, so they are not
affected.

## Known limitations

- YouTube can rename these views in any update. Detection then stops and Shorts
  are no longer blocked; the rest of the app is unaffected.
- A Short opened inside the regular player (for example from search results on
  some versions) may not use the Shorts pager and would not be detected.
- Shorts thumbnails ("shelves") in the home feed are not hidden — OpenBlock
  only intervenes when the Shorts player opens.

## Test protocol

To move this adapter to **verified**, test on at least three real devices from
two manufacturers and record the results in [tested-devices.md](../tested-devices.md):

1. Create a *Block feed* rule for YouTube Shorts.
2. Open YouTube → Shorts tab: the intervention appears within one second.
3. Tap **Go back**: you are back in the previous YouTube screen.
4. Open a Short from the home shelf: the intervention appears.
5. Play a regular video, search, open subscriptions and the library: no
   intervention.
6. Rotate the device and use split-screen: behaviour is the same.
7. Snooze the rule: Shorts work until the snooze ends.
8. Repeat after a YouTube update.

Record the YouTube version (Settings › Apps › YouTube) with each report.
