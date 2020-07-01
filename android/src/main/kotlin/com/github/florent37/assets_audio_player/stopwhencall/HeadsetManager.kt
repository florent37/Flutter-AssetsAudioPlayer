package com.github.florent37.assets_audio_player.stopwhencall

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter

private class MusicIntentReceiver : BroadcastReceiver() {
    var pluggedListener: ((Boolean) -> Unit)? = null
    override fun onReceive(context: Context, intent: Intent?) {
            if (intent?.action == Intent.ACTION_HEADSET_PLUG) {
                when (intent.getIntExtra("state", -1)) {
                    0 -> {
                        pluggedListener?.invoke(false)
                        //"Headset is unplugged"
                    }
                    1 -> {
                        pluggedListener?.invoke(true)
                        // "Headset is plugged"
                    }
                    else -> {
                        //"I have no idea what the headset state is"
                    }
                }
            }
    }
}

class HeadsetManager(private val context: Context) {

    var onHeadsetPluggedListener: ((Boolean) -> Unit)? = null
    private val receiver = MusicIntentReceiver().apply {
        this.pluggedListener = { plugged ->
            this@HeadsetManager.onHeadsetPluggedListener?.invoke(plugged)
        }
    }

    fun start(){
        val filter = IntentFilter(Intent.ACTION_HEADSET_PLUG)
        context.registerReceiver(receiver, filter)
    }

    fun stop(){
        context.unregisterReceiver(receiver)
    }

}