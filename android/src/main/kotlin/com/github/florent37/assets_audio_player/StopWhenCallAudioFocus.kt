import android.content.Context
import android.media.AudioManager
import androidx.media.AudioAttributesCompat
import androidx.media.AudioFocusRequestCompat
import androidx.media.AudioManagerCompat

class StopWhenCallAudioFocus(private val context: Context) : StopWhenCall() {

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val focusLock = Any()

    private var request: AudioFocusRequestCompat? = null
    private val listener: ((Int) -> Unit) = { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN ->
                synchronized(focusLock) {
                    pingListeners(AudioState.AUTHORIZED_TO_PLAY)
                }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ->
                synchronized(focusLock) {
                    pingListeners(AudioState.REDUCE_VOLUME)
                }
            else -> {
                synchronized(focusLock) {
                    pingListeners(AudioState.FORBIDDEN)
                }
            }
        }
    }

    override fun requestAudioFocus() {
        this.request = AudioFocusRequestCompat.Builder(AudioManagerCompat.AUDIOFOCUS_GAIN).also {
            it.setAudioAttributes(AudioAttributesCompat.Builder().run {
                setUsage(AudioAttributesCompat.USAGE_MEDIA)
                setContentType(AudioAttributesCompat.CONTENT_TYPE_MUSIC)
                build()
            })
            it.setOnAudioFocusChangeListener(listener)
        }.build()
        val result: Int = AudioManagerCompat.requestAudioFocus(audioManager, request!!)
        synchronized(focusLock) {
            listener(result)
        }
    }

    override fun stop() {
        this.request?.let {
            AudioManagerCompat.abandonAudioFocusRequest(audioManager, it)
        }
    }
}