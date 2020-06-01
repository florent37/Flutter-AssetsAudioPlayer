package com.github.florent37.assets_audio_player.notification

import java.io.Serializable

class NotificationSettings(
        val nextEnabled: Boolean,
        val playPauseEnabled: Boolean,
        val prevEnabled: Boolean,

        //android only
        val stopEnabled: Boolean,
        val seekBarEnabled: Boolean
) : Serializable {
    fun numberEnabled() : Int {
        var number = 0
        if(nextEnabled) number++
        if(playPauseEnabled) number++
        if(prevEnabled) number++
        if(stopEnabled) number++
        return number
    }
}

fun fetchNotificationSettings(from: Map<*, *>) : NotificationSettings {
    return NotificationSettings(
            nextEnabled= from["notif.settings.nextEnabled"] as? Boolean ?: true,
            stopEnabled= from["notif.settings.stopEnabled"] as? Boolean ?: true,
            playPauseEnabled = from["notif.settings.playPauseEnabled"] as? Boolean ?: true,
            prevEnabled = from["notif.settings.prevEnabled"] as? Boolean ?: true,
            seekBarEnabled = from["notif.settings.seekBarEnabled"] as? Boolean ?: true
    )
}