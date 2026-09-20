package com.infomak.moai.plugin

import android.os.Handler
import android.os.Looper
import android.content.Context
import android.util.Log
import com.infomak.moai.contract.CURRENT_CONTRACT
import com.infomak.moai.contract.DrmInfo
import com.infomak.moai.contract.IPlugin
import com.infomak.moai.contract.PluginChannel
import com.infomak.moai.contract.PluginManifest
import com.infomak.moai.contract.ResolveRequest
import com.infomak.moai.contract.ResolveResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext

/**
 * Host de plugins `.dex`: descarga, verifica (SHA-256), cachea en
 * `files/plugins/<id>/` y carga con [DexClassLoader]. Expone el canal
 * `com.infomak.moai.tv/plugin`.
 */
class PluginLoader(private val context: Context) {
    companion object {
        const val TAG = "MoaiPlugin"

        private const val DOWNLOAD_TIMEOUT_MS = 30_000
        private const val RESOLVE_TIMEOUT_SECONDS = 20L
        private const val UA =
            "MoaiPlugin/1.0 (Android; Moai TV)"
    }

    private data class InstalledPlugin(
        val manifest: PluginManifest,
        val sourceUrl: String,
        val dexPath: String,
    )

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Archivo-tipo de disco (instalaciones persistentes entre arranques). */
    private val pluginsDir = File(context.filesDir, "plugins")

    /** Instalaciones visibles, keyed por plugin id. */
    private val installed = mutableMapOf<String, InstalledPlugin>()

    /** Instancias cargadas (estado interno de tokens/sesiones vive acá). */
    private val instances = mutableMapOf<String, IPlugin>()

    /** Archivos en serie (un install/update/remove a la vez). */
    private val fileExecutor = Executors.newSingleThreadExecutor()

    /** resolve() por plugin, con timeout estricto. */
    private val resolveExecutor = Executors.newFixedThreadPool(2)

    init {
        scanInstalledFromDisk()
    }

