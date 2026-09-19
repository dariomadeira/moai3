# Plugins de resolución cargados en runtime (`.dex` / `DexClassLoader`)

> Estado: **diseño / paso 1 — documentación**
> Alcance: host = moai3 (Android). Compatibilidad: Android (sideload/TV).
> Fuera de alcance: iOS, web, desktop, Google Play (ver sección 11).

---

## 1. Objetivo

Permitir que un usuario agregue **fuentes de canales de TV** a la app pasándole
simplemente una **URL de un repositorio git**, **sin recompilar el APK** y **sin
hostear ningún servidor**.

Cada fuente (el "plugin") puede tener **lógica viva**: resolución con tokens,
probes HTTP, redirecciones, headers custom, DRM y manejo de sesión. Esa lógica
corre **dentro de la app**, en el propio dispositivo Android.

Esta lógica viva no puede ser código Dart (Dart está compilado AOT en el APK y
no admite carga dinámica en runtime). Por eso se usa **código nativo Kotlin/Java
compilado a un archivo `.dex`**, descargado desde una URL y cargado en runtime
con `DexClassLoader`.

---

## 2. Resumen de decisiones

| Decisión | Elección | Por qué |
|---|---|---|
| Donde corre la lógica | Dentro de la app (dispositivo) | IP residencial real → los cheques geo de Flow/Tigo pasan como hoy |
| Formato del artefacto | `.dex` (DexClassLoader) | Se escribe el plugin en Kotlin; sin ABI C/NDK |
| Instalación | URL de git (raw/HTTP) | Sin pub.dev, sin recompilar, sin host |
| Motor de reproducción | El que ya existe (ExoPlayer) | No se toca; el plugin solo produce `{ url, headers, drm, format }` |
| El plugin "solo dice qué mostrar" | Resolver en el plugin, motor tonto | Motor único, lógica por fuente en el plugin |
| Distribución | Repositorio git + tags | Versionado natural, re-descarga manual |

---

## 3. Modelo general (3 partes)

```
┌───────────────────────────── App (APK compilado) ────────────────────────────┐
│                                                                              │
│  ┌────────────────────┐    ┌─────────────────────────────────────────────┐   │
│  │  UI / Estado       │    │   PluginHostService (Dart)                  │   │
│  │  (moai3 AppState)  │───▶│   - listar plugins                          │   │
│  │                    │    │   - pedir canales de un plugin              │   │
│  │                    │    │   - resolver un canal                       │   │
│  └─────────┬──────────┘    └───────────────────┬─────────────────────────┘   │
│            │                                   │ MethodChannel              │
│            ▼                                   ▼                             │
│  ┌────────────────────┐    ┌─────────────────────────────────────────────┐   │
│  │  Player / Engine   │◀───│   PluginLoader (Kotlin)                     │   │
│  │  (ExoPlayer)       │    │   - descargar .dex de una URL               │   │
│  │  reproduce el      │    │   - verificar (hash/firma)                  │   │
│  │  resultado final   │    │   - cargar con DexClassLoader               │   │
│  └────────────────────┘    │   - instanciar IPlugin (reflexión)          │   │
│                            └───────────────────┬─────────────────────────┘   │
│                                                │ resolve()                  │
└────────────────────────────────────────────────┴─────────────────────────────┘
                                                   │
                                            VIVE EN GIT (no en la app)
                                            ┌┴──────────────────────────┐
                                            │  plugin.kotlin → .dex      │
                                            │  manifest + interfaz       │
                                            └────────────────────────────┘
```

- El **plugin** es un proyecto Kotlin independiente que compila a `.dex`.
- La **app** solo sabe hablar con un contrato mínimo y estable.
- El **motor** (ExoPlayer) ya existente reproduce el resultado que el plugin
  devuelve. Nunca ve la lógica interna del plugin.

---

## 4. Componentes

### 4.1 Host — `PluginHostService` (Dart, dentro del APK)

Estado público de plugins disponibles:

```
id            → string único (para persistir la instalación)
nombre        → para la UI
version       → del plugin (para saber si hay update)
canales       → lista de canales que el plugin aporta
  id, nombre, logo, categoría, país
```

API pública (Dart → Kotlin vía MethodChannel):

