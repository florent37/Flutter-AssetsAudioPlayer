package com.github.florent37.assets_audio_player.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.support.v4.media.session.PlaybackStateCompat.ACTION_PLAY_PAUSE
import android.support.v4.media.session.PlaybackStateCompat.ACTION_SEEK_TO
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.media.session.MediaButtonReceiver
import com.github.florent37.assets_audio_player.R
import com.google.android.exoplayer2.C
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch

class NotificationService : Service() {

    companion object {
        const val NOTIFICATION_ID = 1
        const val CHANNEL_ID = "assets_audio_player"
        const val MEDIA_SESSION_TAG = "assets_audio_player"

        const val EXTRA_PLAYER_ID = "playerId"
        const val EXTRA_NOTIFICATION_ACTION = "notificationAction"
        const val TRACK_ID = "trackID";

        const val manifestIcon = "assets.audio.player.notification.icon"
        const val manifestIconPlay = "assets.audio.player.notification.icon.play"
        const val manifestIconPause = "assets.audio.player.notification.icon.pause"
        const val manifestIconPrev = "assets.audio.player.notification.icon.prev"
        const val manifestIconNext = "assets.audio.player.notification.icon.next"
        const val manifestIconStop = "assets.audio.player.notification.icon.stop"

        fun updatePosition(context: Context, isPlaying: Boolean, currentPositionMs: Long, speed: Float){
            MediaButtonsReceiver.getMediaSessionCompat(context).let { mediaSession ->
                val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED;
                mediaSession.setPlaybackState(PlaybackStateCompat.Builder ()
                        .setActions(ACTION_SEEK_TO)
                        .setState(state, currentPositionMs, if(isPlaying) speed else 0f)
                        .build());
            }
        }
        
        fun displaySeekBar(context: Context, display: Boolean, durationMs: Long){
            val mediaSession = MediaButtonsReceiver.getMediaSessionCompat(context)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                if (!display || durationMs == 0L /* livestream */) {
                    mediaSession.setMetadata(MediaMetadataCompat.Builder()
                            .putLong(MediaMetadata.METADATA_KEY_DURATION, C.TIME_UNSET)
                            .build())
                } else {
                    mediaSession.setMetadata(MediaMetadataCompat.Builder()
                            .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)
                            .build())
                }
            }
        }
    }
    
    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        if(intent.action == Intent.ACTION_MEDIA_BUTTON){
            MediaButtonsReceiver.getMediaSessionCompat(applicationContext).let {
                MediaButtonReceiver.handleIntent(it, intent)
            }
        }
        when (val notificationAction = intent.getSerializableExtra(EXTRA_NOTIFICATION_ACTION)) {
            is NotificationAction.Show -> {
                displayNotification(notificationAction)
            }
            is NotificationAction.Hide -> {
                hideNotif()
            }
        }
        return START_NOT_STICKY
    }

    private fun createReturnIntent(forAction: String, forPlayer: String,audioMetas: AudioMetas): Intent {
        return Intent(this, NotificationActionReceiver::class.java)
                .setAction(forAction)
                .putExtra(EXTRA_PLAYER_ID, forPlayer)
                .putExtra(TRACK_ID,audioMetas.trackID)
    }
    
    private fun displayNotification(action: NotificationAction.Show) {
        GlobalScope.launch(Dispatchers.Main) {
            if (action.audioMetas.imageType != null && action.audioMetas.image != null) {
                try {
                    val image = ImageDownloader.getBitmap(context = applicationContext, fileType = action.audioMetas.imageType, filePath = action.audioMetas.image, filePackage = action.audioMetas.imagePackage)
                    displayNotification(action, image) //display without image for now
                } catch (t: Throwable) {
                    t.printStackTrace()
                    displayNotification(action, null) //display without image
                }
            } else {
                displayNotification(action, null) //display without image
            }
        }
    }

    private fun getSmallIcon(context: Context) : Int {
        return getCustomIconOrDefault(context, manifestIcon,"", R.drawable.exo_icon_circular_play)
    }

    private fun getPlayIcon(context: Context,settingName: String) : Int {
        return getCustomIconOrDefault(context, manifestIconPlay,settingName, R.drawable.exo_icon_play)
    }

    private fun getPauseIcon(context: Context,settingName: String) : Int {
        return getCustomIconOrDefault(context, manifestIconPause,settingName, R.drawable.exo_icon_pause)
    }

    private fun getNextIcon(context: Context,settingName: String) : Int {
        return getCustomIconOrDefault(context, manifestIconNext,settingName, R.drawable.exo_icon_next)
    }

    private fun getPrevIcon(context: Context,settingName: String) : Int {
        return getCustomIconOrDefault(context, manifestIconPrev,settingName, R.drawable.exo_icon_previous)
    }

    private fun getStopIcon(context: Context,settingName: String) : Int {
        return getCustomIconOrDefault(context, manifestIconStop,settingName, R.drawable.exo_icon_stop)
    }

    private fun getCustomIconOrDefault(context: Context, manifestName: String, settingName: String ,defaultIcon: Int) : Int {
        try {
            val icon: Int = getResourceID(settingName)
            if(icon != 0) return icon;
            val appInfos = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)
            val customIcon = appInfos.metaData.get(manifestName) as? Int
            return customIcon ?: defaultIcon
        } catch (t : Throwable) {
            return defaultIcon
        }
    }

    private fun getResourceID(iconName : String) : Int{
        if(iconName == null) return 0
        val id : Int = resources.getIdentifier(iconName,"drawable",applicationContext.packageName)
        return id
    }

    private fun displayNotification(action: NotificationAction.Show, bitmap: Bitmap?) {
        createNotificationChannel()
        val mediaSession = MediaButtonsReceiver.getMediaSessionCompat(applicationContext)

        val notificationSettings = action.notificationSettings

        displaySeekBar(
                context = applicationContext, 
                display = notificationSettings.seekBarEnabled, 
                durationMs = action.durationMs
        )

        val toggleIntent = createReturnIntent(forAction = NotificationAction.ACTION_TOGGLE, forPlayer = action.playerId,audioMetas = action.audioMetas)
                .putExtra(EXTRA_NOTIFICATION_ACTION, action.copyWith(
                        isPlaying = !action.isPlaying
                ))
        val pendingToggleIntent = PendingIntent.getBroadcast(this, 0, toggleIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        MediaButtonReceiver.handleIntent(mediaSession, toggleIntent)

        val context = this

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                //prev
                .apply {
                    if(notificationSettings.prevEnabled) {
                        addAction(getPrevIcon(context,action.notificationSettings.previousIcon?:""), "prev",
                                PendingIntent.getBroadcast(context, 0, createReturnIntent(forAction = NotificationAction.ACTION_PREV, forPlayer = action.playerId,audioMetas = action.audioMetas), PendingIntent.FLAG_UPDATE_CURRENT)
                        )
                    }
                }
                //play/pause
                .apply {
                    if(notificationSettings.playPauseEnabled) {
                        addAction(
                                if (action.isPlaying) getPauseIcon(context,action.notificationSettings.pauseIcon?:"") else getPlayIcon(context,action.notificationSettings.playIcon?: ""),
                                if (action.isPlaying) "pause" else "play",
                                pendingToggleIntent
                        )
                    }
                }
                //next
                .apply {
                    if(notificationSettings.nextEnabled) {
                        addAction(getNextIcon(context,action.notificationSettings.nextIcon?:""), "next", PendingIntent.getBroadcast(context, 0,
                                createReturnIntent(forAction = NotificationAction.ACTION_NEXT, forPlayer = action.playerId,audioMetas = action.audioMetas), PendingIntent.FLAG_UPDATE_CURRENT)
                        )
                    }
                }
                //stop
                .apply {
                    if(notificationSettings.stopEnabled){
                        addAction(getStopIcon(context,action.notificationSettings.stopIcon?:""), "stop", PendingIntent.getBroadcast(context, 0,
                                createReturnIntent(forAction = NotificationAction.ACTION_STOP, forPlayer = action.playerId,audioMetas = action.audioMetas), PendingIntent.FLAG_UPDATE_CURRENT)
                        )
                    }
                }
                .setStyle(androidx.media.app.NotificationCompat.MediaStyle()
                        .also {
                            when(notificationSettings.numberEnabled()){
                                1 ->  it.setShowActionsInCompactView(0)
                                2 ->  it.setShowActionsInCompactView(0, 1)
                                3 ->  it.setShowActionsInCompactView(0, 1, 2)
                                else -> it.setShowActionsInCompactView()
                            }
                        }
                        .setShowCancelButton(true)
                        .setMediaSession(mediaSession.sessionToken)
                )
                .setSmallIcon(getSmallIcon(context))
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setVibrate(longArrayOf(0L))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setContentTitle(action.audioMetas.title)
                .setContentText(action.audioMetas.artist)
                .also {
                    if(!action.audioMetas.album.isNullOrEmpty()) {
                        it.setSubText(action.audioMetas.album)
                    }
                }
                .setContentIntent(PendingIntent.getBroadcast(this, 0,
                        createReturnIntent(forAction = NotificationAction.ACTION_SELECT, forPlayer = action.playerId,audioMetas = action.audioMetas), PendingIntent.FLAG_CANCEL_CURRENT))
                .also {
                    if(bitmap != null){
                        it.setLargeIcon(bitmap)
                    }
                }
                .setShowWhen(false)
                .build()
        startForeground(NOTIFICATION_ID, notification)

        //fix for https://github.com/florent37/Flutter-AssetsAudioPlayer/issues/139
        //if (!action.isPlaying) {
        //    stopForeground(false)
        //}
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                    CHANNEL_ID,
                    "Foreground Service Channel",
                    android.app.NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "assets_audio_player"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            NotificationManagerCompat.from(applicationContext).createNotificationChannel(
                    serviceChannel
            )
        }
    }

    private fun hideNotif(){
        NotificationManagerCompat.from(applicationContext).cancel(NOTIFICATION_ID)
        stopForeground(true)
        stopSelf()
    }
    
    override fun onTaskRemoved(rootIntent: Intent) {
        hideNotif()
    }

    override fun onCreate() {
        super.onCreate()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
    }

}