package com.github.florent37.assets_audio_player.notification

import java.io.Serializable

sealed class NotificationAction(val playerId: String) : Serializable {
    
    companion object {
        const val ACTION_STOP = "stop"
        const val ACTION_NEXT = "next"
        const val ACTION_PREV = "prev"
        const val ACTION_TOGGLE = "toggle"
        const val ACTION_SELECT = "select"
    }
    
    class Show(
            val isPlaying: Boolean,
            val audioMetas: AudioMetas,
            playerId: String
    ) : NotificationAction(playerId= playerId) {
        fun copyWith(isPlaying: Boolean? = null, audioMetas: AudioMetas? = null, playerId: String? = null) : Show{
            return Show(
                    isPlaying= isPlaying ?: this.isPlaying,
                    audioMetas = audioMetas ?: this.audioMetas,
                    playerId = playerId ?: this.playerId
            )
        }
    }

    class Hide(playerId: String) : NotificationAction(playerId= playerId)
}
