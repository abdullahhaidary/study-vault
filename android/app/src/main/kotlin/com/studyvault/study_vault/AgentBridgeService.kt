package com.studyvault.study_vault

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/** Keeps the existing app process available while the user works in Termux.
 * Never restarts automatically: process death invalidates the Dart session key.
 */
class AgentBridgeService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                "study_vault_agent", "Termux agent access", NotificationManager.IMPORTANCE_LOW
            ))
        }
        val open = PendingIntent.getActivity(this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "study_vault_agent") else Notification.Builder(this)
        val notification = builder.setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle("StudyDesk agent access is running")
            .setContentText("Local Termux access enabled. Open Settings to stop.")
            .setContentIntent(open).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(8746, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(8746, notification)
        }
        return START_NOT_STICKY
    }
}
