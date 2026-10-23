package com.infomak.moai

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import androidx.core.content.FileProvider
import id.laskarmedia.openvpn_flutter.OpenVPNFlutterPlugin
import java.io.File
import java.net.NetworkInterface
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import android.util.Log
import com.infomak.moai.plugin.PluginLoader
import com.infomak.moai.voice.RemoteVoiceManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.infomak.moai.net.StrictTls

/** App Moai. */
class MainActivity : FlutterActivity() {

    companion object {
        init {
            configurePermissiveSsl()
        }

        @JvmStatic
        fun configurePermissiveSsl() {
            // Guardar la validación del sistema antes de pisarla (descargas de código).
            StrictTls.captureSystemDefaults()
            try {
                val trustAllCerts = arrayOf<TrustManager>(
                    object : X509TrustManager {
                        override fun checkClientTrusted(
                            chain: Array<out X509Certificate>?,
                            authType: String?
                        ) {}

                        override fun checkServerTrusted(
                            chain: Array<out X509Certificate>?,
                            authType: String?
                        ) {}

                        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                    }
                )

                val sslContext = SSLContext.getInstance("TLS")
                sslContext.init(null, trustAllCerts, SecureRandom())
                HttpsURLConnection.setDefaultSSLSocketFactory(sslContext.socketFactory)
                HttpsURLConnection.setDefaultHostnameVerifier { _, _ -> true }
                SSLContext.setDefault(sslContext)
                Log.i("MainActivity", "SSL permisivo global configurado en Android native")
            } catch (e: Exception) {
                Log.e("MainActivity", "Error configurando SSL permisivo: ${e.message}", e)
            }
        }
    }

    private val engine = PlayerEngine()
    private lateinit var pluginLoader: PluginLoader
    private var voiceManager: RemoteVoiceManager? = null
    private var uiDpadSounds: UiDpadSounds? = null

