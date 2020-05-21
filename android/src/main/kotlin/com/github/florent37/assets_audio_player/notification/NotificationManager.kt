package com.github.florent37.assets_audio_player.notification

import android.content.Context
import android.content.Intent
import com.github.florent37.assets_audio_player.AssetsAudioPlayerPlugin

class NotificationManager(private val context: Context) {

    fun showNotification(playerId: String, audioMetas: AudioMetas, isPlaying: Boolean) {
        context.startService(Intent(context, NotificationService::class.java).apply {
            putExtra(NotificationService.EXTRA_NOTIFICATION_ACTION, NotificationAction.Show(
                    isPlaying = isPlaying,
                    audioMetas = audioMetas,
                    playerId = playerId
            ))
        })
        AssetsAudioPlayerPlugin.instance?.assetsAudioPlayer?.registerLastPlayerWithNotif(playerId)
    }

    fun hideNotification() {
        //if remainingNotif == 0, stop
        context.stopService(Intent(context, NotificationService::class.java))
    }
}