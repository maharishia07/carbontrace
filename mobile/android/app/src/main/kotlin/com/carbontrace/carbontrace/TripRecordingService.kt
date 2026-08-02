package com.carbontrace.carbontrace

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service that keeps the app alive while a trip records.
 *
 * Android requires the persistent notification â€” it doubles as the user's
 * assurance that trip recording is active. The actual GPS capture runs in
 * Dart (TripRecorder); this service (re)creates or reuses the cached
 * Flutter engine headlessly and signals Dart over the MethodChannel.
 */
class TripRecordingService : Service() {
    companion object {
        const val ACTION_STOP = "com.carbontrace.app.STOP_RECORDING"
        const val NOTIF_CHANNEL = "carbontrace_trip"
        const val NOTIF_ID = 1101
    }

    private var channel: MethodChannel? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            channel?.invokeMethod("autoStop", null)
                ?: MainActivity.channel?.invokeMethod("autoStop", null)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIF_ID, buildNotification())

        // Reuse the UI engine if the app is open; otherwise run headless.
        val engine = FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)
            ?: FlutterEngine(this).also {
                it.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
                )
                FlutterEngineCache.getInstance().put(MainActivity.ENGINE_ID, it)
            }
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, MainActivity.CHANNEL)
        channel?.invokeMethod("autoStart", mapOf("reason" to (intent?.getStringExtra("reason") ?: "unknown")))
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIF_CHANNEL, "Trip recording",
                    NotificationManager.IMPORTANCE_LOW
                ).apply { description = "Shown while CarbonTrace records a trip" }
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, NOTIF_CHANNEL) else Notification.Builder(this)
        return builder
            .setContentTitle("CarbonTrace â€” trip recording")
            .setContentText("Tracking this drive's COâ‚‚. Tap to open.")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

