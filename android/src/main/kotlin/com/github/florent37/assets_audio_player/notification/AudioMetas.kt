package com.github.florent37.assets_audio_player.notification

import java.io.Serializable

class AudioMetas(
        val title: String?,
        val artist: String?,
        val album: String?,
        val image: String?,
        val imageType: String?,
        val imagePackage: String?,
        val trackID: String?
) : Serializable

fun fetchAudioMetas(from: Map<*, *>) : AudioMetas {
    return AudioMetas(
            title = from["song.title"] as? String,
            artist = from["song.artist"] as? String,
            album = from["song.album"] as? String,
            image = from["song.image"] as? String,
            imageType = from["song.imageType"] as? String,
            imagePackage = from["song.imagePackage"] as? String,
            trackID = from["song.trackID"] as? String
    )
}