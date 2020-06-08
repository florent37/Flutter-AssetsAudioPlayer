package com.github.florent37.assets_audio_player.playerimplem

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import com.github.florent37.assets_audio_player.Player
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

class PlayerImplemMediaPlayer(
        onFinished: (() -> Unit),
        onBuffering: ((Boolean) -> Unit),
        onError: ((Throwable) -> Unit)
) : PlayerImplem(
        onFinished = onFinished,
        onBuffering = onBuffering,
        onError = onError
) {
    private var mediaPlayer: MediaPlayer? = null

    override val isPlaying: Boolean
        get() = try { mediaPlayer?.isPlaying ?: false } catch (t: Throwable) { false }
    override val currentPositionMs: Long
        get() = try { mediaPlayer?.currentPosition?.toLong() ?: 0 } catch (t: Throwable) { 0 }

    override var loopSingleAudio: Boolean
        get() = mediaPlayer?.isLooping ?: false
        set(value) {
            mediaPlayer?.isLooping = value
        }
    
    override fun stop() {
        mediaPlayer?.stop()
    }

    override fun play() {
        mediaPlayer?.start()
    }

    override fun pause() {
        mediaPlayer?.pause()
    }

    override suspend fun open(
            context: Context,
            flutterAssets: FlutterPlugin.FlutterAssets,
            assetAudioPath: String?,
            audioType: String,
            networkHeaders: Map<*, *>?,
            assetAudioPackage: String?
    ): DurationMS = suspendCoroutine { continuation ->
        this.mediaPlayer = MediaPlayer()
        
        when (audioType) {
            Player.AUDIO_TYPE_NETWORK, Player.AUDIO_TYPE_LIVESTREAM -> {
                mediaPlayer?.reset()
                networkHeaders?.toMapString()?.let {
                    mediaPlayer?.setDataSource(context, Uri.parse(assetAudioPath), it)
                } ?: run {
                    //without headers
                    mediaPlayer?.setDataSource(assetAudioPath)
                }
            }
            Player.AUDIO_TYPE_FILE-> {
                mediaPlayer?.reset();
                mediaPlayer?.setDataSource(context, Uri.parse("file:///"+assetAudioPath))
            }
            else -> { //asset
                context.assets.openFd("flutter_assets/$assetAudioPath").also {
                    mediaPlayer?.reset();
                    mediaPlayer?.setDataSource(it.fileDescriptor, it.startOffset, it.declaredLength)
                }.close()
            }
        }

        mediaPlayer?.setOnCompletionListener {
            this.onFinished.invoke()
        }

        try {
            mediaPlayer?.setOnPreparedListener {
                //retrieve duration in seconds
                val duration = mediaPlayer?.duration ?: 0
                val totalDurationMs = duration.toLong()

                continuation.resume(totalDurationMs)
            }
            mediaPlayer?.prepare()
        } catch (t: Throwable){
            continuation.resumeWithException(t)
        }
    }

    override fun release() {
        mediaPlayer?.release()
    }

    override fun seekTo(to: Long) {
        mediaPlayer?.seekTo(to.toInt())
    }

    override fun setVolume(volume: Float) {
        mediaPlayer?.setVolume(volume, volume)
    }

    override fun setPlaySpeed(playSpeed: Float) {
        //not possible
    }

}

fun Map<*,*>.toMapString() : Map<String, String> {
    val result = mutableMapOf<String, String>()
    this.forEach {
        it.key?.let { key ->
            it.value?.let { value ->
                result[key.toString()] = value.toString()
            }
        }
    }
    return result
}