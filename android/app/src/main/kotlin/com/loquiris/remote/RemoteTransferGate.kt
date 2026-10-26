package com.loquiris.remote

/** Foreground database preparation preempts transfers instead of waiting on the network. */
class RemoteTransferGate {
    @Volatile var paused=false
        private set
    private val requests=mutableMapOf<Any, ()->Unit>()
    @Synchronized fun register(abort: ()->Unit): AutoCloseable {
        val key=Any()
        if(paused) abort() else requests[key]=abort
        return AutoCloseable { synchronized(this) {requests.remove(key)} }
    }
    fun pause() {
        val aborts=synchronized(this) {paused=true;requests.values.toList()}
        aborts.forEach {runCatching(it)}
    }
    @Synchronized fun resume() {paused=false}
}
