package com.github.florent37.assets_audio_player.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.support.v4.media.session.MediaSessionCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.media.session.MediaButtonReceiver
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import com.github.florent37.assets_audio_player.R
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

class NotificationService : Service() {

    companion object {
        const val NOTIFICATION_ID = 1
        const val CHANNEL_ID = "assets_audio_player"
        const val MEDIA_SESSION_TAG = "assets_audio_player"

        const val EXTRA_PLAYER_ID = "playerId"
        const val EXTRA_NOTIFICATION_ACTION = "notificationAction"
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        when (val notificationAction = intent.getSerializableExtra(EXTRA_NOTIFICATION_ACTION)) {
            is NotificationAction.Show -> {
                displayNotification(notificationAction)
            }
            is NotificationAction.Hide -> {
                stopForeground(false)
            }
        }
        return START_NOT_STICKY
    }

    private fun createReturnIntent(forAction: String, forPlayer: String): Intent {
        return Intent(this, NotificationActionReciever::class.java)
                .setAction(forAction)
                .putExtra(EXTRA_PLAYER_ID, forPlayer)
    }

    private fun displayNotification(action: NotificationAction.Show) {
        GlobalScope.launch(Dispatchers.Main) {
            if (action.audioMetas.imageType != null && action.audioMetas.image != null) {
                try {
                    val image = getBitmap(context = applicationContext, fileType = action.audioMetas.imageType, filePath = action.audioMetas.image)
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

    private fun displayNotification(action: NotificationAction.Show, bitmap: Bitmap?) {
        createNotificationChannel()
        val mediaSession = MediaSessionCompat(this, MEDIA_SESSION_TAG)

        val toggleIntent = createReturnIntent(forAction = NotificationAction.ACTION_TOGGLE, forPlayer = action.playerId)
                .putExtra(EXTRA_NOTIFICATION_ACTION, action.copyWith(
                        isPlaying = !action.isPlaying
                ))
        val pendingToggleIntent = PendingIntent.getBroadcast(this, 0, toggleIntent, PendingIntent.FLAG_UPDATE_CURRENT)
        MediaButtonReceiver.handleIntent(mediaSession, toggleIntent)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                //prev
                .addAction(R.drawable.exo_icon_previous, "prev",
                        PendingIntent.getBroadcast(this, 0, createReturnIntent(forAction = NotificationAction.ACTION_PREV, forPlayer = action.playerId), PendingIntent.FLAG_UPDATE_CURRENT)
                )
                //play/pause
                .addAction(
                        if (action.isPlaying) R.drawable.exo_icon_pause else R.drawable.exo_icon_play,
                        if (action.isPlaying) "pause" else "play",
                        pendingToggleIntent
                )
                //next
                .addAction(R.drawable.exo_icon_next, "next", PendingIntent.getBroadcast(this, 0,
                        createReturnIntent(forAction = NotificationAction.ACTION_NEXT, forPlayer = action.playerId), PendingIntent.FLAG_UPDATE_CURRENT)
                )
                //stop
                .addAction(R.drawable.exo_icon_stop, "stop", PendingIntent.getBroadcast(this, 0,
                        createReturnIntent(forAction = NotificationAction.ACTION_STOP, forPlayer = action.playerId), PendingIntent.FLAG_UPDATE_CURRENT)
                )
                .setStyle(androidx.media.app.NotificationCompat.MediaStyle()
                        .setShowActionsInCompactView(0, 1, 2)
                        .setShowCancelButton(true)
                        .setMediaSession(mediaSession.sessionToken)
                )
                .setSmallIcon(R.drawable.exo_icon_circular_play)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setVibrate(longArrayOf(0L))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setContentTitle(action.audioMetas.title)
                .setContentText(action.audioMetas.artist)
                .setSubText(action.audioMetas.title)
                .setContentIntent(PendingIntent.getBroadcast(this, 0, createReturnIntent(forAction = NotificationAction.ACTION_SELECT, forPlayer = action.playerId), PendingIntent.FLAG_CANCEL_CURRENT))
                .also {
                    if(bitmap != null){
                        it.setLargeIcon(bitmap)
                    }
                }
                .build()
        startForeground(NOTIFICATION_ID, notification)

        if (!action.isPlaying) {
            stopForeground(false)
        }
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

    suspend fun getBitmap(context: Context, fileType: String, filePath: String): Bitmap = withContext(Dispatchers.IO) {
        suspendCoroutine<Bitmap> { continuation ->
            try {
                when (fileType) {
                    "asset" -> {
                        Glide.with(applicationContext)
                                .asBitmap()
                                .timeout(5000)
                                .load(Uri.parse("file:///android_asset/flutter_assets/$filePath"))
                                .into(object : CustomTarget<Bitmap>() {
                                    override fun onLoadFailed(errorDrawable: Drawable?) {
                                        continuation.resumeWithException(Exception("failed to download $filePath"))
                                    }

                                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                                        continuation.resume(resource)
                                    }

                                    override fun onLoadCleared(placeholder: Drawable?) {

                                    }
                                })

                        //val istr = context.assets.open("flutter_assets/$filePath")
                        //val bitmap = BitmapFactory.decodeStream(istr)
                        //continuation.resume(bitmap)
                    }
                    "network" -> {
                        Glide.with(applicationContext)
                                .asBitmap()
                                .timeout(5000)
                                .load(filePath)
                                .into(object : CustomTarget<Bitmap>() {
                                    override fun onLoadFailed(errorDrawable: Drawable?) {
                                        continuation.resumeWithException(Exception("failed to download $filePath"))
                                    }

                                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                                        continuation.resume(resource)
                                    }

                                    override fun onLoadCleared(placeholder: Drawable?) {

                                    }
                                })
                    }
                    else -> {
                        //val options = BitmapFactory.Options().apply {
                        //    inPreferredConfig = Bitmap.Config.ARGB_8888
                        //}
                        //val bitmap = BitmapFactory.decodeFile(filePath, options)
                        //continuation.resume(bitmap)

                        Glide.with(applicationContext)
                                .asBitmap()
                                .timeout(5000)
                                .load(File(filePath).path)
                                .into(object : CustomTarget<Bitmap>() {
                                    override fun onLoadFailed(errorDrawable: Drawable?) {
                                        continuation.resumeWithException(Exception("failed to download $filePath"))
                                    }

                                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                                        continuation.resume(resource)
                                    }

                                    override fun onLoadCleared(placeholder: Drawable?) {

                                    }
                                })
                    }
                }
            } catch (t: Throwable) {
                // handle exception
                t.printStackTrace()
                continuation.resumeWithException(t)
            }
        }
    }

    override fun onTaskRemoved(rootIntent: Intent) {
        stopForeground(true)
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