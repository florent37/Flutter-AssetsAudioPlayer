package com.github.florent37.assets_audio_player

import StopWhenCall
import StopWhenCallAudioFocus
import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import com.github.florent37.assets_audio_player.notification.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry

internal val METHOD_POSITION = "player.position"
internal val METHOD_VOLUME = "player.volume"
internal val METHOD_FORWARD_REWIND_SPEED = "player.forwardRewind"
internal val METHOD_PLAY_SPEED = "player.playSpeed"
internal val METHOD_FINISHED = "player.finished"
internal val METHOD_IS_PLAYING = "player.isPlaying"
internal val METHOD_IS_BUFFERING = "player.isBuffering"
internal val METHOD_CURRENT = "player.current"
internal val METHOD_NEXT = "player.next"
internal val METHOD_PREV = "player.prev"
internal val METHOD_PLAY_OR_PAUSE = "player.playOrPause"
internal val METHOD_NOTIFICATION_STOP = "player.stop"

class AssetsAudioPlayerPlugin : FlutterPlugin,PluginRegistry.NewIntentListener, ActivityAware {

    var myActivity: Activity? = null
    var notificationChannel : MethodChannel ?= null

    companion object {
        var instance: AssetsAudioPlayerPlugin? = null
    }

    var assetsAudioPlayer: AssetsAudioPlayer? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        instance = this
        notificationChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "assets_audio_player_notification")
        assetsAudioPlayer = AssetsAudioPlayer(
                flutterAssets = flutterPluginBinding.flutterAssets,
                context = flutterPluginBinding.applicationContext,
                messenger = flutterPluginBinding.binaryMessenger
        )
        assetsAudioPlayer!!.register();
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        assetsAudioPlayer?.unregister()
        instance = null
    }

    private fun sendNotificationPayloadMessage(intent: Intent): Boolean? {
        if (NotificationAction.ACTION_SELECT == intent.action) {
            val trackId = intent.getStringExtra(NotificationService.TRACK_ID)
            notificationChannel?.invokeMethod("selectNotification", trackId)
            return true
        }
        return false
    }

    override fun onNewIntent(intent: Intent?): Boolean {
        if (!intent!!.getBooleanExtra("isVisited", false)) {
            val res = sendNotificationPayloadMessage(intent!!)!!
            if (res && myActivity != null) {
                myActivity!!.intent = intent
                intent.putExtra("isVisited", true)
            }
            return res
        }
        return false
    }

    override fun onDetachedFromActivity() {
        myActivity = null;
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        binding.addOnNewIntentListener(this);
        myActivity = binding.getActivity();
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        binding.addOnNewIntentListener(this);
        myActivity = binding.getActivity();
    }

    override fun onDetachedFromActivityForConfigChanges() {
        myActivity = null;
    }
}

