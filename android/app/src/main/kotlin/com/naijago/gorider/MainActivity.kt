package com.naijago.gorider

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val RIDER_JOBS_CHANNEL_ID = "naijago_rider_jobs_v1"
        private const val RIDER_SOUND_RESOURCE = "rider_job_alert"
    }

    private var alertRingtone: android.media.Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "naijago/rider_alerts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playAlert" -> {
                        try {
                            alertRingtone?.stop()
                            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                                manager.getNotificationChannel(RIDER_JOBS_CHANNEL_ID) else null
                            if (channel != null && (channel.importance == NotificationManager.IMPORTANCE_NONE || channel.sound == null)) {
                                result.success(false)
                                return@setMethodCallHandler
                            }
                            val uri = channel?.sound ?: android.net.Uri.parse("android.resource://$packageName/raw/$RIDER_SOUND_RESOURCE")
                            alertRingtone = RingtoneManager.getRingtone(this, uri)?.apply {
                                audioAttributes = AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
                                play()
                            }
                            result.success(alertRingtone != null)
                        } catch (_: Exception) { result.error("ALERT_UNAVAILABLE", "Unable to play alert", null) }
                    }
                    "openSettings" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    android.net.Uri.parse("package:$packageName"))
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (_: Exception) { result.error("SETTINGS_UNAVAILABLE", "Open notification settings manually", null) }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        alertRingtone?.stop()
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createUrgentNotificationChannels()
    }

    private fun createUrgentNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val soundResourceId = resources.getIdentifier(
            RIDER_SOUND_RESOURCE,
            "raw",
            packageName
        )
        val soundUri = if (soundResourceId != 0) {
            android.net.Uri.parse("android.resource://$packageName/raw/$RIDER_SOUND_RESOURCE")
        } else {
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        }
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        listOf(
            RIDER_JOBS_CHANNEL_ID,
            "naijago_urgent_alerts"
        ).forEach { channelId ->
            val channel = NotificationChannel(
                channelId,
                "NaijaGo Urgent Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Loud alerts for delivery jobs and important rider updates"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 250, 500, 250, 700)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
}
