abstract class StopWhenCall {

    interface Listener {
        fun onPhoneStateChanged(enabledToPlay: Boolean)
    }

    private val listeners = mutableSetOf<Listener>()

    fun register(listener: Listener) {
        listeners.add(listener)
    }

    fun unregister(listener: Listener) {
        listeners.remove(listener)
    }

    protected fun pingListeners(enabledToPlay: Boolean) {
        listeners.forEach {
            it.onPhoneStateChanged(enabledToPlay)
        }
    }

    abstract fun start()
    abstract fun stop()
}

