package com.carbontrace.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and caches the engine so the background service can
 * reach the Dart recorder through the same MethodChannel.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val ENGINE_ID = "carbontrace_engine"
        const val CHANNEL = "carbontrace/recorder"
        const val OBD_CHANNEL = "carbontrace/obd"
        var channel: MethodChannel? = null
    }

    private var obd: ObdBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        obd = ObdBridge(this).also {
            it.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OBD_CHANNEL))
        }
    }

    override fun onDestroy() {
        obd?.disconnect()
        super.onDestroy()
    }
}
