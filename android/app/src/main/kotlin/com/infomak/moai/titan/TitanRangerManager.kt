package com.infomak.moai.titan

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import com.google.gson.Gson
import com.titan.ranger.JniHandler
import com.titan.ranger.NativeJni
import com.titan.ranger.Status
import com.titan.ranger.bean.Entry
import com.titan.ranger.bean.Env
import com.titan.ranger.bean.Media
import com.titan.ranger.bean.Program
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

class TitanRangerManager(private val context: Context) {
    companion object {
        private const val TAG = "TitanRangerManager"
        private const val CHANNEL_NAME = "com.infomak.moai.tv/titan_ranger"
        private val gson = Gson()
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var isInitialized = false

    fun registerChannel(channelMessenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(channelMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> handleInit(call, result)
                "getAndroidId" -> handleGetAndroidId(result)
                "setEnv" -> handleSetEnv(call, result)
                "setEntries" -> handleSetEntries(call, result)
                "prepareProgram" -> handlePrepareProgram(call, result)
                "stopProgram" -> handleStopProgram(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleInit(call: MethodCall, result: MethodChannel.Result) {
        try {
            val workPath = call.argument<String>("workPath") ?: context.filesDir.absolutePath
            NativeJni.c().initWorkPath(workPath)
            // Igual que la app oficial: consultar versión tras crear el singleton
            // garantiza que la librería nativa quedó enlazada correctamente.
            NativeJni.c().getVersion()
            isInitialized = true
            Log.i(TAG, "Titan Ranger initialized with workPath: $workPath")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "handleInit error: ${e.message}", e)
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun handleGetAndroidId(result: MethodChannel.Result) {
        try {
            val androidId = Settings.System.getString(context.contentResolver, "android_id") ?: ""
            Log.i(TAG, "Android ID: $androidId")
            result.success(androidId)
        } catch (e: Exception) {
            Log.e(TAG, "handleGetAndroidId error: ${e.message}", e)
            result.success("")
        }
    }

    private fun handleSetEnv(call: MethodCall, result: MethodChannel.Result) {
        try {
            val map = call.argument<Map<String, Any>>("env") ?: emptyMap()
            val env = Env(
                map["app"] as? String ?: "com.android.msandroid",
                map["app_ver"] as? String ?: "50503",
                map["user_id"] as? String ?: "",
                map["dev_id"] as? String ?: "",
                map["communication_key"] as? String ?: "2b494e53756c664c2f44465245733572",
                map["params"] as? String ?: "",
                map["android_id"] as? String ?: "",
                (map["titan_port"] as? Number)?.toInt() ?: 0
            )
            val jsonEnv = gson.toJson(env)
            NativeJni.c().setEnv(jsonEnv)
            Log.i(TAG, "SetEnv dispatched: $jsonEnv")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "handleSetEnv error: ${e.message}", e)
            result.error("ENV_ERROR", e.message, null)
        }
    }

    private fun handleSetEntries(call: MethodCall, result: MethodChannel.Result) {
        try {
            val rawList = call.argument<List<Map<String, Any>>>("entries") ?: emptyList()
            val entries = rawList.map { m ->
                val authsRaw = m["auths"] as? List<*> ?: emptyList<Any>()
                val auths = authsRaw.mapNotNull { it?.toString() }
                Entry(
                    m["name"] as? String ?: "",
                    m["buss"] as? String ?: "free",
                    m["strategy"] as? String ?: "",
                    m["main_addr"] as? String ?: "",
                    m["main_addr_code"] as? String ?: "",
                    m["spare_addr"] as? String ?: "",
                    m["spare_addr_code"] as? String ?: "",
                    m["redirect"] as? String ?: "",
                    m["tag"] as? String ?: "",
                    m["sign_type"] as? String ?: "",
                    (m["priority"] as? Number)?.toInt() ?: 1,
                    (m["enable"] as? Number)?.toInt() ?: 1,
                    auths,
                    m["gslb_params"] as? String ?: ""
                )
            }
            val jsonEntries = gson.toJson(entries)
            NativeJni.c().setEntries(jsonEntries)
            Log.i(TAG, "SetEntries dispatched (${entries.size} entries)")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "handleSetEntries error: ${e.message}", e)
            result.error("ENTRIES_ERROR", e.message, null)
        }
    }

    private fun handlePrepareProgram(call: MethodCall, result: MethodChannel.Result) {
        val instanceId = call.argument<Int>("instanceId") ?: 0
        val name = call.argument<String>("name") ?: "vod"
        val extra = call.argument<String>("extra") ?: ""

        val progMap = call.argument<Map<String, Any>>("program")
        if (progMap == null) {
            result.error("ARG_ERROR", "Missing program map", null)
            return
        }

        try {
            val mediasRaw = progMap["medias"] as? List<Map<String, Any>> ?: emptyList()
            val medias = mediasRaw.map { mm ->
                Media(
                    mm["name"] as? String ?: "",
                    mm["license"] as? String ?: "",
                    mm["lang"] as? String ?: "spa",
                    mm["quality"] as? String ?: "720p",
                    mm["vcodec"] as? String ?: "h265",
                    mm["format"] as? String ?: "ts"
                )
            }

            val program = Program(
                progMap["name"] as? String ?: "",
                progMap["buss"] as? String ?: "vod",
                progMap["title"] as? String ?: "",
                progMap["episode"] as? String ?: "1",
                progMap["from"] as? String ?: "detail",
                progMap["cause"] as? String ?: "user",
                medias,
                progMap["media"] as? String ?: "",
                (progMap["start"] as? Number)?.toLong() ?: 0L
            )

            val jsonProgram = gson.toJson(program)
            val hasResponded = AtomicBoolean(false)

            // Setup JniHandler callback listener for this instanceId
            val listener = object : JniHandler.a {
                override fun a(i10: Int, str: String?, str2: String?, str3: String?): Int = 0
                override fun b(): Int = instanceId
                override fun c(str: String?, str2: String?, i10: Int): Int = 0

                override fun d(i10: Int, event: String?, obj: Any?, err: Long): Int {
                    Log.i(TAG, "JniHandler callback instance=$i10 event=$event err=$err obj=$obj")
                    if (event == "media_prepared" || event == "cast_prepared") {
                        // Ranger puede emitir media_prepare_error intermedios mientras
                        // cambia de CDN y después media_prepared con err=0. Solo este
                        // último es válido; los errores intermedios no son definitivos.
                        if (err == 0L && obj is Status && !obj.play_url.isNullOrEmpty() &&
                            hasResponded.compareAndSet(false, true)
                        ) {
                            mainHandler.post {
                                val resMap = hashMapOf<String, Any?>(
                                    "play_url" to obj.play_url,
                                    "format" to obj.format,
                                    "media_buffer" to obj.media_buffer,
                                    "latency" to obj.latency,
                                    "buss" to obj.buss,
                                    "err" to err
                                )
                                Log.i(TAG, "Ranger resolved play_url: ${obj.play_url}")
                                result.success(resMap)
                            }
                        } else {
                            Log.w(TAG, "Evento $event ignorado (err=$err, play_url=${(obj as? Status)?.play_url})")
                        }
                    } else if (err != 0L) {
                        // No responder todavía: Ranger seguirá probando otras fuentes.
                        Log.w(TAG, "Evento intermedio $event err=$err; esperando media_prepared")
                    }
                    return 0
                }

                override fun t(str: String?, str2: String?, j10: Long): Int = 0
            }

            JniHandler.d(0, listener)
            JniHandler.d(instanceId, listener)

            // La app oficial NO llama a SetPlayer antes del primer PrepareProgram:
            // su motor por defecto es EnumC7259b.NATIVE ("native"). Forzar "exo"
            // hacía que Ranger esperara eventos de un reproductor externo y nunca
            // emitiera OnPrepareEvent. Ver C7707e.m29678U0 / m29689t0.

            // Ranger puede tardar >20s si el primer CDN falla y cambia de fuente.
            // La app oficial no impone un timeout corto; esperamos hasta 60s.
            mainHandler.postDelayed({
                if (hasResponded.compareAndSet(false, true)) {
                    Log.w(TAG, "Timeout waiting for Ranger media_prepared (60s)")
                    result.error("TIMEOUT", "Titan Ranger prepareProgram timed out", null)
                }
            }, 60000)

            NativeJni.c().prepareProgram(instanceId, name, jsonProgram, extra)
            Log.i(TAG, "PrepareProgram dispatched: name=$name extra=$extra program=$jsonProgram")

        } catch (e: Exception) {
            Log.e(TAG, "handlePrepareProgram error: ${e.message}", e)
            result.error("PREPARE_ERROR", e.message, null)
        }
    }

    private fun handleStopProgram(call: MethodCall, result: MethodChannel.Result) {
        val instanceId = call.argument<Int>("instanceId") ?: 1
        val name = call.argument<String>("name") ?: "vod"
        try {
            NativeJni.c().stopProgram(instanceId, name)
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }
}