class AssetsAudioPlayer(
        private val context: Context,
        private val messenger: BinaryMessenger,
        private val flutterAssets: FlutterPlugin.FlutterAssets
) : MethodCallHandler {

    private var stopWhenCall = StopWhenCallAudioFocus(context)
    private val notificationManager = NotificationManager(context)
    private var mediaButtonsReceiver: MediaButtonsReceiver? = null
    private val stopWhenCallListener = object : StopWhenCall.Listener {
        override fun onPhoneStateChanged(audioState: StopWhenCall.AudioState) {
            players.values.forEach {
                it.updateEnableToPlay(audioState)
            }
        }
    }

    private var lastPlayerIdWithNotificationEnabled: String? = null

    fun register() {
        stopWhenCall.register(stopWhenCallListener)

        mediaButtonsReceiver = MediaButtonsReceiver(context,
                onAction = {
                    onMediaButton(it)
                },
                onNotifSeek = { position ->
                    onNotifSeekPlayer(position)
                }
        )

        val channel = MethodChannel(messenger, "assets_audio_player")
        channel.setMethodCallHandler(this)

        //stopWhenCall?.requestAudioFocus()
    }

    fun unregister() {
        stopWhenCall?.stop()
        notificationManager.hideNotificationService(definitively = true)
        stopWhenCall?.unregister(stopWhenCallListener)
        players.values.forEach {
            it.stop()
        }
        players.clear()
    }

    private val players = mutableMapOf<String, Player>()

    fun getPlayer(id: String): Player? {
        return this.players[id]
    }

    private fun getOrCreatePlayer(id: String): Player {
        return players.getOrPut(id) {
            val channel = MethodChannel(messenger, "assets_audio_player/$id")
            val player = Player(
                    context = context,
                    id = id,
                    notificationManager = notificationManager,
                    stopWhenCall = stopWhenCall!!,
                    flutterAssets = flutterAssets
            )
            player.apply {
                onVolumeChanged = { volume ->
                    channel.invokeMethod(METHOD_VOLUME, volume)
                }
                onForwardRewind = { speed ->
                    channel.invokeMethod(METHOD_FORWARD_REWIND_SPEED, speed)
                }
                onPlaySpeedChanged = { speed ->
                    channel.invokeMethod(METHOD_PLAY_SPEED, speed)
                }
                onPositionChanged = { position ->
                    channel.invokeMethod(METHOD_POSITION, position)
                }
                onReadyToPlay = { totalDurationMs ->
                    channel.invokeMethod(METHOD_CURRENT, mapOf(
                            "totalDurationMs" to totalDurationMs)
                    )
                }
                onPlaying = {
                    channel.invokeMethod(METHOD_IS_PLAYING, it)
                }
                onBuffering = {
                    channel.invokeMethod(METHOD_IS_BUFFERING, it)
                }
                onFinished = {
                    channel.invokeMethod(METHOD_FINISHED, null)
                }

                onPrev = {
                    channel.invokeMethod(METHOD_PREV, null)
                }
                onNext = {
                    channel.invokeMethod(METHOD_NEXT, null)
                }
                onStop = {
                    channel.invokeMethod(METHOD_CURRENT, null)
                }
                onNotificationPlayOrPause = {
                    channel.invokeMethod(METHOD_PLAY_OR_PAUSE, null)
                }
                onNotificationStop = {
                    channel.invokeMethod(METHOD_NOTIFICATION_STOP, null)
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
                    getOrCreatePlayer(id).setVolume(volume)
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "playSpeed" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    val speed = args["playSpeed"] as? Double ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Double.", null)
                        return
                    }
                    getOrCreatePlayer(id).setPlaySpeed(speed)
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "showNotification" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    val show = args["show"] as? Boolean ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (show) must be an Boolean.", null)
                        return
                    }
                    getOrCreatePlayer(id).showNotification(show)
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "forwardRewind" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    val speed = args["speed"] as? Double ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Double.", null)
                        return
                    }
                    getOrCreatePlayer(id).forwardRewind(speed)
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
                    getOrCreatePlayer(id).seek(to * 1L)
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "loopSingleAudio" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    val loop = args["loop"] as? Boolean ?: run {
                        result.error("WRONG_FORMAT", "The specified argument(loop) must be an Boolean.", null)
                        return
                    }
                    getOrCreatePlayer(id).loopSingleAudio(loop)
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "onAudioUpdated" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument (id) must be an String.", null)
                        return
                    }
                    val path = args["path"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument(path) must be an String.", null)
                        return
                    }

                    val audioMetas = fetchAudioMetas(args)

                    getOrCreatePlayer(id).onAudioUpdated(path, audioMetas)
                    result.success(null)
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            "forceNotificationForGroup" -> {
                (call.arguments as? Map<*, *>)?.let { args ->
                    val id = args["id"] as? String
                    val isPlaying = args["isPlaying"] as? Boolean ?: run {
                        result.error("WRONG_FORMAT", "The specified argument(isPlaying) must be an Boolean.", null)
                        return
                    }
                    val display = args["display"] as? Boolean ?: run {
                        result.error("WRONG_FORMAT", "The specified argument(display) must be an Boolean.", null)
                        return
                    }

                    val audioMetas = fetchAudioMetas(args)
                    val notificationSettings = fetchNotificationSettings(args)
                    
                    if(!display){
                        notificationManager.stopNotification()
                    } else if(id != null) {
                        getOrCreatePlayer(id).forceNotificationForGroup(
                            audioMetas = audioMetas,
                            isPlaying = isPlaying,
                            display = display,
                            notificationSettings= notificationSettings
                        )
                    }
                   
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
                    val assetPackage = args["package"] as? String

                    val audioType = args["audioType"] as? String ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Map<String, Any> containing a `audioType`", null)
                        return
                    }
                    val volume = args["volume"] as? Double ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Map<String, Any> containing a `volume`", null)
                        return
                    }
                    val playSpeed = args["playSpeed"] as? Double ?: run {
                        result.error("WRONG_FORMAT", "The specified argument must be an Map<String, Any> containing a `playSpeed`", null)
                        return
                    }
                    val autoStart = args["autoStart"] as? Boolean ?: true
                    val displayNotification = args["displayNotification"] as? Boolean ?: false
                    val respectSilentMode = args["respectSilentMode"] as? Boolean ?: false
                    val seek = args["seek"] as? Int?
                    val networkHeaders = args["networkHeaders"] as? Map<*, *>?

                    val notificationSettings = fetchNotificationSettings(args)
                    val audioMetas = fetchAudioMetas(args)

                    getOrCreatePlayer(id).open(
                            assetAudioPath = path,
                            assetAudioPackage = assetPackage,
                            audioType = audioType,
                            autoStart = autoStart,
                            volume = volume,
                            seek = seek,
                            respectSilentMode = respectSilentMode,
                            displayNotification = displayNotification,
                            notificationSettings = notificationSettings,
                            result = result,
                            playSpeed = playSpeed,
                            audioMetas = audioMetas,
                            networkHeaders= networkHeaders,
                            context = context
                    )
                } ?: run {
                    result.error("WRONG_FORMAT", "The specified argument must be an Map<*, Any>.", null)
                    return
                }
            }
            else -> result.notImplemented()
        }
    }

    fun registerLastPlayerWithNotif(playerId: String) {
        this.lastPlayerIdWithNotificationEnabled = playerId
    }

    fun onMediaButton(action: MediaButtonsReceiver.MediaButtonAction) {
        lastPlayerIdWithNotificationEnabled
                ?.let {
                    getPlayer(it)
                }?.let { player ->
                    when (action) {
                        MediaButtonsReceiver.MediaButtonAction.play -> player.askPlayOrPause()
                        MediaButtonsReceiver.MediaButtonAction.pause -> player.askPlayOrPause()
                        MediaButtonsReceiver.MediaButtonAction.playOrPause -> player.askPlayOrPause()
                        MediaButtonsReceiver.MediaButtonAction.next -> player.next()
                        MediaButtonsReceiver.MediaButtonAction.prev -> player.prev()
                        MediaButtonsReceiver.MediaButtonAction.stop -> player.askStop()
                    }
                }
    }

    fun onNotifSeekPlayer(toMs: Long) {
        lastPlayerIdWithNotificationEnabled
                ?.let {
                    getPlayer(it)
                }?.let { player ->
                    player.seek(toMs)
                }
    }
}