    private var arcadeManager: com.infomak.moai.games.ArcadeEmulatorManager? = null
    private var titanRangerManager: com.infomak.moai.titan.TitanRangerManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterActivityHolder.current = this
        pluginLoader = PluginLoader(this)
        voiceManager = RemoteVoiceManager(this)
        uiDpadSounds = UiDpadSounds(this).also { it.init() }
        arcadeManager = com.infomak.moai.games.ArcadeEmulatorManager(this, flutterEngine.dartExecutor.binaryMessenger)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.infomak.moai/arcade_view",
            com.infomak.moai.games.ArcadePlatformViewFactory(arcadeManager!!)
        )
        titanRangerManager = com.infomak.moai.titan.TitanRangerManager(this).also {
            it.registerChannel(flutterEngine.dartExecutor.binaryMessenger)
        }
        setupDeviceChannel(flutterEngine)
        setupVoiceTestChannel(flutterEngine)
        engine.attach(flutterEngine)
        pluginLoader.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        if (::pluginLoader.isInitialized) {
            pluginLoader.shutdown()
        }
        engine.disposeAll()
        voiceManager?.release()
        voiceManager = null
        uiDpadSounds?.release()
        uiDpadSounds = null
        FlutterActivityHolder.current = null
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // openvpn_flutter: requestCode 24 = VpnService.prepare.
        // connectWhileGranted llama startVPN con la config estática del plugin.
        // Si solo se pidió permiso (config vacía), startVPN crashea / tumba la app.
        if (requestCode == 24) {
            if (resultCode == RESULT_OK) {
                try {
                    val configField =
                        OpenVPNFlutterPlugin::class.java.getDeclaredField("config")
                    configField.isAccessible = true
                    val cfg = configField.get(null) as? String
                    if (!cfg.isNullOrBlank()) {
                        OpenVPNFlutterPlugin.connectWhileGranted(true)
                    } else {
                        Log.i(
                            "MainActivity",
                            "VPN permiso OK; connect diferido a Flutter (sin config pendiente)",
                        )
                    }
                } catch (e: Exception) {
                    Log.e("MainActivity", "VPN onActivityResult: ${e.message}", e)
                }
            } else {
                Log.w("MainActivity", "VPN permiso denegado por el usuario")
                val engine = flutterEngine
                if (engine != null) {
                    try {
                        MethodChannel(
                            engine.dartExecutor.binaryMessenger,
                            "com.infomak.moai.tv/vpn_permission",
                        ).invokeMethod("denied", null)
                    } catch (e: Exception) {
                        Log.w("MainActivity", "No se pudo notificar deny VPN: ${e.message}")
                    }
                }
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun dispatchKeyEvent(event: android.view.KeyEvent): Boolean {
        if (arcadeManager?.isRunningEmulation == true) {
            if (arcadeManager?.handleKeyEvent(event) == true) {
                return true
            }
            // Emulación activa: no sonidos de UI.
            return super.dispatchKeyEvent(event)
        }
        // UI TV: click D-pad (gamepad filtrado dentro de UiDpadSounds).
        uiDpadSounds?.onKey(event)
        return super.dispatchKeyEvent(event)
    }

    override fun dispatchGenericMotionEvent(event: android.view.MotionEvent): Boolean {
        if (arcadeManager?.isRunningEmulation == true) {
            if (arcadeManager?.handleGenericMotionEvent(event) == true) {
                return true
            }
        }
        return super.dispatchGenericMotionEvent(event)
    }

    /** Canal de utilidades del dispositivo (rama anterior de moai). */
    private fun setupDeviceChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.infomak.moai.tv/device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTotalRamMb" -> {
                    val activityManager =
                        getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val memoryInfo = ActivityManager.MemoryInfo()
                    activityManager.getMemoryInfo(memoryInfo)
                    val totalRamMb = (memoryInfo.totalMem / (1024 * 1024)).toInt()
                    result.success(totalRamMb)
                }
                "getHardwareDeviceId" -> {
                    try {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        result.success(androidId ?: "")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error getting ANDROID_ID: ${e.message}", e)
                        result.success("")
                    }
                }
                "getDeviceFingerprint" -> {
                    val map = HashMap<String, String>()
                    map["androidId"] = try {
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: ""
                    } catch (e: Exception) {
                        ""
                    }
                    fun macOf(ifaceName: String): String {
                        return try {
                            val networkInterfaces = NetworkInterface.getNetworkInterfaces()
                            var iface: NetworkInterface? = null
                            while (networkInterfaces.hasMoreElements()) {
                                val candidate = networkInterfaces.nextElement()
                                if (candidate.name.equals(ifaceName, true)) {
                                    iface = candidate
                                    break
                                }
                            }
                            val addr = iface?.hardwareAddress
                            if (addr == null || addr.isEmpty()) {
                                "02:00:00:00:00:00"
                            } else {
                                addr.joinToString(":") { byte -> String.format("%02X", byte) }
                            }
                        } catch (e: Exception) {
                            "02:00:00:00:00:00"
                        }
                    }
                    map["wifiMac"] = macOf("wlan0")
                    map["etheMac"] = macOf("eth0")
                    map["serialNumber"] = try { Build.SERIAL ?: "unknown" } catch (e: Exception) { "unknown" }
                    map["diskInfo"] = ""
                    map["ramSize"] = try {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val mi = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(mi)
                        (mi.totalMem / (1024L * 1024L)).toString() + "MB"
                    } catch (e: Exception) {
                        ""
                    }
                    map["romSize"] = try {
                        val s = StatFs(Environment.getDataDirectory().path)
                        ((s.blockSizeLong * s.blockCountLong) / (1024L * 1024L)).toString() + "MB"
                    } catch (e: Exception) {
                        ""
                    }
                    map["gatewayMac"] = "02:00:00:00:00:00"
                    map["cpuId"] = Build.HARDWARE ?: "unknown"
                    map["display"] = Build.DISPLAY ?: "unknown"
                    map["brand"] = Build.BRAND ?: "unknown"
                    map["verId"] = Build.ID ?: "unknown"
                    map["cpuAbi"] = Build.CPU_ABI ?: "unknown"
                    map["hardware"] = Build.HARDWARE ?: "unknown"
                    map["manufacturer"] = Build.MANUFACTURER ?: "unknown"
                    map["fingerprint"] = Build.FINGERPRINT ?: "unknown"
                    map["host"] = Build.HOST ?: "unknown"
                    map["device"] = Build.DEVICE ?: "unknown"
                    map["board"] = Build.BOARD ?: "unknown"
                    map["tags"] = Build.TAGS ?: "unknown"
                    result.success(map)
                }
                "finishApp" -> {
                    finishAndRemoveTask()
                    result.success(null)
                }
                "setUiDpadSoundsEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    uiDpadSounds?.setEnabled(enabled)
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "Path is null or empty", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
                            return@setMethodCallHandler
                        }
                        val contentUri = FileProvider.getUriForFile(
                            this,
                            "${packageName}.fileProvider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(contentUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error installing APK: ${e.message}", e)
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Canal para la prueba empírica de captura de audio del control remoto TV. */
    private fun setupVoiceTestChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.infomak.moai.tv/remote_voice"
        )
        channel.setMethodCallHandler { call, result ->
            val vm = voiceManager ?: run {
                result.error("NOT_INITIALIZED", "Voice manager no inicializado", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "checkHardware" -> {
                    result.success(vm.checkHardware())
                }
                "hasPermission" -> {
                    result.success(vm.hasPermission())
                }
                "requestPermission" -> {
                    vm.requestPermission()
                    result.success(true)
                }
                "startRecording" -> {
                    result.success(vm.startRecording())
                }
                "stopRecording" -> {
                    result.success(vm.stopRecording())
                }
                "playRecording" -> {
                    val res = vm.playRecording {
                        runOnUiThread {
                            channel.invokeMethod("onPlaybackComplete", null)
                        }
                    }
                    result.success(res)
                }
                "playAudio" -> {
                    val source = call.argument<String>("source") ?: run {
                        result.error("INVALID_ARG", "Parametro 'source' requerido", null)
                        return@setMethodCallHandler
                    }
                    val res = vm.playAudio(source) {
                        runOnUiThread {
                            channel.invokeMethod("onPlaybackComplete", null)
                        }
                    }
                    result.success(res)
                }
                "stopPlayback" -> {
                    vm.stopPlayback()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}

/** Puente simple para obtener el contexto de la Activity actual. */
object FlutterActivityHolder {
    var current: Context? = null
}
