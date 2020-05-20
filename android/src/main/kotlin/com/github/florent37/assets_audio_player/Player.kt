package com.github.florent37.assets_audio_player

import StopWhenCall
import android.content.Context
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import android.os.Message
import com.github.florent37.assets_audio_player.notification.AudioMetas
import com.github.florent37.assets_audio_player.notification.NotificationManager
import com.google.android.exoplayer2.*
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory
import com.google.android.exoplayer2.source.MediaSource
import com.google.android.exoplayer2.source.ProgressiveMediaSource
import com.google.android.exoplayer2.upstream.AssetDataSource
import com.google.android.exoplayer2.upstream.DataSource
import com.google.android.exoplayer2.upstream.DataSpec
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max

/**
 * Does not depend on Flutter, feel free to use it in all your projects
 */
class Player(
        val id: String,
        context: Context,
        private val stopWhenCall: StopWhenCall,
        private val notificationManager: NotificationManager,
        private val flutterAssets: FlutterPlugin.FlutterAssets
) {

    companion object {
        const val VOLUME_WHEN_REDUCED = 0.3

        const val AUDIO_TYPE_NETWORK = "network"
        const val AUDIO_TYPE_LIVESTREAM = "liveStream"
        const val AUDIO_TYPE_FILE = "file"
        const val AUDIO_TYPE_ASSET = "asset"
    }

    private val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    // To handle position updates.
    private val handler = Handler()

    private var mediaPlayer: ExoPlayer? = null

    //region outputs
    var onVolumeChanged: ((Double) -> Unit)? = null
    var onPlaySpeedChanged: ((Double) -> Unit)? = null
    var onForwardRewind: ((Double) -> Unit)? = null
    var onReadyToPlay: ((Long) -> Unit)? = null
    var onPositionChanged: ((Long) -> Unit)? = null
    var onFinished: (() -> Unit)? = null
    var onPlaying: ((Boolean) -> Unit)? = null
    var onBuffering: ((Boolean) -> Unit)? = null
    var onNext: (() -> Unit)? = null
    var onPrev: (() -> Unit)? = null
    var onStop: (() -> Unit)? = null
    var onNotificationPlayOrPause: (() -> Unit)? = null
    //endregion

    private var respectSilentMode: Boolean = false
    private var volume: Double = 1.0
    private var playSpeed: Double = 1.0

    private var isEnabledToPlayPause: Boolean = true
    private var isEnabledToChangeVolume: Boolean = true

    val isPlaying: Boolean
        get() = mediaPlayer != null && mediaPlayer!!.isPlaying

    private var lastRingerMode: Int? = null //see https://developer.android.com/reference/android/media/AudioManager.html?hl=fr#getRingerMode()

    private var displayNotification = false
    private var audioMetas: AudioMetas? = null

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

                    if (respectSilentMode) {
                        val ringerMode = am.ringerMode
                        if (lastRingerMode != ringerMode) { //if changed
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

    fun next() {
        this.onNext?.invoke()
    }

    fun prev() {
        this.onPrev?.invoke()
    }

    fun open(assetAudioPath: String?,
             assetAudioPackage: String?,
             audioType: String,
             autoStart: Boolean,
             volume: Double,
             seek: Int?,
             respectSilentMode: Boolean,
             displayNotification: Boolean,
             audioMetas: AudioMetas,
             playSpeed: Double,
             result: MethodChannel.Result,
             context: Context
    ) {
        stop(pingListener = false)

        this.mediaPlayer = SimpleExoPlayer.Builder(context).build();
        this.displayNotification = displayNotification
        this.audioMetas = audioMetas
        this.respectSilentMode = respectSilentMode

        lateinit var mediaSource: MediaSource
        try {
            mediaPlayer?.stop()
            if (audioType == AUDIO_TYPE_NETWORK || audioType == AUDIO_TYPE_LIVESTREAM) {
                mediaSource = ProgressiveMediaSource
                        .Factory(DefaultDataSourceFactory(context, "assets_audio_player"), DefaultExtractorsFactory())
                        .createMediaSource(Uri.parse(assetAudioPath))
            } else if (audioType == AUDIO_TYPE_FILE) {
                mediaSource = ProgressiveMediaSource
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

        var onThisMediaReady = false
        this.mediaPlayer?.addListener(object : Player.EventListener {

            override fun onPlayerError(error: ExoPlaybackException) {
                result.error("OPEN", error.message, null)
            }

            override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {
                when (playbackState) {
                    ExoPlayer.STATE_ENDED -> {
                        pause()
                        this@Player.onFinished?.invoke()
                        this@Player.onBuffering?.invoke(false)
                    }
                    ExoPlayer.STATE_BUFFERING -> {
                        this@Player.onBuffering?.invoke(true)
                    }
                    ExoPlayer.STATE_READY -> {
                        this@Player.onBuffering?.invoke(false)
                        if (!onThisMediaReady) {
                            onThisMediaReady = true
                            //retrieve duration in seconds
                            if(audioType == AUDIO_TYPE_LIVESTREAM) {
                                onReadyToPlay?.invoke(0) //no duration for livestream
                            } else {
                                val duration = mediaPlayer?.duration ?: 0
                                val totalDurationSeconds = (duration.toLong() / 1000)

                                onReadyToPlay?.invoke(totalDurationSeconds)
                            }

                            if (autoStart) {
                                play()
                            }
                            updateNotif()
                            setVolume(volume)
                            setPlaySpeed(playSpeed)

                            seek?.let {
                                this@Player.seek(milliseconds = seek * 1000L)
                            }

                            result.success(null)
                        }
                    }
                    else -> {
                    }
                }
            }
        })

        mediaPlayer?.prepare(mediaSource)
    }

    fun stop(pingListener: Boolean = true) {
        mediaPlayer?.apply {
            // Reset duration and position.
            // handler.removeCallbacks(updatePosition);
            // channel.invokeMethod("player.duration", 0);
            onPositionChanged?.invoke(0)

            mediaPlayer?.stop()
            mediaPlayer?.release()
            updateNotif()
            onPlaying?.invoke(false)
            handler.removeCallbacks(updatePosition)
        }
        if (forwardHandler != null) {
            forwardHandler!!.stop()
            forwardHandler = null
        }
        onForwardRewind?.invoke(0.0)
        mediaPlayer = null
        if (pingListener) {
            onStop?.invoke()
        }
    }


    fun toggle() {
        if (isPlaying) {
            pause()
        } else {
            play()
        }
    }

    private fun stopForward() {
        forwardHandler?.takeIf { h -> h.isActive }?.let { h ->
            h.stop()
            setPlaySpeed(this.playSpeed)
        }
        onForwardRewind?.invoke(0.0)
    }

    private fun updateNotif() {
        this.audioMetas?.takeIf { this.displayNotification }?.let { audioMetas ->
            notificationManager.showNotification(playerId = id, audioMetas = audioMetas, isPlaying = this.isPlaying)
        }
    }

    fun play() {
        if (isEnabledToPlayPause) { //can be disabled while recieving phone call
            mediaPlayer?.let { player ->
                stopForward()
                player.playWhenReady = true
                handler.post(updatePosition)
                onPlaying?.invoke(true)
                updateNotif()
            }
        } else {
            this.stopWhenCall.requestAudioFocus()
        }
    }

    fun pause() {
        if (isEnabledToPlayPause) {
            mediaPlayer?.let {
                it.playWhenReady = false
                handler.removeCallbacks(updatePosition)

                stopForward()
                onPlaying?.invoke(false)
                updateNotif()
            }
        }
    }

    fun seek(milliseconds: Long) {
        mediaPlayer?.apply {
            val to = max(milliseconds, 0L)
            seekTo(to)
            onPositionChanged?.invoke(currentPosition / 1000L)
        }
    }

    fun seekBy(milliseconds: Long) {
        mediaPlayer?.let {
            val to = it.currentPosition + milliseconds;
            seek(to)
        }
    }

    fun setVolume(volume: Double) {
        if (isEnabledToChangeVolume) {
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
    }

    private var forwardHandler: ForwardHandler? = null;

    fun setPlaySpeed(playSpeed: Double) {
        if (playSpeed >= 0) { //android only take positive play speed
            if (forwardHandler != null) {
                forwardHandler!!.stop()
                forwardHandler = null
            }
            this.playSpeed = playSpeed
            mediaPlayer?.let {
                it.setPlaybackParameters(PlaybackParameters(playSpeed.toFloat()))
                onPlaySpeedChanged?.invoke(this.playSpeed)
            }
        }
    }

    fun forwardRewind(speed: Double) {
        if (forwardHandler == null) {
            forwardHandler = ForwardHandler()
        }

        mediaPlayer?.let {
            it.playWhenReady = false
            //handler.removeCallbacks(updatePosition)
            //onPlaying?.invoke(false)
        }

        onForwardRewind?.invoke(speed)
        forwardHandler!!.start(this, speed)
    }

    private var volumeBeforePhoneStateChanged: Double? = null
    private var wasPlayingBeforeEnablePlayChange: Boolean? = null
    fun updateEnableToPlay(audioState: StopWhenCall.AudioState) {
        when (audioState) {
            StopWhenCall.AudioState.AUTHORIZED_TO_PLAY -> {
                this.isEnabledToPlayPause = true //this one must be called before play/pause()
                this.isEnabledToChangeVolume = true //this one must be called before play/pause()
                wasPlayingBeforeEnablePlayChange?.let {
                    //phone call ended
                    if (it) {
                        play()
                    } else {
                        pause()
                    }
                }
                volumeBeforePhoneStateChanged?.let {
                    setVolume(it)
                }
                wasPlayingBeforeEnablePlayChange = null
                volumeBeforePhoneStateChanged = null
            }
            StopWhenCall.AudioState.REDUCE_VOLUME -> {
                volumeBeforePhoneStateChanged = this.volume
                setVolume(VOLUME_WHEN_REDUCED)
                this.isEnabledToChangeVolume = false //this one must be called after setVolume()
            }
            StopWhenCall.AudioState.FORBIDDEN -> {
                wasPlayingBeforeEnablePlayChange = this.isPlaying
                pause()
                this.isEnabledToPlayPause = false //this one must be called after pause()
            }
        }
    }

    fun askPlayOrPause() {
        this.onNotificationPlayOrPause?.invoke()
    }
}

class ForwardHandler : Handler() {

    companion object {
        const val MESSAGE_FORWARD = 1
        const val DELAY = 300L
    }

    private var player: com.github.florent37.assets_audio_player.Player? = null
    private var speed: Double = 1.0

    val isActive: Boolean
        get() = hasMessages(MESSAGE_FORWARD)

    fun start(player: com.github.florent37.assets_audio_player.Player, speed: Double) {
        this.player = player
        this.speed = speed
        removeMessages(MESSAGE_FORWARD)
        sendEmptyMessage(MESSAGE_FORWARD)
    }

    fun stop() {
        removeMessages(MESSAGE_FORWARD)
        this.player = null
    }

    override fun handleMessage(msg: Message?) {
        super.handleMessage(msg)
        if (msg?.what == MESSAGE_FORWARD) {
            this.player?.let {
                it.seekBy((DELAY * speed).toLong())
                sendEmptyMessageDelayed(MESSAGE_FORWARD, DELAY)
            }
        }
    }
}