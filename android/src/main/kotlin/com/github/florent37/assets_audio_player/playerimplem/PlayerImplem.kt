package com.github.florent37.assets_audio_player.playerimplem

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin

typealias DurationMS = Long

abstract class PlayerImplem(
        val onFinished: (() -> Unit),
        val onBuffering: ((Boolean) -> Unit),
        val onError: ((Throwable) -> Unit)
) {
    abstract val isPlaying: Boolean
    abstract val currentPositionMs: Long
    abstract fun stop()
    abstract fun play()
    abstract fun pause()
    abstract suspend fun open(context: Context,
                     flutterAssets: FlutterPlugin.FlutterAssets,
                     assetAudioPath: String?,
                     audioType: String,
                     assetAudioPackage: String?
    ) : DurationMS
    abstract fun release()
    abstract fun seekTo(to: Long)
    abstract fun setVolume(volume: Float)
    abstract fun setPlaySpeed(playSpeed: Float)
}