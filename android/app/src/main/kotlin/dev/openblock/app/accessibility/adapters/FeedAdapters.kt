package dev.openblock.app.accessibility.adapters

/**
 * Reference adapter: YouTube Shorts.
 *
 * The Shorts player is hosted in a vertical pager whose container views use
 * the `reel_*` resource ids below. Regular videos, search, subscriptions and
 * the library do not contain them, so the rest of the app keeps working.
 * Status: experimental — see docs/adapters/youtube-shorts.md.
 */
class YouTubeShortsAdapter : ViewIdFeedAdapter(
    packageName = "com.google.android.youtube",
    target = "youtube.shorts",
    viewIds = listOf(
        "reel_recycler",
        "reel_player_page_container",
        "reel_watch_player",
    ),
)

/**
 * Instagram Reels viewer (full-screen vertical pager).
 * Status: experimental — see docs/supported-apps.md.
 */
class InstagramReelsAdapter : ViewIdFeedAdapter(
    packageName = "com.instagram.android",
    target = "instagram.reels",
    viewIds = listOf(
        "clips_viewer_view_pager",
        "clips_viewer_pager",
    ),
)

object FeedAdapters {
    private val all: List<FeedAdapter> = listOf(YouTubeShortsAdapter(), InstagramReelsAdapter())

    private val byPackage: Map<String, List<FeedAdapter>> = all.groupBy { it.packageName }

    fun forPackage(packageName: String): List<FeedAdapter> = byPackage[packageName].orEmpty()

    fun supports(packageName: String): Boolean = byPackage.containsKey(packageName)
}
