package com.github.florent37.assetsaudioplayer

import android.content.Context
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.os.Handler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.Registrar


internal val METHOD_POSITION = "player.position"
internal val METHOD_FINISHED = "player.finished"
internal val METHOD_IS_PLAYING = "player.isPlaying"
internal val METHOD_CURRENT = "player.current"
internal val METHOD_NEXT = "player.next"
internal val METHOD_PREV = "player.prev"

class AssetsAudioPlayerPlugin(private val context: Context, private val channel: MethodChannel) :
        MethodCallHandler {
    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "assets_audio_player")
            channel.setMethodCallHandler(AssetsAudioPlayerPlugin(registrar.context(), channel))
        }
    }

    // To handle position updates.
    private val handler = Handler()

    private var mediaPlayer: MediaPlayer? = null

    private val isPlaying: Boolean
        get() = mediaPlayer != null && mediaPlayer!!.isPlaying

    private val updatePosition = object : Runnable {
        override fun run() {
            mediaPlayer?.let { mediaPlayer ->
                try {
                    if (!mediaPlayer.isPlaying) {
                        handler.removeCallbacks(this)
                    }

                    // Send position (seconds) to the application.
                    channel.invokeMethod(METHOD_POSITION, mediaPlayer.currentPosition / 1000)

                    // Update every 300ms.
                    handler.postDelayed(this, 300)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isPlaying" -> {
                result.success(isPlaying)
            }
            "play" -> {
                play()
                result.success(null)
            }
            "pause" -> {
                pause()
                result.success(null)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            "seek" -> if (call.arguments != null) {
                val to = call.arguments as? Int ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an int.", null)
                    return
                }

                seek(to)
                result.success(null)
            }
            "open" -> if (call.arguments != null) {

                val args = call.arguments() as? Map<*, *> ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<String, Any>.", null)
                    return
                }

                val path = args["path"] as? String ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<String, Any> containing a `path`", null)
                    return
                }
                val autoStart = args["autoStart"] as? Boolean ?: true

                open(
                        path,
                        autoStart,
                        result
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun stop() {
        mediaPlayer?.apply {
            // Reset duration and position.
            // handler.removeCallbacks(updatePosition);
            // channel.invokeMethod("player.duration", 0);
            channel.invokeMethod(METHOD_POSITION, 0)

            mediaPlayer?.stop()
            mediaPlayer?.reset();
            mediaPlayer?.release()
            channel.invokeMethod(METHOD_IS_PLAYING, false)
            handler.removeCallbacks(updatePosition)
        }
        mediaPlayer = null
    }

    private fun open(assetAudioPath: String?, autoStart: Boolean, result: MethodChannel.Result) {
        stop()

        var totalDurationSeconds = 0L

        this.mediaPlayer = MediaPlayer()

        try {
            val mmr = MediaMetadataRetriever()

            val afd = context.assets.openFd("flutter_assets/$assetAudioPath")
            mediaPlayer?.reset();
            mediaPlayer?.setDataSource(afd.fileDescriptor, afd.startOffset, afd.declaredLength)

            mmr.setDataSource(afd.fileDescriptor, afd.startOffset, afd.declaredLength)

            //retrieve duration in seconds
            val duration =
                    mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION).toLong()
            totalDurationSeconds = (duration / 1000)

            mmr.release()

            afd.close()
        } catch (e: Exception) {
            channel.invokeMethod(METHOD_POSITION, 0)
            e.printStackTrace()
            result.error("OPEN", e.message, null)
            return
        }

        try {
            mediaPlayer?.setOnPreparedListener {
                if(autoStart) {
                    play()
                }
            }
            mediaPlayer?.prepare()
        } catch (e: Exception) {
            channel.invokeMethod(METHOD_POSITION, 0)
            e.printStackTrace()
            result.error("OPEN", e.message, null)
            return
        }

        // Send duration to the application.
        // channel.invokeMethod("platform.duration", mediaPlayer.getDuration() / 1000);

        mediaPlayer?.setOnCompletionListener {
            channel.invokeMethod(METHOD_FINISHED, null)
            channel.invokeMethod(METHOD_IS_PLAYING, false)
        }

        channel.invokeMethod(METHOD_CURRENT, mapOf("totalDuration" to totalDurationSeconds))


        //will be done on play
        //result.success(null);
    }

    private fun toggle() {
        if (isPlaying) {
            pause()
        } else {
            play()
        }
    }

    private fun play() {
        mediaPlayer?.apply {
            start()
            handler.post(updatePosition)
            channel.invokeMethod(METHOD_IS_PLAYING, true)
        }
    }

    private fun pause() {
        mediaPlayer?.apply {
            pause()
            handler.removeCallbacks(updatePosition)
            channel.invokeMethod(METHOD_IS_PLAYING, false)
        }
    }

    private fun seek(seconds: Int) {
        mediaPlayer?.apply {
            seekTo(seconds * 1000)
            channel.invokeMethod(METHOD_POSITION, currentPosition / 1000)
        }
    }
}
