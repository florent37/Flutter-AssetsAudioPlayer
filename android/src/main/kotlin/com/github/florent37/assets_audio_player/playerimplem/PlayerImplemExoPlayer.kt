package com.github.florent37.assets_audio_player.playerimplem

import android.content.Context
import android.net.Uri
import com.github.florent37.assets_audio_player.Player
import com.google.android.exoplayer2.*
import com.google.android.exoplayer2.Player.REPEAT_MODE_ALL
import com.google.android.exoplayer2.Player.REPEAT_MODE_OFF
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory
import com.google.android.exoplayer2.source.MediaSource
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.upstream.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

class PlayerImplemExoPlayer(
        onFinished: (() -> Unit),
        onBuffering: ((Boolean) -> Unit),
        onError: ((Throwable) -> Unit)
) : PlayerImplem(
        onFinished=onFinished, 
        onBuffering=onBuffering, 
        onError=onError
) {

    private var mediaPlayer: ExoPlayer? = null
    
    override var loopSingleAudio: Boolean
        get() = mediaPlayer?.repeatMode == REPEAT_MODE_ALL
        set(value) {
            mediaPlayer?.repeatMode = if(value) REPEAT_MODE_ALL else REPEAT_MODE_OFF
        }

    override val isPlaying: Boolean
        get() = mediaPlayer?.isPlaying ?: false
    override val currentPositionMs: Long
        get() = mediaPlayer?.currentPosition ?: 0

    override fun stop() {
        mediaPlayer?.stop()
    }

    override fun play() {
        mediaPlayer?.playWhenReady = true
    }

    override fun pause() {
        mediaPlayer?.playWhenReady = false
    }

    fun getDataSource( context: Context,
                               flutterAssets: FlutterPlugin.FlutterAssets,
                               assetAudioPath: String?,
                               audioType: String,
                               networkHeaders: Map<*, *>?,
                               assetAudioPackage: String?) : MediaSource {
        try {
            mediaPlayer?.stop()
            if (audioType == Player.AUDIO_TYPE_NETWORK || audioType == Player.AUDIO_TYPE_LIVESTREAM) {
                val uri = Uri.parse(assetAudioPath)
                val userAgent = "assets_audio_player"
                if(networkHeaders == null) {
                    return ProgressiveMediaSource
                            .Factory(DefaultDataSourceFactory(context, userAgent), DefaultExtractorsFactory())
                            .createMediaSource(uri)
                } else {
                    return ProgressiveMediaSource.Factory(DataSource.Factory {
                        val dataSource = DefaultHttpDataSource(userAgent)
                        networkHeaders.forEach {
                            it.key?.let { key ->
                                it.value?.let { value ->
                                    dataSource.setRequestProperty(key.toString(), value.toString())
                                }
                            }
                        }
                        dataSource;
                    }).createMediaSource(uri)
                }
            } else if (audioType == Player.AUDIO_TYPE_FILE) {
                return ProgressiveMediaSource
                        .Factory(DefaultDataSourceFactory(context, "assets_audio_player"), DefaultExtractorsFactory())
                        .createMediaSource(Uri.parse(assetAudioPath))
            } else { //asset
                val path = if (assetAudioPackage.isNullOrBlank()) {
                    flutterAssets.getAssetFilePathByName(assetAudioPath!!)
                } else {
                    flutterAssets.getAssetFilePathByName(assetAudioPath!!, assetAudioPackage)
                }
                val assetDataSource = AssetDataSource(context)
                assetDataSource.open(DataSpec(Uri.parse(path)))

                val factory = DataSource.Factory { assetDataSource }
                return ProgressiveMediaSource
                        .Factory(factory, DefaultExtractorsFactory())
                        .createMediaSource(assetDataSource.uri)
            }
        } catch (e: Exception) {
            throw e
        }
    }

    private fun SimpleExoPlayer.Builder.incrementBufferSize(audioType: String) : SimpleExoPlayer.Builder {
        if (audioType == Player.AUDIO_TYPE_NETWORK || audioType == Player.AUDIO_TYPE_LIVESTREAM) {
            /* Instantiate a DefaultLoadControl.Builder. */
            val loadControlBuilder = DefaultLoadControl.Builder()

/*How many milliseconds of media data to buffer at any time. */
            val loadControlBufferMs = DefaultLoadControl.DEFAULT_MAX_BUFFER_MS /* This is 50000 milliseconds in ExoPlayer 2.9.6 */

/* Configure the DefaultLoadControl to use the same value for */
            loadControlBuilder.setBufferDurationsMs(
                    loadControlBufferMs,
                    loadControlBufferMs,
                    DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                    DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS)

            return this.setLoadControl(loadControlBuilder.createDefaultLoadControl())
        }
        return this
    }

    override suspend fun open(
            context: Context,
            flutterAssets: FlutterPlugin.FlutterAssets,
            assetAudioPath: String?,
            audioType: String,
            networkHeaders: Map<*, *>?,
            assetAudioPackage: String?
    ) = suspendCoroutine<DurationMS> { continuation ->
        var onThisMediaReady = false

        try {
            mediaPlayer = SimpleExoPlayer.Builder(context)
                    .incrementBufferSize(audioType)
                    .build()

            val mediaSource = getDataSource(
                    context=context,
                    flutterAssets=flutterAssets,
                    assetAudioPath=assetAudioPath,
                    audioType= audioType,
                    networkHeaders = networkHeaders,
                    assetAudioPackage= assetAudioPackage
            )

            var lastState : Int? = null

            this.mediaPlayer?.addListener(object : com.google.android.exoplayer2.Player.EventListener {

                override fun onPlayerError(error: ExoPlaybackException) {
                    if(!onThisMediaReady) {
                        continuation.resumeWithException(error)
                    } else {
                        onError(error)
                    }
                }

                override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {
                    if(lastState != playbackState) {
                        when (playbackState) {
                            ExoPlayer.STATE_ENDED -> {
                                pause()
                                onFinished.invoke()
                                onBuffering.invoke(false)
                            }
                            ExoPlayer.STATE_BUFFERING -> {
                                onBuffering.invoke(true)
                            }
                            ExoPlayer.STATE_READY -> {
                                onBuffering.invoke(false)
                                if (!onThisMediaReady) {
                                    onThisMediaReady = true
                                    //retrieve duration in seconds
                                    if (audioType == Player.AUDIO_TYPE_LIVESTREAM) {
                                        continuation.resume(0) //no duration for livestream
                                    } else {
                                        val duration = mediaPlayer?.duration ?: 0
                                        val totalDurationMs = (duration.toLong())

                                        continuation.resume(totalDurationMs)
                                    }
                                }
                            }
                            else -> {
                            }
                        }
                    }
                    lastState = playbackState
                }
            })

            mediaPlayer?.prepare(mediaSource)
        } catch (error: Throwable){
            if(!onThisMediaReady) {
                continuation.resumeWithException(error)
            } else {
                onError(error)
            }
        }
    }

    override fun release() {
        mediaPlayer?.release()
    }

    override fun seekTo(to: Long) {
        mediaPlayer?.seekTo(to)
    }

    override fun setVolume(volume: Float) {
        mediaPlayer?.audioComponent?.volume = volume
    }

    override fun setPlaySpeed(playSpeed: Float) {
        mediaPlayer?.setPlaybackParameters(PlaybackParameters(playSpeed))
    }

}