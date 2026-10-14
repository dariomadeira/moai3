# SPEC-11: Especificación de Canales de Plataforma (MethodChannels)

> **Estado**: Vigente (ampliado en `xumovies`, v3.0.36+)  
> **Área**: Plataforma / Interoperabilidad Flutter <-> Android  
> **Implementación Nativa**: `android/app/src/main/kotlin/com/infomak/moai/MainActivity.kt`, `games/ArcadeEmulatorManager.kt`

---

## 1. Resumen de Canales Registrados

| Nombre del Canal | Tipo | Propósito |
| :--- | :--- | :--- |
| `com.infomak.moai.tv/player` | `MethodChannel` | Control del ciclo de vida del reproductor ExoPlayer sobre Texture |
| `com.infomak.moai.tv/player/events/{handle}` | `EventChannel` | Emisión continua de eventos de reproducción y métricas de video |
| `com.infomak.moai.tv/plugin` | `MethodChannel` | Gestión del ciclo de vida y resolución de plugins `.dex` |
| `com.infomak.moai.tv/device` | `MethodChannel` | Hardware, emulador, mute de clicks UI D-Pad |
| `com.infomak.moai/arcade_channel` | `MethodChannel` | Emulador FBNeo/libretro, ROMs, gamepad, **netplay lockstep** |
| `com.infomak.moai.tv/remote_voice` | `MethodChannel` | PoC micrófono del control remoto (SPEC-34) |

---

## 2. Canal de Reproductor: `com.infomak.moai.tv/player`

### 2.1. Métodos Invocables

#### `create`
- **Argumentos**: Ninguno.
- **Respuesta**:
  ```dart
  Map<String, dynamic> {
    "handle": int,     // Identificador de instancia interna
    "textureId": int   // ID de SurfaceTexture registrado en Flutter Engine
  }
  ```

#### `prepare`
- **Argumentos**:
  ```dart
  Map<String, dynamic> {
    "handle": int,
    "url": String,
    "headers": Map<String, String>,
    "userAgent": String?,
    "mimeType": String?,
    "drmLicenseUri": String?,
    "drmScheme": String?, // "WIDEVINE" o "CLEARKEY"
    "title": String
  }
  ```
- **Respuesta**: `null` (la preparación inicia de forma asíncrona; el resultado se notifica vía `EventChannel`).

#### `play`, `pause`, `stop`, `release`
- **Argumentos**: `{"handle": int}`
- **Respuesta**: `null`.
- **Efecto de `release`**: Libera la instancia de ExoPlayer, desmonta el `SurfaceTexture` y cierra el `EventChannel` asociado.

---

## 3. Canal de Eventos: `com.infomak.moai.tv/player/events/{handle}`

Emite eventos de estado como mapas JSON:

```dart
// Cambio de estado
{"event": "state", "value": "idle" | "buffering" | "ready" | "ended"}

// Cambio de reproducción
{"event": "playing", "value": true | false}

// Primer cuadro renderizado
{"event": "firstFrame"}

// Dimensiones de video
{"event": "videoSize", "width": int, "height": int}

// Error en reproducción
{
  "event": "error",
  "code": int,
  "message": String,
  "errorClass": String
}
```

---

## 4. Canal de Plugins: `com.infomak.moai.tv/plugin`

### 4.1. Métodos Invocables

#### `list`
- **Argumentos**: Ninguno.
- **Respuesta**: `List<Map<String, dynamic>>` con la información de todas las fuentes instaladas (`PluginSource`).

#### `install`
- **Argumentos**: `{"url": String}` (URL al archivo `.dex` o `manifest.json`).
- **Respuesta**: `Map<String, dynamic>` con los metadatos de la fuente instalada.
- **Errores**:
  - `CONTRACT_MISMATCH`: Si `minContrato > 1` o `maxContrato < 1`.
  - `DOWNLOAD_ERROR`: Falla de red o hash inválido.
  - `CLASS_LOAD_ERROR`: No se pudo instanciar la clase `IPlugin`.

#### `update`
- **Argumentos**: `{"url": String}`
- **Respuesta**: `Map<String, dynamic>` con la nueva versión del plugin instalada.

#### `remove`
- **Argumentos**: `{"id": String}`
- **Respuesta**: `void`.

#### `resolve`
- **Argumentos**:
  ```dart
  {
    "pluginId": String,
    "channelId": String
  }
  ```
- **Respuesta**:
  ```dart
  Map<String, dynamic> {
    "url": String,
    "headers": Map<String, String>,
    "drmTipo": String?,
    "drmLicenceUrl": String?,
    "format": String,  // "hls" | "dash" | "directo"
    "ttlMs": int
  }
  ```

---

## 5. Canal de Dispositivo: `com.infomak.moai.tv/device`

#### `getTotalRamMb`
- **Respuesta**: `int` (Total de memoria RAM del dispositivo en Megabytes).

#### `isEmulator`
- **Respuesta**: `bool` (Heurística basada en `Build.FINGERPRINT`, `Build.MODEL` y `Build.HARDWARE`).

#### `setUiDpadSoundsEnabled` (xumovies)
- **Argumentos**: `{"enabled": bool}` — `false` silencia clicks UI (preferencia `ui_sounds_disabled`).
- **Respuesta**: `null` / éxito void.
- **Nativo**: `UiDpadSounds` (SoundPool). Ver [SPEC-41](../features/tv_focus_styles_and_dpad_audio.md).

---

## 6. Canal Arcade: `com.infomak.moai/arcade_channel` (xumovies)

Además de `initializeEmulator`, `loadRom`, `sendInputState`, `pause`/`resume`/`stop`, ROMs y gamepad:

| Método | Argumentos | Respuesta |
| :--- | :--- | :--- |
| `netplayEnable` | `enabled`, `delayFrames`, `isHost` | `true` |
| `netplaySubmitLocalInput` | `frame`, `mask` | `true` |
| `netplaySubmitRemoteInput` | `frame`, `mask` | `true` |
| `netplayGetFrame` | — | `int`/`long` |

Detalle de comportamiento: [SPEC-38](../features/arcade_netplay.md).
