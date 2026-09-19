# Contrato de plugin v1 (`.dex`) — congelado

> Estado: **congelado (v1)**. Define la interfaz que cualquier fuente `.dex`
> debe implementar para ser cargada por el host de moai3.
> Complemento formal de `Plugins_Resolucion_Runtime_Dex.md` y de la Fase 3
> del `Plan_Implementacion_Moai3_Motor_Plugins.md`.

---

## 1. Interfaz (Kotlin)

Las clases viven **en la app** (paquete `com.infomak.moai.contract`). El plugin
compila contra esta misma interfaz; al cargarse con la app como *parent
classloader*, sus referencias resuelven a estas clases. Los nombres no cambian
jamás (si cambian, es una **nueva versión de contrato** y la app vieja rechaza
plugins más nuevos).

```kotlin
interface IPlugin {
    fun manifest(): PluginManifest
    fun resolve(request: ResolveRequest): ResolveResult
}
```

Versionado: el host usa `CURRENT_CONTRACT = 1`. El plugin declara
`minContrato`/`maxContrato`; si `CURRENT_CONTRACT` queda fuera del rango, la
instalación se rechaza con "Contrato incompatible".

### Datos de entrada/salida

```kotlin
data class PluginChannel(
    val id: String,          val nombre: String,
    val logo: String = "",   val categoria: String = "General",
    val pais: String = "General",
)

data class PluginManifest(
    val id: String,          val nombre: String,
    val version: String,     val minContrato: Int,
    val maxContrato: Int,    val canales: List<PluginChannel>,
    val clase: String,          // FQCN que implementa IPlugin, ej "com.fuente.Plugin"
)

data class ResolveRequest(
    val channelId: String,
    val fallbackIndex: Int = 0,   // >0 = reintento: re-resolver (token/URL nueva)
)

data class DrmInfo(
    val tipo: String,           // "clearkey" | "widevine"
    val licenceUrl: String,
)

data class ResolveResult(
    val url: String,
    val headers: Map<String, String> = emptyMap(),
    val drm: DrmInfo? = null,
    val format: String = "directo",  // "hls" | "dash" | "mpegts" | "directo"
    val ttlMs: Long = 0L,            // TTL de la resolución (0 = no cachear)
)
```

**Reglas de `resolve()`:**
- Corre en hilo hijo **siempre** (el host lo espera con timeout de 20 s).
- Es síncrono desde el punto de vista del host; el plugin hace su propio
  HTTP/network interno si quiere.
- El motor **solo reproduce** lo que devuelve; no interpreta lógica interna.
- Puede re-resolver por `fallbackIndex` (token viejo, manifiesto nuevo, etc.).

---

## 2. `manifest.json` (lo que aterriza en `files/plugins/<id>/`)

```json
{
  "id": "source-xyz",
  "nombre": "Fuente XYZ",
  "version": "1.2.0",
  "minContrato": 1,
  "maxContrato": 1,
  "clase": "com.fuente.Plugin",
  "canales": [
    {
      "id": "c1",
      "nombre": "Canal 1",
      "logo": "https://…/logo.png",
      "categoria": "General",
      "pais": "AR"
    }
  ]
}
```

El host añade en el momento de instalar:
- **`sha256`** (hex, minúsculas) del `plugin.dex` — verificación **siempre-on**;
  si falta o no coincide, la instalación se rechaza.

Repos de fuente: el artefacto se publica por **tag** (`v1.2.0`) con
`manifest.json` + `plugin.dex` en la misma ref. El usuario pega la URL de
`plugin.dex` **o** de `manifest.json`; el host deriva la otra (mismo directorio).

---

## 3. Canal del host (`com.infomak.moai.tv/plugin`)

| Método | Args | Resultado |
|---|---|---|
| `install` | `url` | `PluginSource` (id, nombre, versión, canales, sourceUrl) |
| `update` | `url` | `PluginSource` re-descargada (mismo `id`, nueva versión) |
| `list` | — | `List<PluginSource>` instaladas (leídas de disco) |
| `remove` | `id` | `bool` |
| `resolve` | `pluginId`, `channelId` | `ResolveResult` |

Errores → `PlatformException(code: "plugin_error", message, details)`.

### `PluginSource` (modelo Dart→UI)

```
id, nombre, version, minContrato, maxContrato, sourceUrl,
canales: [{ id, nombre, logo, categoria, pais }]
```

### `ResolveResult` del canal (Dart→motor)

```
url, headers: {User-Agent, ...}, drmTipo, drmLicenceUrl, format, ttlMs
```

`format → hint MIME`: `hls` → `application/x-mpegURL`, `dash` →
`application/dash+xml`, `mpegts|directo` → null (ExoPlayer lo deduce).

---

## 4. Cómo el host identifica un canal de plugin

- Canal de catálogo: `Channel(id: "plugin:<pluginId>:<channelId>",
  pluginId, pluginChannelId, pluginName, …)`.
- Playback: `ChannelPlaybackHelpers.resolvePlayback()` pide al plugin
  `resolve(pluginId, channelId)` y entrega `{ url, headers, mimeType }` al motor
  Kotlin (ExoPlayer). Cada reintento re-resuelve (URL fresca).
- Fuentes probables de un canal-plugin = 1: los fallbacks multi-URL son
  internos del plugin (el re-intento vuelve a pedir su `resolve`).

---

## 5. Seguridad

- Descargas **solo HTTPS** (se rechaza `http:`).
- `sha256` del dex verificado contra el manifest **antes de cargar**.
- Caché local: `files/plugins/<id>/manifest.json`, `plugin.dex`, `odex/`.
- El plugin corre en el proceso de la app: un plugin roto puede tumbar la app
  (riesgo asumido; ver riesgos en el doc de diseño).

---

## 6. Fuera de alcance en v1

- Prioridad entre múltiples fuentes para el mismo canal (v1: primer instalado
  gana el id compuesto; no hay dedupe por nombre de canal).
- Verificación por firma (solo hash).
- `ttlMs` (reserva): el host aún no cachea resultados de `resolve`.