package dev.openblock.app

import dev.openblock.app.bank.BankGuard
import dev.openblock.app.bridge.PlatformChannel
import dev.openblock.app.widget.ProgressWidget
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var platformChannel: PlatformChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        platformChannel = PlatformChannel(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onResume() {
        super.onResume()
        // Opening OpenBlock means the banking app was left.
        BankGuard.resume(this)
        ProgressWidget.refresh(this)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        platformChannel?.dispose()
        platformChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
