# SPEC-10: Contrato de Plugins v1 (`.dex`)

> **Estado**: Congelado (v1)  
> **Área**: Plataforma Nativa / Plugins  
> **Archivo Fuente de Referencia**: `android/app/src/main/kotlin/com/infomak/moai/contract/PluginContract.kt`

---

## 1. Propósito y Modelo de Carga

Esta especificación define la interfaz inmutable que debe implementar cualquier módulo externo empaquetado en formato `.dex` para ser cargado dinámicamente por MoAI 3.

### Reglas de Runtime ClassLoader:
1. Las clases del contrato residen físicamente en el APK anfitrión (`com.infomak.moai.contract`).
2. El plugin compila externamente contra estas mismas definiciones de clases.
3. Al instalarse o cargarse en tiempo de ejecución, el host instancia un `DexClassLoader` asignando el `ClassLoader` de la aplicación como *parent classloader*.
4. De este modo, las referencias a tipos en el archivo `.dex` resuelven directamente a las clases de la aplicación anfitriona sin duplicación ni `ClassCastException`.

---

## 2. Definición Formal de la Interfaz (Kotlin)

```kotlin
package com.infomak.moai.contract

const val CURRENT_CONTRACT = 1

interface IPlugin {
    /** Retorna el manifiesto del plugin y catálogo estático/inicial de canales. */
    fun manifest(): PluginManifest

    /** Resuelve dinámicamente un canal a una fuente reproducible. Corre en hilo secundario. */
    fun resolve(request: ResolveRequest): ResolveResult
}
```

---

## 3. Estructuras de Datos del Contrato

### 3.1. `PluginChannel`
Representa una entrada de canal aportada por el plugin:
```kotlin
data class PluginChannel(
    val id: String,                 // Identificador único dentro del plugin (ej. "telefe")
    val nombre: String,             // Nombre visible en UI
    val logo: String = "",          // URL o base64 del logo
    val categoria: String = "General", // Categoría temática (Deportes, Noticias, etc.)
    val pais: String = "General",      // País o región (Argentina, España, General)
)
```

### 3.2. `PluginManifest`
Metadatos del plugin exportados por el archivo `.dex`:
```kotlin
data class PluginManifest(
    val id: String,                 // Identificador canónico del plugin (ej. "moai_ar")
    val nombre: String,             // Nombre del plugin visible en ajustes
    val version: String,            // SemVer (ej. "1.0.4")
    val minContrato: Int,           // Mínimo contrato soportado
    val maxContrato: Int,           // Máximo contrato soportado
    val canales: List<PluginChannel>, // Lista de canales provistos
    val clase: String,              // FQCN de la clase que implementa IPlugin
    val tag: String = "",           // Etiqueta visual para UI (ej. "AR", "DL")
    val canalInicial: String? = null // ID de canal preferido para auto-reproducción inicial
)
```

### 3.3. `ResolveRequest`
Petición de resolución emitida por la app al intentar reproducir un canal:
```kotlin
data class ResolveRequest(
    val channelId: String,          // ID del canal solicitado
    val fallbackIndex: Int = 0,     // 0 = primer intento; >0 = reintento tras fallo o token expirado
)
```

### 3.4. `ResolveResult` y `DrmInfo`
Resultado que consume el reproductor nativo (ExoPlayer):
```kotlin
data class DrmInfo(
    val tipo: String,               // "clearkey" | "widevine"
    val licenceUrl: String,         // URL del servidor de licencias DRM
)

data class ResolveResult(
    val url: String,                // URL de stream final directa (HLS / DASH / MP4 / etc.)
    val headers: Map<String, String> = emptyMap(), // Headers HTTP requeridos (User-Agent, Referer)
    val drm: DrmInfo? = null,       // Configuración DRM si aplica
    val format: String = "directo", // "hls" | "dash" | "mpegts" | "directo"
    val ttlMs: Long = 0L,           // Tiempo de vida de la URL en ms (0 = no almacenar en caché)
)
```

---

## 4. Reglas de Validación y Compatibilidad

1. **Rechazo por versión de contrato**:
   Si `CURRENT_CONTRACT` de la app anfitriona queda fuera del rango `[manifest.minContrato, manifest.maxContrato]`, la instalación o carga del plugin se rechaza inmediatamente con un error explícito: `Contrato incompatible`.
2. **Sanitización de cadenas**:
   Si `categoria` o `pais` en `PluginChannel` son vacíos o consisten únicamente en espacios en blanco, el host o catálogo los sustituye automáticamente por `'General'`.
3. **Hilo de Ejecución de `resolve`**:
   La invocación de `IPlugin.resolve` **NUNCA** debe ejecutarse en el hilo principal (UI thread), ya que puede realizar llamadas HTTP o cómputo intensivo (desencriptación de tokens).
