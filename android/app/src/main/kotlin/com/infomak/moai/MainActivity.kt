package com.infomak.moai

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import java.io.File
import android.util.Log
import android.view.Surface
import android.view.WindowManager
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.DefaultDrmSessionManagerProvider
import androidx.media3.exoplayer.drm.DrmSessionManagerProvider
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.LocalMediaDrmCallback
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.upstream.DefaultBandwidthMeter
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.exoplayer.upstream.LoadErrorHandlingPolicy
import com.infomak.moai.plugin.PluginLoader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

/** App Moai. */
class MainActivity : FlutterActivity() {

    private val engine = PlayerEngine()
    private lateinit var pluginLoader: PluginLoader

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterActivityHolder.current = this
        pluginLoader = PluginLoader(this)
        setupDeviceChannel(flutterEngine)
        engine.attach(flutterEngine)
        pluginLoader.attach(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onDestroy() {
        if (::pluginLoader.isInitialized) {
            pluginLoader.shutdown()
        }
        engine.disposeAll()
        FlutterActivityHolder.current = null
        super.onDestroy()
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
                "isEmulator" -> {
                    val isEmu = (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")
                            || Build.FINGERPRINT.startsWith("generic")
                            || Build.FINGERPRINT.startsWith("unknown")
                            || Build.MODEL.contains("google_sdk")
                            || Build.MODEL.contains("Emulator")
                            || Build.MODEL.contains("Android SDK built for x86")
                            || Build.BOARD.contains("QC_Reference_Phone")
                            || Build.MANUFACTURER.contains("Genymotion")
                            || Build.HOST.startsWith("Build")
                            || Build.HARDWARE.contains("goldfish")
                            || Build.HARDWARE.contains("ranchu")
                            || Build.PRODUCT.contains("sdk_gphone")
                            || Build.PRODUCT.contains("emulator")
                            || Build.PRODUCT.contains("google_sdk")
                            || Build.PRODUCT.contains("sdk")
                            || Build.PRODUCT.contains("sdk_x86")
                            || Build.PRODUCT.contains("vbox86p"))
                    result.success(isEmu)
                }
                "finishApp" -> {
                    finishAndRemoveTask()
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
}

/**
 * Motor único de reproducción (ExoPlayer nativo) renderizando a un
 * `SurfaceTexture` de Flutter (widget `Texture`). Sin PlatformView.
 */
@UnstableApi
class PlayerEngine {
    companion object {
        const val TAG = "MoaiEngine"
    }

    private var flutterEngine: FlutterEngine? = null
    private var controlChannel: MethodChannel? = null
    private val entries = mutableMapOf<Int, PlayerEntry>()
    private var nextId = 0

    fun attach(flutterEngine: FlutterEngine) {
        this.flutterEngine = flutterEngine
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.infomak.moai.tv/player"
        )
        channel.setMethodCallHandler { call, result -> handle(call, result) }
        controlChannel = channel
    }

    @Suppress("UNCHECKED_CAST")
    private fun handle(call: MethodCall, result: Result) {
        val handle = (call.argument<Number>("handle"))?.toInt()
        try {
            when (call.method) {
                "create" -> {
                    val fe = flutterEngine
                        ?: return result.error("no_engine", "Sin FlutterEngine", null)
                    val textureEntry = fe.renderer.createSurfaceTexture()
                    // Tamaño por defecto para evitar textura negra/1x1 en
                    // dispositivos que no reportan videoSize de inmediato.
                    // (El evento videoSize lo reajusta después.)
                    textureEntry.surfaceTexture().setDefaultBufferSize(1280, 720)
                    val entry = PlayerEntry(nextId++, textureEntry)
                    entries[entry.id] = entry
                    entry.setupEvents(fe.dartExecutor.binaryMessenger)
                    Log.i(TAG, "create -> handle=${entry.id} texture=${entry.textureId}")
                    result.success(
                        mapOf(
                            "handle" to entry.id,
                            "textureId" to entry.textureId,
                        )
                    )
                }

                "setMedia" -> {
                    val entry = entries[handle]
                        ?: return result.error("no_player", "handle inexistente", null)
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
                    Log.i(TAG, "setMedia handle=$handle args=${args.keys}")
                    entry.buildAndPlay(args)
                    result.success(null)
                }

                "play" -> {
                    Log.d(TAG, "play handle=$handle")
                    entries[handle]?.player?.play()
                    result.success(null)
                }
                "pause" -> {
                    Log.d(TAG, "pause handle=$handle")
                    entries[handle]?.player?.pause()
                    result.success(null)
                }
                "seekTo" -> {
                    val pos = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                    Log.d(TAG, "seekTo handle=$handle pos=$pos")
                    entries[handle]?.player?.seekTo(pos)
                    result.success(null)
                }
                "setVolume" -> {
                    val vol = (call.argument<Number>("volume"))?.toFloat() ?: 1f
                    Log.d(TAG, "setVolume handle=$handle vol=$vol")
                    entries[handle]?.player?.volume = vol
                    result.success(null)
                }
                "getPosition" -> result.success(entries[handle]?.player?.currentPosition ?: 0L)
                "getDuration" -> result.success(entries[handle]?.player?.duration ?: 0L)
                "dispose" -> {
                    Log.i(TAG, "dispose handle=$handle")
                    entries.remove(handle)?.dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error en método ${call.method}: $e")
            result.error("player_error", e.message, null)
        }
    }

    fun disposeAll() {
        entries.values.forEach { it.dispose() }
        entries.clear()
        clearKeepScreenOn()
    }

    private fun clearKeepScreenOn() {
        val activity = FlutterActivityHolder.current
        if (activity is MainActivity) {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}

@UnstableApi
class PlayerEntry(
    val id: Int,
    private val textureEntry: TextureRegistry.SurfaceTextureEntry,
) {
    private val surface = Surface(textureEntry.surfaceTexture())
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    var player: ExoPlayer? = null

    val textureId: Long get() = textureEntry.id()

    fun setupEvents(binaryMessenger: io.flutter.plugin.common.BinaryMessenger) {
        eventChannel = EventChannel(binaryMessenger, "com.infomak.moai.tv/player/events/$id")
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun emit(event: String, value: Any? = null) {
        val sink = eventSink ?: return
        val payload = if (value == null) {
            mapOf("event" to event)
        } else {
            mapOf("event" to event, "value" to value)
        }
        sink.success(payload)
    }

    private fun setKeepScreenOn(keepOn: Boolean) {
        val activity = FlutterActivityHolder.current
        if (activity is MainActivity) {
            if (keepOn) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    fun buildAndPlay(args: Map<*, *>) {
        // Loose release del player anterior (misma textura, nueva fuente).
        player?.release()
        player = null

        val url = args["url"] as? String ?: run {
            Log.e(PlayerEngine.TAG, "setMedia sin URL -> abortado")
            return
        }
        @Suppress("UNCHECKED_CAST")
        val rawHeaders = (args["headers"] as? Map<String, Any>) ?: emptyMap()
        val headers = rawHeaders.mapValues { it.value.toString() }
        val userAgent = args["userAgent"] as? String
        val mimeType = args["mimeType"] as? String
        val drmUri = args["drmLicenseUri"] as? String
        val drmScheme = args["drmScheme"] as? String
        val title = args["title"] as? String
        val artist = args["artist"] as? String
        val artwork = args["artwork"] as? String

        Log.i(PlayerEngine.TAG,
            "buildAndPlay: url=${url.take(160)}${if (url.length > 160) "..." else ""} " +
                "mime=$mimeType drm=$drmScheme drmUri=${drmUri?.take(120) ?: "-"} " +
                "ua=$userAgent cabeceras=${headers.size}")

        val context = appContext()

        // Cabeceras del canal en TODAS las peticiones de media + UA específico.
        val dsFactory = DefaultHttpDataSource.Factory()
            .setDefaultRequestProperties(headers)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(15_000)
            .setAllowCrossProtocolRedirects(true)
        if (!userAgent.isNullOrEmpty()) {
            dsFactory.setUserAgent(userAgent)
        }

        val bandwidthMeter = DefaultBandwidthMeter.Builder(context)
            .setInitialBitrateEstimate(25_000_000L)
            .build()

        val metadataBuilder = MediaMetadata.Builder()
        if (!title.isNullOrEmpty()) metadataBuilder.setTitle(title)
        if (!artist.isNullOrEmpty()) metadataBuilder.setArtist(artist)
        val mediaMetadata = metadataBuilder.build()

        val mediaBuilder = MediaItem.Builder()
            .setUri(Uri.parse(url))
            .setMediaMetadata(mediaMetadata)
        if (!mimeType.isNullOrEmpty()) mediaBuilder.setMimeType(mimeType)

        val isInlineDrm = !drmUri.isNullOrEmpty() && (drmUri.startsWith("data:") || drmUri.startsWith("inline:"))

        if (!drmUri.isNullOrEmpty()) {
            val uuid = if (drmScheme == "WIDEVINE") C.WIDEVINE_UUID else C.CLEARKEY_UUID
            val targetUri = if (isInlineDrm) Uri.parse("about:blank") else Uri.parse(drmUri)
            val drmBuilder =
                MediaItem.DrmConfiguration.Builder(uuid).setLicenseUri(targetUri)
            if (drmScheme == "WIDEVINE") {
                drmBuilder.setLicenseRequestHeaders(headers)
            }
            mediaBuilder.setDrmConfiguration(drmBuilder.build())
        }
        val mediaItem = mediaBuilder.build()

        val drmProvider = if (isInlineDrm) {
            val rawJsonBytes = when {
                drmUri!!.startsWith("data:application/json;base64,") ->
                    android.util.Base64.decode(drmUri.substringAfter("base64,"), android.util.Base64.DEFAULT)
                drmUri.startsWith("data:application/json,") ->
                    Uri.decode(drmUri.substringAfter("data:application/json,")).toByteArray(Charsets.UTF_8)
                drmUri.startsWith("inline:") ->
                    drmUri.substringAfter("inline:").toByteArray(Charsets.UTF_8)
                else ->
                    drmUri.toByteArray(Charsets.UTF_8)
            }
            val localCallback = LocalMediaDrmCallback(rawJsonBytes)
            DrmSessionManagerProvider {
                DefaultDrmSessionManager.Builder()
                    .setUuidAndExoMediaDrmProvider(C.CLEARKEY_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
                    .build(localCallback)
            }
        } else {
            val provider = DefaultDrmSessionManagerProvider()
            provider.setDrmHttpDataSourceFactory(dsFactory)
            provider
        }

        val mediaSourceFactory = DefaultMediaSourceFactory(context)
            .setDataSourceFactory(dsFactory)
            .setDrmSessionManagerProvider(drmProvider)
            .setLoadErrorHandlingPolicy(object : DefaultLoadErrorHandlingPolicy() {
                override fun getRetryDelayMsFor(
                    loadErrorInfo: LoadErrorHandlingPolicy.LoadErrorInfo
                ): Long = 500L

                override fun getMinimumLoadableRetryCount(dataType: Int): Int = 15
            })

        val newPlayer = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .setBandwidthMeter(bandwidthMeter)
            .setLoadControl(DefaultLoadControl.Builder().build())
            .setRenderersFactory(DefaultRenderersFactory(context))
            .setAudioAttributes(AudioAttributes.DEFAULT, true)
            .build()

        newPlayer.setVideoSurface(surface)
        newPlayer.setVideoScalingMode(C.VIDEO_SCALING_MODE_SCALE_TO_FIT)

        newPlayer.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                val name = when (state) {
                    Player.STATE_READY -> "ready"
                    Player.STATE_BUFFERING -> "buffering"
                    Player.STATE_IDLE -> "idle"
                    Player.STATE_ENDED -> "ended"
                    else -> "unknown"
                }
                Log.i(PlayerEngine.TAG, "estado=$name handle=$id")
                when (state) {
                    Player.STATE_READY -> emit("state", "ready")
                    Player.STATE_BUFFERING -> emit("state", "buffering")
                    Player.STATE_IDLE -> emit("state", "idle")
                    Player.STATE_ENDED -> emit("state", "ended")
                }
            }

            override fun onIsPlayingChanged(playing: Boolean) {
                Log.d(PlayerEngine.TAG, "playing=$playing handle=$id")
                setKeepScreenOn(playing)
                emit("playing", playing)
            }

            override fun onRenderedFirstFrame() {
                Log.i(PlayerEngine.TAG, "PRIMER CUADRO handle=$id")
                emit("firstFrame")
            }

            override fun onVideoSizeChanged(videoSize: androidx.media3.common.VideoSize) {
                if (videoSize.width > 0 && videoSize.height > 0) {
                    textureEntry.surfaceTexture()
                        .setDefaultBufferSize(videoSize.width, videoSize.height)
                }
                Log.i(PlayerEngine.TAG, "videoSize=${videoSize.width}x${videoSize.height} handle=$id")
                emit(
                    "videoSize",
                    mapOf("width" to videoSize.width, "height" to videoSize.height)
                )
            }

            override fun onPlayerError(error: PlaybackException) {
                Log.e(PlayerEngine.TAG,
                    "ERROR code=${error.errorCode} class=${error.javaClass.simpleName} " +
                        "msg=${error.message ?: ""} handle=$id")
                emit(
                    "error",
                    mapOf(
                        "code" to error.errorCode,
                        "message" to (error.message ?: ""),
                        "class" to error.javaClass.simpleName,
                    )
                )
            }
        })

        newPlayer.setMediaSource(mediaSourceFactory.createMediaSource(mediaItem))
        newPlayer.prepare()
        newPlayer.play()
        player = newPlayer
        Log.i(PlayerEngine.TAG, "ExoPlayer creado, reproduciendo en cola " +
            "uri=${url.take(90)}...")
    }

    private fun appContext(): Context {
        // El contexto de la Activity es suficiente para ExoPlayer.
        return FlutterActivityHolder.current
            ?: throw IllegalStateException("Sin contexto de Activity")
    }

    fun dispose() {
        setKeepScreenOn(false)
        player?.release()
        player = null
        try {
            surface.release()
        } catch (_: Exception) {
        }
        textureEntry.release()
        eventChannel?.setStreamHandler(null)
        eventSink = null
    }
}

/** Puente simple para obtener el contexto de la Activity actual. */
object FlutterActivityHolder {
    var current: Context? = null
}