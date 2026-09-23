package com.infomak.moai.contract

/**
 * Contrato v1 de plugins (.dex). Congelado: los nombres de clases y métodos
 * no cambian jamás. Si cambian, es una versión nueva de [CURRENT_CONTRACT].
 *
 * Las clases de este paquete viven EN LA APP (APK). El plugin las referencia
 * por nombre; al cargarse con la app como parent classloader, se resuelven a
 * estas. Los repos de plugins compilan contra este mismo contrato.
 */
const val CURRENT_CONTRACT = 1

/** Implementado por cada plugin (`.dex`). La única cara que ve la app. */
interface IPlugin {
    fun manifest(): PluginManifest

    /** Resuelve un canal a una fuente reproducible. Corre en hilo hijo. */
    fun resolve(request: ResolveRequest): ResolveResult
}

/** Un canal que el plugin aporta al catálogo (aparece en la UI). */
data class PluginChannel(
    val id: String,
    val nombre: String,
    val logo: String = "",
    val categoria: String = "General",
    val pais: String = "General",
)

/** Metadata declarada por el plugin (vive también en su manifest.json). */
data class PluginManifest(
    val id: String,
    val nombre: String,
    val version: String,
    val minContrato: Int,
    val maxContrato: Int,
    val canales: List<PluginChannel>,
    /** FQCN de la clase que implementa [IPlugin], ej. "com.fuente.Plugin". */
    val clase: String,
    val tag: String = "",
    val canalInicial: String? = null,
)

/** Lo que la app le pide al plugin al abrir un canal. */
data class ResolveRequest(
    val channelId: String,
    /**
     * 0 = primer intento. >0 = reintento/fallback: el plugin puede re-resolver
     * (token renovado, otro manifiesto, etc.) si su fuente "envejeció".
     */
    val fallbackIndex: Int = 0,
)

/** DRM opcional que el resultado pide pasarle al motor. */
data class DrmInfo(
    val tipo: String,           // "clearkey" | "widevine"
    val licenceUrl: String,
)

/** Lo único que consume el motor: reproduce esto tal cual, sin interpretarlo. */
data class ResolveResult(
    val url: String,
    val headers: Map<String, String> = emptyMap(),
    val drm: DrmInfo? = null,
    /** "hls" | "dash" | "mpegts" | "directo". */
    val format: String = "directo",
    /** TTL de la resolución. 0 = no cachear. (Reserva para futuras versiones.) */
    val ttlMs: Long = 0L,
)