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

class MainActivity : FlutterActivity() {
    companion object {
        private const val RIDER_JOBS_CHANNEL_ID = "naijago_rider_jobs_v1"
        private const val RIDER_SOUND_RESOURCE = "rider_job_alert"
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
            android.net.Uri.parse("android.resource://$packageName/$soundResourceId")
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