```
install(url)      → descarga + verifica + cachea + expone canales
list()            → plugins instalados + su estado
resolve(pluginId, channelId) → devuelve { url, headers, drm, format }
update(url)       → re-descarga una versión nueva del mismo plugin
remove(url|id)    → elimina de caché y de la UI
```

### 4.2 Host — `PluginLoader` (Kotlin, dentro del APK)

Responsabilidades:

- Descargar el `.dex` (y su `manifest.json` / hash) con HTTP(S).
- Verificar integridad (hash) antes de cargar.
- Guardar en el **files dir** del app (`files/plugins/`).
- Crear un `DexClassLoader` por plugin, aislado (classloader propio).
- Reflejar e instanciar la clase que implementa `IPlugin`.
- Ejecutar `resolve()` en un hilo hijo (nunca en el main thread) con timeout.
- Cachear resultados cortos si el contrato lo permite.

### 4.3 Motor — respetando el que ya existe

- En **moai3**: `video_player` (ExoPlayer) ya reproduce HLS/DASH/MPEG-TS con
  headers. El resultado de `resolve()` aterriza en `ChannelPlaybackHelpers`
  (`resolveStreamUrl`, hoy identidad).
- En **Pascua** (referencia): el motor Kotlin ya recibe
  `setMedia(url, mimeType, drm, headers)` — el mismo contrato que devuelve un
  plugin. No necesita cambios.

### 4.4 Plugin — proyecto Kotlin independiente

Estructura mínima de un repo de plugin:

```
source-xyz/
├── build.gradle.kts        (target: d8 → plugin.dex)
├── src/main/kotlin/…        (implementación de IPlugin)
├── manifest.json             (id, nombre, versión, canales semilla)
└── plugin.dex                (artefacto compilado, subido a git)
```

---

## 5. Contrato del plugin (el corazón del diseño)

El contrato es lo único que la app "ve". Debe ser **diminuto, estable y
congelado**. La app nunca necesita saber cómo el plugin resuelve sus canales.

### 5.1 Interfaz (Kotlin, definida en el plugin)

```kotlin
interface IPlugin {
    fun manifest(): PluginManifest
    fun resolve(request: ResolveRequest): ResolveResult
}
```

### 5.2 Manifest (JSON)

```json
{
  "id": "source-xyz",
  "nombre": "Fuente XYZ",
  "version": "1.2.0",
  "minContrato": 1,
  "maxContrato": 1,
  "canales": [
    { "id": "c1", "nombre": "Canal 1", "logo": "https://…/logo.png",
      "categoria": "General", "pais": "AR" }
  ]
}
```

`minContrato` / `maxContrato` permiten que el plugin declare con qué versión
del contrato de la app es compatible (barrera de riesgo por versión).

### 5.3 ResolveResult (lo único que consume el motor)

```json
{
  "url": "https://…/master.mpd",
  "headers": { "User-Agent": "…", "Referer": "…" },
  "drm": { "tipo": "clearkey" | "widevine", "licenceUrl": "https://…" },
  "format": "hls" | "dash" | "mpegts" | "directo",
  "ttlMs": 3600000
}
```

- `ttlMs` opcional: cuánto vale la resolución; si el canal se reproduce y luego
  falla por "URL vieja", el host re-llama a `resolve()` antes de reintentar.
- El motor reproduce esto tal cual. No interpreta nada.

### 5.4 Reglas del contrato

- Los nombres de clases/métodos del contrato no cambian jamas (si cambian, es
  una **nueva versión de contrato**, y la app vieja muestra "incompatible").
- Todo el estado interno del plugin (tokens, sesiones, cachés) vive dentro de
  la instancia del plugin; la app no lo toca.
- `resolve()` debe ser síncrono desde el punto de vista del host: el plugin
  puede hacer sus propios `Thread`/HTTP, pero el host lo llama con timeout y
  corta si se excede.

---

## 6. Ciclo de vida de un plugin

