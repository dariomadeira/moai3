package com.infomak.moai.net

import javax.net.ssl.HostnameVerifier
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLSocketFactory

/**
 * Validación TLS original del sistema, guardada antes de que MainActivity
 * instale el modo permisivo global para streams (SPEC-50 §2.2).
 *
 * Se usa en descargas cuyo contenido se ejecuta (plugins `.dex`).
 */
object StrictTls {
    @Volatile
    private var captured = false
    lateinit var socketFactory: SSLSocketFactory
        private set
    lateinit var hostnameVerifier: HostnameVerifier
        private set

    /** Debe llamarse antes de cambiar los defaults; las llamadas siguientes no hacen nada. */
    @Synchronized
    fun captureSystemDefaults() {
        if (captured) return
        socketFactory = HttpsURLConnection.getDefaultSSLSocketFactory()
        hostnameVerifier = HttpsURLConnection.getDefaultHostnameVerifier()
        captured = true
    }

    fun apply(conn: HttpsURLConnection) {
        captureSystemDefaults()
        conn.sslSocketFactory = socketFactory
        conn.hostnameVerifier = hostnameVerifier
    }
}
