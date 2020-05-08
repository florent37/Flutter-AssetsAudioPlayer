package com.github.florent37.assets_audio_player

import android.content.Context
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import com.google.android.exoplayer2.*
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory
import com.google.android.exoplayer2.source.MediaSource
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.upstream.AssetDataSource
import com.google.android.exoplayer2.upstream.DataSource
import com.google.android.exoplayer2.upstream.DataSpec
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory
import io.flutter.plugin.common.MethodChannel

/**
 * Does not depend on Flutter, feel free to use it in all your projects
 */
class Player(context: Context) {

    private val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    // To handle position updates.
    private val handler = Handler()

    private var mediaPlayer: ExoPlayer? = null

    //region outputs
    var onVolumeChanged: ((Double) -> Unit)? = null
    var onPlaySpeedChanged: ((Double) -> Unit)? = null
    var onReadyToPlay: ((Long) -> Unit)? = null
    var onPositionChanged: ((Long) -> Unit)? = null
    var onFinished: (() -> Unit)? = null
    var onPlaying: ((Boolean) -> Unit)? = null
    //endregion

    private var respectSilentMode: Boolean = false
    private var volume: Double = 1.0
    private var playSpeed: Double = 1.0

    val isPlaying: Boolean
        get() = mediaPlayer != null && mediaPlayer!!.isPlaying

    private var lastRingerMode: Int? = null //see https://developer.android.com/reference/android/media/AudioManager.html?hl=fr#getRingerMode()

    private val updatePosition = object : Runnable {
        override fun run() {
            mediaPlayer?.let { mediaPlayer ->
                try {
                    if (!mediaPlayer.isPlaying) {
                        handler.removeCallbacks(this)
                    }

                    val position = mediaPlayer.currentPosition / 1000L

                    // Send position (seconds) to the application.
                    onPositionChanged?.invoke(position)

                    if(respectSilentMode){
                        val ringerMode = am.ringerMode
                        if(lastRingerMode != ringerMode){ //if changed
                            lastRingerMode = ringerMode
                            setVolume(volume) //re-apply volume if changed
                        }
                    }

                    // Update every 300ms.
                    handler.postDelayed(this, 300)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    fun open(assetAudioPath: String?,
             audioType: String,
             autoStart: Boolean,
             volume: Double,
             seek: Int?,
             respectSilentMode: Boolean,
             result: MethodChannel.Result, context: Context) {
        stop()

        this.mediaPlayer = SimpleExoPlayer.Builder(context).build();

        this.respectSilentMode = respectSilentMode

        lateinit var mediaSource: MediaSource
        try {
            if (audioType == "network") {
                mediaPlayer?.stop();
                mediaSource = ProgressiveMediaSource
                        .Factory(DefaultDataSourceFactory(context, "assets_audio_player"), DefaultExtractorsFactory())
                        .createMediaSource(Uri.parse(assetAudioPath))
            } else if (audioType == "file") {
                mediaPlayer?.stop()
                mediaSource = ProgressiveMediaSource
                        .Factory(DefaultDataSourceFactory(context, "assets_audio_player"), DefaultExtractorsFactory())
                        .createMediaSource(Uri.parse(assetAudioPath))
            } else { //asset
                mediaPlayer?.stop()

                val dataSpec = DataSpec(Uri.parse("assets:///flutter_assets/$assetAudioPath"))
                val assetDataSource = AssetDataSource(context)
                assetDataSource.open(dataSpec)

                val factory = DataSource.Factory { assetDataSource }
                mediaSource = ProgressiveMediaSource
                        .Factory(factory, DefaultExtractorsFactory())
                        .createMediaSource(assetDataSource.uri)
            }
        } catch (e: Exception) {
            onPositionChanged?.invoke(0)
            e.printStackTrace()
            result.error("OPEN", e.message, null)
            return
        }

        this.mediaPlayer?.addListener(object: Player.EventListener {

            override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {
                when(playbackState){
                    ExoPlayer.STATE_ENDED -> {
                        this@Player.onFinished?.invoke()
                        stop()
                    }
                    ExoPlayer.STATE_READY -> {
                        //retrieve duration in seconds
                        val duration = mediaPlayer?.duration ?: 0
                        val totalDurationSeconds = (duration.toLong() / 1000)

                        onReadyToPlay?.invoke(totalDurationSeconds)

                        if (autoStart) {
                            play()
                        }
                        setVolume(volume)

                        seek?.let {
                            this@Player.seek(seconds = seek)
                        }
                    }
                    else -> {}
                }
            }
        })

        mediaPlayer?.prepare(mediaSource)
    }

    fun stop() {
        mediaPlayer?.apply {
            // Reset duration and position.
            // handler.removeCallbacks(updatePosition);
            // channel.invokeMethod("player.duration", 0);
            onPositionChanged?.invoke(0)

            mediaPlayer?.stop()
            mediaPlayer?.release()
            onPlaying?.invoke(false)
            handler.removeCallbacks(updatePosition)
        }
        mediaPlayer = null
    }


    fun toggle() {
        if (isPlaying) {
            pause()
        } else {
            play()
        }
    }

    fun play() {
        mediaPlayer?.let {
            it.playWhenReady = true
            handler.post(updatePosition)
            onPlaying?.invoke(true)
        }
    }

    fun pause() {
        mediaPlayer?.let {
            it.playWhenReady = false
            handler.removeCallbacks(updatePosition)
            onPlaying?.invoke(false)
        }
    }

    fun seek(seconds: Int) {
        mediaPlayer?.apply {
            seekTo(seconds * 1000L)
            onPositionChanged?.invoke(currentPosition / 1000L)
        }
    }

    fun setVolume(volume: Double) {
        this.volume = volume
        mediaPlayer?.let {
            var v = volume
            if (this.respectSilentMode) {
                v = when (am.ringerMode) {
                    AudioManager.RINGER_MODE_SILENT, AudioManager.RINGER_MODE_VIBRATE -> 0.toDouble()
                    else -> volume //AudioManager.RINGER_MODE_NORMAL
                }
            }

            it.audioComponent?.volume = v.toFloat();

            onVolumeChanged?.invoke(this.volume) //only notify the setted volume, not the silent mode one
        }
    }

    fun setPlaySpeed(playSpeed: Double) {
        this.playSpeed = playSpeed
        mediaPlayer?.let {
            it.setPlaybackParameters(PlaybackParameters(playSpeed.toFloat()))
            onPlaySpeedChanged?.invoke(this.playSpeed) //only notify the setted volume, not the silent mode one
        }
    }
}
