package dev.openblock.app.bank

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import dev.openblock.app.MainActivity
import dev.openblock.app.R
import dev.openblock.app.storage.NativeStore
import dev.openblock.app.usage.UsageReader

/**
 * Runs only while [BankGuard] has the accessibility service turned off. It
 * watches usage events for the next app brought to the front and turns the
 * service back on as soon as that app has rules. Switching between apps
 * without rules (for example to copy a code), or locking and unlocking the
 * phone, keeps the service off, so the banking app does not see it again on
 * return. Polling stops while the screen is off.
 */
class BankGuardService : Service() {
    private lateinit var store: NativeStore
    private lateinit var usage: UsageReader
    private val handler = Handler(Looper.getMainLooper())
    private var checkedUntilMs = 0L

    private val screen = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            // Events from while the screen was off are read on the next poll.
            handler.removeCallbacks(poll)
            if (intent.action == Intent.ACTION_SCREEN_ON) handler.post(poll)
        }
    }

    private val poll = object : Runnable {
        override fun run() {
            checkForeground()
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        store = NativeStore.get(this)
        usage = UsageReader(this)
        checkedUntilMs = System.currentTimeMillis()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screen, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(screen, filter)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        if (!store.isBankPaused()) {
            stopSelf()
            return START_NOT_STICKY
        }
        handler.removeCallbacks(poll)
        handler.post(poll)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        unregisterReceiver(screen)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkForeground() {
        if (!store.isBankPaused()) {
            stopSelf()
            return
        }
        val config = store.config()
        if (config.bankPackages.isEmpty()) {
            BankGuard.resume(this)
            return
        }
        val nowMs = System.currentTimeMillis()
        val pkg = usage.lastResumedPackage(checkedUntilMs - OVERLAP_MS, nowMs)
        checkedUntilMs = nowMs
        if (pkg == null || pkg in config.bankPackages) return
        if (config.rulesFor(pkg).any { it.enabled }) BankGuard.resume(this)
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.bank_guard_channel),
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        // Opening OpenBlock turns blocking back on (see MainActivity).
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(getString(R.string.bank_guard_title))
            .setContentText(getString(R.string.bank_guard_text))
            .setStyle(Notification.BigTextStyle().bigText(getString(R.string.bank_guard_text)))
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val CHANNEL_ID = "bank_guard"
        private const val NOTIFICATION_ID = 1
        private const val POLL_MS = 1_000L

        /** Usage events can be written slightly after they happen. */
        private const val OVERLAP_MS = 2_000L
    }
}
