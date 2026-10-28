package dev.openblock.app.apps

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

/**
 * Lists launchable apps. Package visibility is limited to launcher activities
 * through the `<queries>` element in the manifest, so QUERY_ALL_PACKAGES is
 * not needed.
 */
class InstalledApps(private val context: Context) {
    data class App(val packageName: String, val label: String)

    fun launchable(): List<App> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val activities = pm.queryIntentActivities(intent, 0)
        return activities
            .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .filter { it.first != context.packageName }
            .distinctBy { it.first }
            .map { App(it.first, it.second) }
            .sortedBy { it.label.lowercase() }
    }

    /** Launcher icon as PNG, scaled to [sizePx]. */
    fun iconPng(packageName: String, sizePx: Int = 96): ByteArray? = try {
        val drawable = context.packageManager.getApplicationIcon(packageName)
        val bitmap = drawable.toBitmap(sizePx)
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    } catch (_: Exception) {
        null
    }

    private fun Drawable.toBitmap(size: Int): Bitmap {
        if (this is BitmapDrawable && bitmap != null) {
            return Bitmap.createScaledBitmap(bitmap, size, size, true)
        }
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        setBounds(0, 0, size, size)
        draw(canvas)
        return bitmap
    }
}
