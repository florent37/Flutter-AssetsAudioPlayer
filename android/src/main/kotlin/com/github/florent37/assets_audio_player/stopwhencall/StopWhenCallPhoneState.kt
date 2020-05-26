import android.content.Context
import android.telephony.TelephonyManager

class StopWhenCallPhoneState(private val context: Context) : StopWhenCall() {

    private val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

    companion object {
        var INSTANCE: StopWhenCallPhoneState? = null
    }

    init {
        INSTANCE = this
    }

    fun onChanged(audioState: String) {
        when (audioState) {
            TelephonyManager.EXTRA_STATE_IDLE -> {
                pingListeners(StopWhenCall.AudioState.AUTHORIZED_TO_PLAY)
            }
            TelephonyManager.EXTRA_STATE_RINGING -> {
                pingListeners(StopWhenCall.AudioState.REDUCE_VOLUME)
            }
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                pingListeners(StopWhenCall.AudioState.FORBIDDEN)
            }
        }
    }

    override fun requestAudioFocus() {
        onChanged(telephonyManager.callState.toString())
    }

    override fun stop() {

    }
}