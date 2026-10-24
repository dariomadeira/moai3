package com.infomak.moai
import android.content.Context
import android.net.Uri
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
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

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
                "pauseAll" -> {
                    Log.i(TAG, "pauseAll (pausando streaming de TV)")
                    entries.values.forEach { it.player?.pause() }
                    result.success(null)
                }
                "resumeAll" -> {
                    Log.i(TAG, "resumeAll (reanudando streaming de TV)")
                    entries.values.forEach { it.player?.play() }
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
        // Stop, clear surface, media items and release previous player properly
        try {
            player?.clearMediaItems()
            player?.stop()
            player?.clearVideoSurface()
            player?.release()
        } catch (_: Exception) {
        }
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
            // En vivo un segmento o playlist puede tardar o fallar una vez sin
            // que el canal esté caído: se reintenta como el player web (6).
            .setLoadErrorHandlingPolicy(object : DefaultLoadErrorHandlingPolicy() {
                override fun getRetryDelayMsFor(
                    loadErrorInfo: LoadErrorHandlingPolicy.LoadErrorInfo
                ): Long = 1000L

                override fun getMinimumLoadableRetryCount(dataType: Int): Int = 6
            })

        // Arranque igual de rápido (1 s), pero con hasta 30 s de colchón: con
        // segmentos de 6 s, 5 s de máximo dejaba cortar ante cualquier demora.
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                15_000,
                30_000,
                1_000,
                3_000
            )
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()

        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)

        val newPlayer = ExoPlayer.Builder(context)
            .setMediaSourceFactory(mediaSourceFactory)
            .setBandwidthMeter(bandwidthMeter)
            .setLoadControl(loadControl)
            .setRenderersFactory(renderersFactory)
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
                // DO NOT call surfaceTexture().setDefaultBufferSize() here as it invalidates
                // active SurfaceTexture GraphicBuffers, causing Codec2 dequeue failures and UI freezes.
                Log.i(PlayerEngine.TAG, "videoSize=${videoSize.width}x${videoSize.height} handle=$id")
                emit(
                    "videoSize",
                    mapOf("width" to videoSize.width, "height" to videoSize.height)
                )
            }

            override fun onPlayerError(error: PlaybackException) {
                // Quedó detrás de la ventana del vivo (p. ej. tras un corte de
                // red): se vuelve al vivo en vez de cortar el canal.
                if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW) {
                    Log.w(PlayerEngine.TAG, "Detrás del vivo: vuelvo al borde handle=$id")
                    newPlayer.seekToDefaultPosition()
                    newPlayer.prepare()
                    return
                }
                Log.e(PlayerEngine.TAG,
                    "ERROR code=${error.errorCode} class=${error.javaClass.simpleName} " +
                        "msg=${error.message ?: ""} handle=$id")
                try {
                    newPlayer.stop()
                    newPlayer.clearVideoSurface()
                    newPlayer.clearMediaItems()
                } catch (e: Exception) {
                    Log.w(PlayerEngine.TAG, "Error deteniendo player en onPlayerError: ${e.message}")
                }
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
        try {
            player?.clearMediaItems()
            player?.stop()
            player?.clearVideoSurface()
            player?.release()
        } catch (_: Exception) {
        }
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
