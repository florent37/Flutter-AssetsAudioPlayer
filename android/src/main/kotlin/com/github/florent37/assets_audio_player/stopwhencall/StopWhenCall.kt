abstract class StopWhenCall {

    enum class AudioState {
        AUTHORIZED_TO_PLAY,
        REDUCE_VOLUME,
        FORBIDDEN
    }

    interface Listener {
        fun onPhoneStateChanged(audioState: AudioState)
    }

    private val listeners = mutableSetOf<Listener>()

    fun register(listener: Listener) {
        listeners.add(listener)
    }

    fun unregister(listener: Listener) {
        listeners.remove(listener)
    }

    protected fun pingListeners(audioState: AudioState) {
        listeners.forEach {
            it.onPhoneStateChanged(audioState= audioState)
        }
    }

    abstract fun requestAudioFocus()
    abstract fun stop()
}

