package com.github.florent37.assets_audio_player.notification

import java.io.Serializable

class NotificationSettings(
        val nextEnabled: Boolean,
        val playPauseEnabled: Boolean,
        val prevEnabled: Boolean,

        //android only
        val stopEnabled: Boolean
) : Serializable

fun fetchNotificationSettings(from: Map<*, *>) : NotificationSettings {
    return NotificationSettings(
            nextEnabled= from["notif.settings.nextEnabled"] as? Boolean ?: true,
            stopEnabled= from["notif.settings.stopEnabled"] as? Boolean ?: true,
            playPauseEnabled = from["notif.settings.playPauseEnabled"] as? Boolean ?: true,
            prevEnabled = from["notif.settings.prevEnabled"] as? Boolean ?: true
    )
}