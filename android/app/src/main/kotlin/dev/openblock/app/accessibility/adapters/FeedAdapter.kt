package dev.openblock.app.accessibility.adapters

import android.view.accessibility.AccessibilityNodeInfo

/**
 * Recognises a specific feed inside one app.
 *
 * Adapters are app-specific on purpose: there are no generic heuristics,
 * coordinates or text matching. An adapter only checks whether views with
 * known resource ids are visible; it never reads text. Every adapter must be
 * documented in docs/supported-apps.md together with how it was tested.
 */
interface FeedAdapter {
    val packageName: String

    /** Feed ids this adapter can detect, e.g. `youtube.shorts`. */
    val targets: Set<String>

    /**
     * Returns the id of the feed visible in [root], restricted to [wanted],
     * or null if none of them is on screen.
     */
    fun detect(root: AccessibilityNodeInfo, wanted: Collection<String>): String?
}

/** Detects a feed by the presence of any visible view with one of [viewIds]. */
abstract class ViewIdFeedAdapter(
    final override val packageName: String,
    private val target: String,
    viewIds: List<String>,
) : FeedAdapter {
    private val fullIds = viewIds.map { "$packageName:id/$it" }

    final override val targets: Set<String> = setOf(target)

    override fun detect(root: AccessibilityNodeInfo, wanted: Collection<String>): String? {
        if (target !in wanted) return null
        for (id in fullIds) {
            val nodes = try {
                root.findAccessibilityNodeInfosByViewId(id)
            } catch (_: RuntimeException) {
                // The window can change while it is being inspected.
                emptyList()
            }
            val visible = nodes.any { it.isVisibleToUser }
            nodes.forEach { it.recycleCompat() }
            if (visible) return target
        }
        return null
    }
}

@Suppress("DEPRECATION")
internal fun AccessibilityNodeInfo.recycleCompat() {
    // recycle() is a no-op from API 33; earlier versions still pool nodes.
    if (android.os.Build.VERSION.SDK_INT < 33) {
        try {
            recycle()
        } catch (_: IllegalStateException) {
            // Already recycled.
        }
    }
}
