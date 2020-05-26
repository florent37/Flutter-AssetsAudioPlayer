package com.github.florent37.assets_audio_player.stopwhencall

import StopWhenCallPhoneState
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

class PhoneStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        StopWhenCallPhoneState.INSTANCE?.let { stopWhenCall ->

            if (intent.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
                val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
                stopWhenCall.onChanged(state)
            }
        }
    }
}