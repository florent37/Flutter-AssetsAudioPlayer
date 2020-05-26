package com.github.florent37.assets_audio_player.notification

import android.content.Context
import android.content.Intent
import com.github.florent37.assets_audio_player.AssetsAudioPlayerPlugin

class NotificationManager(private val context: Context) {

    var closed = false

    fun showNotification(playerId: String, audioMetas: AudioMetas, isPlaying: Boolean, notificationSettings: NotificationSettings) {
        if(closed)
            return
        context.startService(Intent(context, NotificationService::class.java).apply {
            putExtra(NotificationService.EXTRA_NOTIFICATION_ACTION, NotificationAction.Show(
                    isPlaying = isPlaying,
                    audioMetas = audioMetas,
                    playerId = playerId,
                    notificationSettings= notificationSettings
            ))
        })
        AssetsAudioPlayerPlugin.instance?.assetsAudioPlayer?.registerLastPlayerWithNotif(playerId)
    }

    fun hideNotification(definitively: Boolean = false) {
        //if remainingNotif == 0, stop
        context.stopService(Intent(context, NotificationService::class.java))
        closed = definitively
    }
}