| Evento | Qué pasa |
|---|---|
| **Publicar** | `./gradlew :plugin:dex` → `plugin.dex` + `manifest.json` → `git tag v1.2.0` → push |
| **Instalar** | Usuario pega URL (`https://raw.githubusercontent.com/…/v1.2.0/plugin.dex`) → app descarga manifest + dex → verifica hash → caché → aparece en UI |
| **Cargar** | Al uso: `DexClassLoader(dex, …, classLoader)` → reflexión → instancia `IPlugin` |
| **Usar** | UI muestra canales del manifest → al abrir uno, `resolve()` → motor reproduce |
| **Actualizar** | Host re-descarga desde el tag nuevo (mismo `id` → detecta versión) |
| **Quitar** | Host borra los archivos de `files/plugins/<id>/` y lo saca de la UI |

---

## 7. Detalles técnicos de `DexClassLoader`

### 7.1 Qué es

`DexClassLoader` es una clase estándar de Android que permite **cargar código
(bytecode Dalvik/ART) en runtime** desde una ruta de archivo, sin estar
compilado en el APK.

```kotlin
val loader = DexClassLoader(
    dexPath,           // ruta donde está plugin.dex
    optimizedDir,      // dir de ODEX (AppCompat debe permitir escritura)
    null,              // nativeLibDir
    parentClassLoader  // el de la app, para tener acceso a Kotlin runtime y Android
)
val clazz = loader.loadClass("com.sourcexyz.Plugin")
val plugin = clazz.getConstructor().newInstance() as IPlugin
```

### 7.2 Puntos clave

- **Sin recompilar la app**: el `.dex` es bytecode de máquina virtual,
  independiente de la arquitectura del CPU (no hay multi-ABI).
- **Dependencia del runtime construida en el APK**: el plugin solo usa APIs de
  Android y de Kotlin stdlib. Las librerías del plugin (okhttp, etc.) deben
  quedar **empaquetadas dentro del mismo `.dex`** (fat-dex) o el plugin debe
  limitarse a `HttpURLConnection`/`java.net`.
- **Limitación de hidden API (Android 7+)**: la reflexión solo puede tocar
  APIs públicas del SDK. Los plugins deben escribir código con APIs públicas.
- **Límite de 64K métodos**: si el plugin (con sus librerías) excede 64K
  métodos, se necesita multidex. Mejor: mantener el plugin liviano.
- **`optimizedDir`**: necesita un dirs con permisos de escritura del app
  (ej: `files/plugins/odex/`); usar `codeCacheDir` de la app.
- **Timeout**: el `resolve()` corre en un hilo; el host lo espera con timeout
  configurable (default sugerido: 15–20 s, como el resto de la app).

---

## 8. Seguridad y verificación

- **Siempre HTTPS** para descargar el artefacto (nunca HTTP plano).
- **Hash en el manifest**: la app descarga `manifest.json` + `plugin.dex`,
  calcula `SHA-256` del dex y compara con el campo `sha256` del manifest antes
  de cargarlo. Si no coincide → rechaza.
- **(Opcional) Firma**: manifest firmado / `update` exigiendo huella del repo
  para instalaciones de terceros.
- **Sandbox mínimo**: cada plugin tiene su propio `DexClassLoader`, pero corre
  en el mismo proceso → un plugin malicioso o roto **puede tumbar la app**.
  Mientras los plugins sean los nuestros (URLs que controlamos), el riesgo es
  el mismo que el de cualquier scraper que ya usa la app.
- No se usan permisos extra de Android que la app no tenga ya.

---

## 9. Distribución y versionado

### 9.1 Forma de la URL

- Git raw: `https://raw.githubusercontent.com/<user>/<repo>/<ref>/plugin.dex`
  con `<ref> = tag` (ej: `v1.2.0`) = versión inmutable.
- El `manifest.json` se sirve junto al dex en el mismo ref.
- La app guarda la **URL como clave** de la fuente. El `id` del manifest es la
  clave de identidad interna (para updates y para detectar fuentes duplicadas).

### 9.2 Caché local

```
files/plugins/<id>/
├── manifest.json
├── plugin.dex
└── odex/            ← optimizedDir del DexClassLoader
```

- La caché permite offline y arranque rápido sin re-descarga.
- Un "actualizar" re-descarga y reemplaza conservando el `id`.

### 9.3 Fuente del catálogo vs. lógica

