package com.github.florent37.assets_audio_player

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.Registrar


internal val METHOD_POSITION = "player.position"
internal val METHOD_VOLUME = "player.volume"
internal val METHOD_FINISHED = "player.finished"
internal val METHOD_IS_PLAYING = "player.isPlaying"
internal val METHOD_CURRENT = "player.current"
internal val METHOD_NEXT = "player.next"
internal val METHOD_PREV = "player.prev"


class AssetsAudioPlayerPlugin(private val context: Context, private val messenger: BinaryMessenger, private val channel: MethodChannel) : MethodCallHandler {

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "assets_audio_player")
            channel.setMethodCallHandler(AssetsAudioPlayerPlugin(registrar.context(), registrar.messenger(), channel))
        }

        private val players = mutableMapOf<String, Player>()
    }

    private fun getOrCreatePlayer(id: String): Player {
        return players.getOrPut(id) {
            val channel = MethodChannel(messenger, "assets_audio_player/$id")
            val player = Player(context)
            player.apply {
                onVolumeChanged = { volume ->
                    channel.invokeMethod(METHOD_VOLUME, volume)
                }
                onPositionChanged = { position ->
                    channel.invokeMethod(METHOD_POSITION, position)
                }
                onReadyToPlay = { totalDurationSeconds ->
                    channel.invokeMethod(METHOD_CURRENT, mapOf(
                            "totalDuration" to totalDurationSeconds)
                    )
                }
                onPlaying = {
                    channel.invokeMethod(METHOD_IS_PLAYING, it)
                }
                onFinished = {
                    channel.invokeMethod(METHOD_FINISHED, null)
                }
            }
            return@getOrPut player
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isPlaying" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    getOrCreatePlayer(id).let { player ->
                        result.success(player.isPlaying)
                    }
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "play" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    getOrCreatePlayer(id).play()
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "pause" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    getOrCreatePlayer(id).pause()
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "stop" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    getOrCreatePlayer(id).stop()
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "volume" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    val volume = args["volume"] as? Double ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Double.", null)
                        return
                    }
                    val respectSilentMode = args["respectSilentMode"] as? Boolean ?: false
                    getOrCreatePlayer(id).setVolume(respectSilentMode, volume)
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "seek" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    val to = args["to"] as? Int ?: run {
                        result.error("WRONG_FORMAT", "The specified argument(to) must be an int.", null)
                        return
                    }
                    getOrCreatePlayer(id).seek(to)
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "open" -> {
                (call.arguments as? Map<*, *>)?.let { args ->

                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    val path = args["path"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Map<String, Any> containing a `path`", null)
                        return
                    }
                    val audioType = args["audioType"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Map<String, Any> containing a `audioType`", null)
                        return
                    }
                    val volume = args["volume"] as? Double ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Map<String, Any> containing a `path`", null)
                        return
                    }
                    val autoStart = args["autoStart"] as? Boolean ?: true
                    val respectSilentMode = args["respectSilentMode"] as? Boolean ?: false
                    val seek = args["seek"] as? Int?

                    getOrCreatePlayer(id).open(
                            path,
                            audioType,
                            autoStart,
                            volume,
                            seek,
                            respectSilentMode,
                            result,
                            context
                    )
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            else -> result.notImplemented()
        }
    }
}
