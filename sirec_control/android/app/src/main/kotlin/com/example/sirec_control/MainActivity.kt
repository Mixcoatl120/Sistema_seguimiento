package com.example.sirec_control

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "sirec_control/notifications"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showPersistentNotification" -> {
                    showPersistentNotification()
                    result.success(true)
                }
                "hideNotification" -> {
                    hideNotification()
                    result.success(true)
                }
                "showCustomNotification" -> {
                    val title = call.argument<String>("titulo") ?: "Sirec"
                    val message = call.argument<String>("mensaje") ?: "Notificación"
                    showCustom(title, message)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Crear NotificationChannel para el servicio foreground (Android O+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "sirec_tracking_channel"
            val name = "Sirec Tracking"
            val descriptionText = "Notificación de seguimiento en segundo plano"
            val importance = NotificationManager.IMPORTANCE_LOW

            val channel = NotificationChannel(
                channelId,
                name,
                importance
            )
            channel.description = descriptionText

            val notificationManager: NotificationManager =
                getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showPersistentNotification() {
        val notification = NotificationCompat.Builder(this, "sirec_tracking_channel")
            .setContentTitle("Sirec está rastreando tu ubicación")
            .setContentText("Tu ubicación se está registrando en segundo plano.")
            .setOngoing(true)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(1001, notification)
    }

    private fun hideNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.cancel(1001)
    }

    private fun showCustom(title: String, message: String) {
        val notification = NotificationCompat.Builder(this, "sirec_tracking_channel")
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .build()

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(2001, notification)
    }
}