- Los **canales pueden actualizarse sin recompilar**: si se quiere, el manifest
  puede apuntar a un JSON remoto de canales; pero en la v1 los canales viajan
  dentro del manifest del plugin.

---

## 10. Integración en moai3 (host) — costuras actuales

El host ya tiene los puntos de anclaje:

- `ChannelService` / `ChannelRepository`: son stubs (vacíos). Ahí "aterrizan"
  los canales aportados por los plugins instalados (una nueva implementación,
  por ej. `PluginChannelService`, que consolide los canales de todos los
  plugins instalados).
- `ChannelPlaybackHelpers.resolveStreamUrl()`: hoy es identidad. Ahí vive el
  `resolve()` de la app: si la URL viene de un canal-plugin, pregunta al
  `PluginHostService`.
- `MainActivity.kt` (Kotlin): ya registra `MethodChannel com.infomak.moai.tv/device`.
  Se agrega el channel `com.infomak.moai.tv/plugin` para host ↔ loader.
- El player (ExoPlayer vía `video_player`) reproduce el `ResolveResult` ya
  existente: URL + headers + hint de formato.

Pascua (referencia) no necesita host de plugins hoy: su motor ya acepta
`setMedia(url, mime, drm, headers)`; el `PluginLoader` Kotlin de moai3 es
portable a Pascua tal cual (mismo contrato).

---

## 11. Limitaciones y riesgos (explícitos)

1. **Prohibido por Google Play**: cargar y ejecutar código descargado en
   runtime viola la política de Play (sección "Code downloaded and executed").
   → Vale solo para apps **sideload / TV propias**.
2. **Fragilidad de contrato**: si el contrato cambia, los plugins viejos caen.
   → Contrato congelado + `minContrato/maxContrato`.
3. **Crash del proceso**: el plugin corre dentro del proceso de la app.
4. **Hidden API restrictions**: solo APIs públicas (Android 7+ con reflección).
5. **Necesidad de verificación**: sin hash, un repo comprometido = código
   ejecutado. Mitigación siempre-on (SHA-256).
6. **No se puede "cargar desde servidor remoto ajeno" gratis en Play**: la
   política no es técnica; la técnica sí permite.
7. **Multiplicidad de plugins decidiendo el mismo canal**: la app debe definir
   prioridad cuando dos plugins ofrecen el mismo canal (v1: primer instalado).

---

## 12. Comparación con alternativas descartadas

| Opción | Recompilar | Host servidor | Geo OK | Play | Veredicto |
|---|---|---|---|---|---|
| Resolver Dart embebido + plugins = datos | Sí (por lógica nueva) | No | Sí | No | sirve pero recompilás |
| Addon remoto (modelo Stremio) | No | **Sí** | Depende IP del host | Sí | no querés hostear |
| Nube serverless (Workers/Render/Oracle) | No | **Sí** | **Depende (IP datacenter)** | Sí | rechazado por geo/host |
| `.so` vía dlopen (NDK) | No | No | Sí | No | válido, pero requiere C/Rust |
| **`.dex` vía DexClassLoader (Kotlin)** | **No** | **No** | **Sí** | **No** | ✅ elegido |

---

## 13. Glosario

- **Host**: la app compilada (moai3/Pascua) + su capa Dart/Kotlin de plugins.
- **Plugin / fuente**: artefacto `.dex` + manifest en un repo git.
- **Contrato**: interfaz `IPlugin` + JSONs (`manifest`, `resolve`) que no cambia.
- **Resolver**: lógica interna del plugin que produce el `ResolveResult`.
- **Motor**: ExoPlayer (o el motor Kotlin de Pascua). Reproduce, no resuelve.
- **DexClassLoader**: cargador de bytecode Android en runtime.
- **Raw URL / tag**: esquema de distribución del artefacto en git.

---

## 14. Próximo paso

Este documento es el **paso 1 (diseño y cómo funciona)**.

El **paso 2** será el *plan de implementación* (documento aparte) con:
- tareas del host (Dart + Kotlin) en moai3,
- proyecto Gradle de ejemplo para fabricar el primer `.dex`,
- contrato exacto v1 (firmado en papel),
- prueba end-to-end (instalar por URL → ver canales → reproducir),
- iteraciones (updates, múltiples plugins, prioridades).