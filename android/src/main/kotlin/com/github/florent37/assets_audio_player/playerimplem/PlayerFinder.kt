package com.github.florent37.assets_audio_player.playerimplem

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin

interface PlayerImplemTester {
    @Throws(Exception::class)
    suspend fun open(configuration: PlayerFinderConfiguration): PlayerFinder.PlayerWithDuration
}

class PlayerFinderConfiguration(
        val assetAudioPath: String?,
        val flutterAssets: FlutterPlugin.FlutterAssets,
        val assetAudioPackage: String?,
        val audioType: String,
        val networkHeaders: Map<*, *>?,
        val context: Context,
        val onFinished: (() -> Unit)?,
        val onPlaying: ((Boolean) -> Unit)?,
        val onBuffering: ((Boolean) -> Unit)?
)

object PlayerFinder {

    class PlayerWithDuration(val player: PlayerImplem, val duration: DurationMS)
    class NoPlayerFoundException() : Throwable()

    private val playerImpls = listOf<PlayerImplemTester>(
            PlayerImplemTesterExoPlayer(PlayerImplemTesterExoPlayer.Type.Default),
            PlayerImplemTesterExoPlayer(PlayerImplemTesterExoPlayer.Type.HLS),
            PlayerImplemTesterExoPlayer(PlayerImplemTesterExoPlayer.Type.DASH),
            PlayerImplemTesterExoPlayer(PlayerImplemTesterExoPlayer.Type.SmoothStreaming),
            PlayerImplemTesterMediaPlayer()
    )

    @Throws(NoPlayerFoundException::class)
    private suspend fun _findWorkingPlayer(
            remainingImpls: List<PlayerImplemTester>,
            configuration: PlayerFinderConfiguration
    ): PlayerWithDuration {
        if (remainingImpls.isEmpty()) {
            throw NoPlayerFoundException()
        }
        try {
            //try the first
            val implemTester = remainingImpls.first()
            val playerWithDuration = implemTester.open(
                    configuration= configuration
            )
            //if we're here : no exception, we can return it
            return playerWithDuration
        } catch (t: Throwable) {
            //else, remove it from list and test the next
            val implsToTest = remainingImpls.toMutableList().apply {
                removeAt(0)
            }
            return _findWorkingPlayer(
                    remainingImpls = implsToTest,
                    configuration= configuration
            )
        }
    }

    @Throws(NoPlayerFoundException::class)
    suspend fun findWorkingPlayer(configuration: PlayerFinderConfiguration): PlayerWithDuration {
        return _findWorkingPlayer(
                remainingImpls= playerImpls,
                configuration= configuration
        )
    }
}