    fun attach(binaryMessenger: BinaryMessenger) {
        MethodChannel(binaryMessenger, "com.infomak.moai.tv/plugin")
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    fun shutdown() {
        fileExecutor.shutdownNow()
        resolveExecutor.shutdownNow()
    }

    // ---------------------------------------------------------------- registro

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "install", "update" -> {
                val url = call.argument<String>("url")
                    ?: return result.error("plugin_error", "Falta 'url'", null)
                fileExecutor.execute {
                    try {
                        val res = pluginMap(install(url))
                        mainHandler.post { result.success(res) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("plugin_error", e.message ?: e.toString(), null) }
                    }
                }
            }

            "list" -> {
                fileExecutor.execute {
                    try {
                        val res = installed.values.map { pluginMap(it) }
                        mainHandler.post { result.success(res) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("plugin_error", e.message ?: e.toString(), null) }
                    }
                }
            }

            "resolve" -> {
                val pluginId = call.argument<String>("pluginId")
                val channelId = call.argument<String>("channelId")
                if (pluginId == null || channelId == null) {
                    result.error(
                        "plugin_error",
                        "resolve necesita pluginId y channelId",
                        null,
                    )
                    return
                }
                resolveExecutor.execute {
                    try {
                        val res = resolveMap(resolve(pluginId, channelId))
                        mainHandler.post { result.success(res) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("plugin_error", e.message ?: e.toString(), null) }
                    }
                }
            }

            "remove" -> {
                val id = call.argument<String>("id")
                    ?: return result.error("plugin_error", "Falta 'id'", null)
                fileExecutor.execute {
                    try {
                        val res = remove(id)
                        mainHandler.post { result.success(res) }
                    } catch (e: Exception) {
                        mainHandler.post { result.error("plugin_error", e.message ?: e.toString(), null) }
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------ instalación

    private fun install(rawUrl: String): InstalledPlugin {
        val (manifestUrl, dexUrl) = deriveUrls(rawUrl)
        Log.i(TAG, "install: $manifestUrl + $dexUrl")

        val manifestBytes = download(manifestUrl)
        val manifestJson = JSONObject(String(manifestBytes, Charsets.UTF_8))
        val manifest = parseManifest(manifestJson)

        val dexBytes = download(dexUrl)
        verifySha256(manifestJson, dexBytes)
        
        val dir = File(pluginsDir, manifest.id).apply { mkdirs() }
        File(dir, "manifest.json").writeBytes(manifestBytes)

        val dexFile = File(dir, "plugin.dex")
        if (dexFile.exists()) {
            dexFile.setWritable(true)
            dexFile.delete()
        }
        dexFile.writeBytes(dexBytes)
        dexFile.setReadOnly()

        File(dir, "source.txt").writeText(rawUrl)

        val plugin = InstalledPlugin(
            manifest = manifest,
            sourceUrl = rawUrl,
            dexPath = dexFile.absolutePath,
        )
        installed[manifest.id] = plugin
        instances.remove(manifest.id) // fuerza recarga con el dex nuevo
        Log.i(TAG, "Instalado ${manifest.nombre} v${manifest.version} " +
            "(${manifest.canales.size} canales) sha256 ok")
        return plugin
    }

    /** Acepta URL a `plugin.dex` o `manifest.json`; deriva la otra. */
    private fun deriveUrls(url: String): Pair<String, String> {
        val name = url.substringAfterLast('/', "")
        if (name.isEmpty()) {
            throw IllegalArgumentException("URL inválida: $url")
        }
        return when (name) {
            "plugin.dex" -> Pair(url.replaceLast("plugin.dex", "manifest.json"), url)
            "manifest.json" -> Pair(url, url.replaceLast("manifest.json", "plugin.dex"))
            else -> throw IllegalArgumentException(
                "La URL debe apuntar a 'plugin.dex' o 'manifest.json' (último segmento)"
            )
        }
    }

    private fun download(url: String): ByteArray {
        if (!url.startsWith("https://")) {
            throw IllegalArgumentException("Solo HTTPS: $url")
        }
        val raw = URL(url).openConnection()
        if (raw !is HttpURLConnection) {
            throw IOException("Conexión no HTTP: $url")
        }
        val conn = raw as HttpURLConnection
        if (conn is HttpsURLConnection) {
            conn.sslSocketFactory = SSLContext.getDefault().socketFactory
            conn.hostnameVerifier = HttpsURLConnection.getDefaultHostnameVerifier()
        }
        conn.connectTimeout = DOWNLOAD_TIMEOUT_MS
        conn.readTimeout = DOWNLOAD_TIMEOUT_MS
        conn.instanceFollowRedirects = true
        conn.setRequestProperty("User-Agent", UA)
        conn.setRequestProperty("Accept", "*/*")
        try {
            conn.connect()
            val code = conn.responseCode
            if (code !in 200..299) {
                throw IOException("HTTP $code al descargar $url")
            }
            return conn.inputStream.use { it.readBytes() }
        } finally {
            conn.disconnect()
        }
    }

    private fun parseManifest(json: JSONObject): PluginManifest {
        val id = json.optString("id", "").trim()
        val nombre = json.optString("nombre", "").trim()
        val version = json.optString("version", "").trim()
        val clase = json.optString("clase", "").trim()
        val minContrato = json.optInt("minContrato", 1)
        val maxContrato = json.optInt("maxContrato", CURRENT_CONTRACT)
        if (id.isEmpty() || nombre.isEmpty() || version.isEmpty() || clase.isEmpty()) {
            throw IllegalArgumentException("manifest.json incompleto " +
                "(faltan id/nombre/version/clase)")
        }
        if (CURRENT_CONTRACT < minContrato || CURRENT_CONTRACT > maxContrato) {
            throw IllegalArgumentException(
                "Contrato incompatible: app usa $CURRENT_CONTRACT " +
                    "y el plugin pide [$minContrato..$maxContrato]"
            )
        }

        val canales = mutableListOf<PluginChannel>()
        val canalesJson = json.optJSONArray("canales")
        if (canalesJson != null) {
            for (i in 0 until canalesJson.length()) {
                val c = canalesJson.optJSONObject(i) ?: continue
                val cid = c.optString("id", "").trim()
                val cname = c.optString("nombre", "").trim()
                if (cid.isEmpty() || cname.isEmpty()) continue
                canales.add(
                    PluginChannel(
                        id = cid,
                        nombre = cname,
                        logo = c.optString("logo", ""),
                        categoria = c.optString("categoria", "General"),
                        pais = c.optString("pais", "General"),
                    )
                )
            }
        }
        if (canales.isEmpty()) {
            throw IllegalArgumentException("manifest.json sin canales")
        }

        val tagRaw = json.optString("tag", "").trim()
        val tag = if (tagRaw.isNotEmpty()) {
            tagRaw
        } else if (id.startsWith("moai_")) {
            id.removePrefix("moai_")
        } else {
            ""
        }

        return PluginManifest(
            id = id,
            nombre = nombre,
            version = version,
            minContrato = minContrato,
            maxContrato = maxContrato,
            canales = canales,
            clase = clase,
            tag = tag,
        )
    }

    private fun verifySha256(json: JSONObject, dexBytes: ByteArray) {
        val expected = json.optString("sha256", "").trim().lowercase()
        if (expected.isEmpty()) {
            throw IllegalArgumentException(
                "manifest.json sin sha256: es obligatorio para instalar/actualizar"
            )
        }
        val digest = MessageDigest.getInstance("SHA-256").digest(dexBytes)
        val actual = digest.joinToString("") { "%02x".format(it) }
        if (expected != actual) {
            throw IllegalArgumentException(
                "SHA-256 mismatch en plugin.dex (esperado=$expected, actual=$actual)"
            )
        }
    }

    // -------------------------------------------------------------- ejecución

    fun resolve(pluginId: String, channelId: String): ResolveResult {
        val plugin = installed[pluginId]
            ?: throw IllegalArgumentException("Plugin no instalado: $pluginId")
        val instance = loadPlugin(plugin)

        val future: Future<ResolveResult> = resolveExecutor.submit(
            Callable {
                instance.resolve(ResolveRequest(channelId = channelId))
            }
        )
        return try {
            future.get(RESOLVE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (t: TimeoutException) {
            future.cancel(true)
            throw IllegalArgumentException(
                "resolve() excedió ${RESOLVE_TIMEOUT_SECONDS}s en $pluginId"
            )
        } catch (t: Exception) {
            throw t
        }
    }

    private fun loadPlugin(plugin: InstalledPlugin): IPlugin {
        instances[plugin.manifest.id]?.let { return it }
        val sourceDexFile = File(plugin.dexPath)
        if (!sourceDexFile.exists()) {
            throw IllegalArgumentException("Archivo dex no encontrado: ${plugin.dexPath}")
        }

        // Copiar dex a codeCacheDir para garantizar permisos de ejecución SELinux y compatibilidad con almacenamiento expandido (/mnt/expand/...)
        val codeCachePluginDir = File(context.codeCacheDir, "plugins/${plugin.manifest.id}").apply { mkdirs() }
        val targetDexFile = File(codeCachePluginDir, "plugin.dex")
        if (targetDexFile.exists()) {
            targetDexFile.setWritable(true)
            targetDexFile.delete()
        }
        sourceDexFile.copyTo(targetDexFile, overwrite = true)
        targetDexFile.setReadOnly()

        val optimizedDir = File(codeCachePluginDir, "odex").apply { mkdirs() }

        val loader = dalvik.system.DexClassLoader(
            targetDexFile.absolutePath,
            optimizedDir.absolutePath,
            null,
            context.classLoader,
        )
        val clazz = loader.loadClass(plugin.manifest.clase)
        val instance = clazz.getConstructor().newInstance() as IPlugin
        instances[plugin.manifest.id] = instance
        Log.i(TAG, "IPlugin cargado: ${plugin.manifest.clase} (${plugin.manifest.id})")
        return instance
    }

    // ------------------------------------------------------------ desinstalar

    private fun remove(id: String): Boolean {
        val removed = installed.remove(id) ?: return false
        instances.remove(id)
        val dir = File(pluginsDir, id)
        if (dir.exists()) {
            dir.walkBottomUp().forEach { file ->
                file.setWritable(true)
            }
            dir.deleteRecursively()
        }
        val cacheDir = File(context.codeCacheDir, "plugins/$id")
        if (cacheDir.exists()) {
            cacheDir.walkBottomUp().forEach { file ->
                file.setWritable(true)
            }
            cacheDir.deleteRecursively()
        }
        Log.i(TAG, "Plugin eliminado: $id")
        return removed.manifest.id == id
    }

    // ------------------------------------------------------------- persistencia

    private fun scanInstalledFromDisk() {
        val dirs = pluginsDir.listFiles()?.filter { it.isDirectory } ?: return
        for (dir in dirs) {
            val manifestFile = File(dir, "manifest.json")
            val dexFile = File(dir, "plugin.dex")
            val sourceFile = File(dir, "source.txt")
            if (!manifestFile.exists() || !dexFile.exists() || !sourceFile.exists()) {
                continue
            }
            try {
                val manifest = parseManifest(
                    JSONObject(String(manifestFile.readBytes(), Charsets.UTF_8))
                )
                installed[manifest.id] = InstalledPlugin(
                    manifest = manifest,
                    sourceUrl = sourceFile.readText().trim(),
                    dexPath = dexFile.absolutePath,
                )
            } catch (e: Exception) {
                Log.w(TAG, "Instalación corrupta en ${dir.name}: ${e.message}")
            }
        }
    }

    // ------------------------------------------------------------ serialización

    private fun pluginMap(p: InstalledPlugin): Map<String, Any?> = mapOf(
        "id" to p.manifest.id,
        "tag" to p.manifest.tag,
        "nombre" to p.manifest.nombre,
        "version" to p.manifest.version,
        "minContrato" to p.manifest.minContrato,
        "maxContrato" to p.manifest.maxContrato,
        "sourceUrl" to p.sourceUrl,
        "canales" to p.manifest.canales.map { c ->
            mapOf(
                "id" to c.id,
                "nombre" to c.nombre,
                "logo" to c.logo,
                "categoria" to c.categoria,
                "pais" to c.pais,
            )
        },
    )

    private fun resolveMap(r: ResolveResult): Map<String, Any?> = mapOf(
        "url" to r.url,
        "headers" to r.headers,
        "drmTipo" to r.drm?.tipo,
        "drmLicenceUrl" to r.drm?.licenceUrl,
        "format" to r.format,
        "ttlMs" to r.ttlMs,
    )

    // ---------------------------------------------------------------- helpers

    private fun String.replaceLast(old: String, new: String): String {
        val idx = lastIndexOf(old)
        if (idx < 0) return this
        return substring(0, idx) + new + substring(idx + old.length)
    }
}