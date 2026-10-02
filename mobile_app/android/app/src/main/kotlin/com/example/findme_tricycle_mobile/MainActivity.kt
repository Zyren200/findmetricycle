package com.example.findme_tricycle_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    // Push notifications from the backend (Firebase) name one of these
    // channels. Ride requests and ride updates are high importance so they
    // pop up over other apps with sound — a rider has seconds to accept.
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel("ride_requests", "Ride requests", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "New ride requests while you're online"
                enableVibration(true)
            }
        )
        manager.createNotificationChannel(
            NotificationChannel("ride_updates", "Ride updates", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Your rider accepted, arrived, trip started or completed"
            }
        )
        manager.createNotificationChannel(
            NotificationChannel("announcements", "Announcements", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "News from FindMeTricycle"
            }
        )
    }
}
