package com.example.wakemeup

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Foreground service that spins up a headless Flutter engine after device
 * reboot and calls [bootCallbackDispatcher] to re-register active geofences.
 * Stops itself once the Dart side signals completion (or after a 15-second
 * safety timeout).
 */
class GeofenceRestoreService : Service() {

    companion object {
        private const val CHANNEL_ID = "geofence_restore_channel"
        private const val NOTIFICATION_ID = 8888
        private const val TIMEOUT_MS = 15_000L
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Thread {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                if (!loader.initialized()) {
                    loader.startInitialization(applicationContext)
                }
                loader.ensureInitializationComplete(applicationContext, null)

                val group = FlutterEngineGroup(applicationContext)
                val entrypoint = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "bootCallbackDispatcher"
                )
                val engine = group.createAndRunEngine(applicationContext, entrypoint)

                // Listen for the Dart "complete" signal
                val channel = MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    "com.example.wakemeup/boot"
                )
                var done = false
                channel.setMethodCallHandler { call, result ->
                    if (call.method == "complete") {
                        done = true
                        result.success(null)
                        engine.destroy()
                        stopSelf()
                    }
                }

                // Safety timeout — stop regardless of Dart completion
                val deadline = System.currentTimeMillis() + TIMEOUT_MS
                while (!done && System.currentTimeMillis() < deadline) {
                    Thread.sleep(500)
                }
                if (!done) {
                    engine.destroy()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                stopSelf()
            }
        }.start()

        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Restore",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Restoring location alarms after reboot"
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("WakeMeUp")
            .setContentText("Restoring your location alarms…")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
