package com.github.florent37.assets_audio_player

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import android.os.Handler
import io.flutter.plugin.common.MethodChannel

class Player {
    // To handle position updates.
    private val handler = Handler()

    private var mediaPlayer: MediaPlayer? = null

    //region outputs
    var onVolumeChanged : ((Double) -> Unit)? = null
    var onReadyToPlay : ((Long) -> Unit)? = null
    var onPositionChanged : ((Long) -> Unit)? = null
    var onFinished : (() -> Unit)? = null
    var onPlaying : ((Boolean) -> Unit)? = null
    //endregion

    val isPlaying: Boolean
        get() = mediaPlayer != null && mediaPlayer!!.isPlaying

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

                    // Update every 300ms.
                    handler.postDelayed(this, 300)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    fun open(assetAudioPath: String?, audioType: String, autoStart: Boolean, volume: Double, seek: Int?, result: MethodChannel.Result, context: Context) {
        stop()

        this.mediaPlayer = MediaPlayer()

        try {

            if(audioType == "network"){
                mediaPlayer?.reset();
                mediaPlayer?.setDataSource(context, Uri.parse(assetAudioPath))
            } else if(audioType == "file"){
                mediaPlayer?.reset();
                mediaPlayer?.setDataSource(context, Uri.parse(assetAudioPath))
            } else { //asset
                context.assets.openFd("flutter_assets/$assetAudioPath").also {
                    mediaPlayer?.reset();
                    mediaPlayer?.setDataSource(it.fileDescriptor, it.startOffset, it.declaredLength)
                }.close()
            }
        } catch (e: Exception) {
            onPositionChanged?.invoke(0)
            e.printStackTrace()
            result.error("OPEN", e.message, null)
            return
        }

        try {
            mediaPlayer?.setOnPreparedListener {
                //retrieve duration in seconds
                val duration = mediaPlayer?.duration ?: 0
                val totalDurationSeconds = (duration.toLong() / 1000)

                onReadyToPlay?.invoke(totalDurationSeconds)

                if (autoStart) {
                    play()
                }
                setVolume(volume)

                seek?.let {
                    this.seek(seconds = seek)
                }
            }
            mediaPlayer?.prepare()
        } catch (e: Exception) {
            onPositionChanged?.invoke(0)
            e.printStackTrace()
            result.error("OPEN", e.message, null)
            return
        }

        mediaPlayer?.setOnCompletionListener {
            this.onFinished?.invoke()
            stop()
        }
    }

    fun stop() {
        mediaPlayer?.apply {
            // Reset duration and position.
            // handler.removeCallbacks(updatePosition);
            // channel.invokeMethod("player.duration", 0);
            onPositionChanged?.invoke(0)

            mediaPlayer?.stop()
            mediaPlayer?.reset()
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
        mediaPlayer?.apply {
            start()
            handler.post(updatePosition)
            onPlaying?.invoke(true)
        }
    }

    fun pause() {
        mediaPlayer?.apply {
            pause()
            handler.removeCallbacks(updatePosition)
            onPlaying?.invoke(false)
        }
    }

    fun seek(seconds: Int) {
        mediaPlayer?.apply {
            seekTo(seconds * 1000)
            onPositionChanged?.invoke(currentPosition / 1000L)
        }
    }

    fun setVolume(volume: Double) {
        mediaPlayer?.let {
            it.setVolume(volume.toFloat(), volume.toFloat());
            onVolumeChanged?.invoke(volume)
        }
    }
}
