# Plan de implementación — Paso 2

> Se complementa con `Plugins_Resolucion_Runtime_Dex.md` (paso 1: diseño).
> Estado: **Fase 3 completada** (host de plugins por URL; Fase 4 − primer dex − pendiente).
> Objetivo: dejar moai3 como un host mínimo con un motor único en Kotlin,
> listo para recibir un `.dex` por URL y reproducir su canal.

---

## 0. Decisiones previas (a confirmar antes de codear)

| # | Decisión | Opción |
|---|---|---|
| D1 | Motor único | **Kotlin propio (puerto generalizado del motor de Pascua) — confirmado y en producción**: reemplaza a `video_player` en moai3 |
| D2 | Contrato v1 | El definido en el paso 1 (sección 5); se cierra por escrito antes de programar |
| D3 | Separación | El motor **solo reproduce**; el plugin (dex) **solo resuelve** |
| D4 | Primer canal del demo | Lo indica el usuario (pendiente) |
| D5 | Dónde vive el host | moai3 (Android, sideload) |
| D6 | Repo del plugin | Repositorio git propio, artefacto `.dex` + `manifest.json` por tag |

---

## Fase 1 — Limpieza de moai3 (moai mínimo)

**Objetivo:** quedar con un cascarón que arranca, navega y solo espera un motor
y un host de plugins. Fuera todo lo que no se reutiliza.

Tareas:
1. Auditar `lib/` y listar:
   - **Se queda**: estado (`AppState`), modelo `Channel`/`ChannelGroup`, tema
     (Material 3 / dynamic color), navegación (go_router), logs
     (`DebugLogController`), persistencia (`AppPreferences`), overlay del
     reproductor (posicionamiento 16:9).
   - **Se elimina**: `video_player` (reemplazado por el motor propio),
     `wakelock_plus` si pasa al motor, focus system (`lib/focus/`) si deja de
     usarse el flujo D-pad, `overlap_config`, panels/settings muertos,
     `PlaybackStatsController` legacy si queda obsoleto, `device_memory`
     solo si no se usa (se conserva mientras el motor no lo cubra).
2. Borrar de `pubspec.yaml` las dependencias sin uso.
3. Tras el borrado: `flutter analyze` 0 issues y que la app compile.
4. (Criterio) El `.apk` resultante debe ser visiblemente más chico y arrancar
   en `/home` sin errores, aunque aún no reproduzca.

**Entregable:** moai3 "hueso", compilando, sin deuda visual.

---

## Fase 2 — Motor único en Kotlin (reemplaza a video_player)

**Objetivo:** un solo motor de reproducción en el APK, al estilo del de Pascua,
pero generalizado. Solo reproduce lo que le dan.

Tareas:
1. Portar/generalizar el engine Kotlin de Pascua a moai3:
   - `MethodChannel "com.infomak.moai.tv/player"` (control):
     `create → textureId`, `setMedia(url, mimeType, drm, headers)`,
     `play`, `pause`, `seekTo`, `setVolume`, `dispose`.
   - `EventChannel "com.infomak.moai.tv/player/events/<id>"`:
     eventos `videoPlaying`, `firstFrame`, `bufferingStart/End`, `error`
     (con `code`/`class`/`message` accionables), `videoSize`.
   - Soporte de formatos: HLS, DASH, MPEG-TS HTTP; heads custom; DRM
     ClearKey y Widevine (con `setLicenseRequestHeaders`).
   - Watchdog anti-buffer infinito (el de Pascua, 45 s → error accionable).
   - Buffer inicial razonable (`setDefaultBufferSize`).
2. Widget host en Flutter: `EnginePlayerView` renderizando sobre `Texture`,
   igual que el `PascuaPlayer` existente (referencia en `/home/apogeo/pascua`).
3. Reescribir `TvViewer` para usar `EnginePlayerView` en lugar de
   `VideoPlayerController`:
   - Conserva sesión/reintentos (`ReconnectionCoordinator`,
     `PlaybackSessionGuard`) ahora para `resolve()` + `setMedia`.
   - El watchdog nativo reemplaza al timer Dart de 15 s.
4. Punto de integración de resolución:
   - `ChannelPlaybackHelpers.resolveStreamUrl()` pasa a preguntar al
     `PluginHostService` (Fase 3); mientras tanto devolver la URL directa
     para probar el motor con una URL de prueba.
5. Criterio: reproducir DASH/HLS directo y un caso con headers desde la fase
   2, sin plugins todavía.

**Entregable:** moai3 reproduce con su motor Kotlin propio.

---

## Fase 3 — Capa de host de plugins (Dart + Kotlin)

**Objetivo:** darle a moai3 la capacidad de instalar `.dex` por URL y exponer
sus canales.

Tareas:
1. `PluginLoader` (Kotlin, dentro del APK):
   - Descarga `manifest.json` + `plugin.dex` con HTTPS.
   - Verifica `sha256` del dex contra el manifest (siempre).
   - Caché en `files/plugins/<id>/` (+ `odex/` dir para `DexClassLoader`).
   - `DexClassLoader` + reflexión → instancia `IPlugin`.
   - `resolve()` en hilo hijo con timeout (15–20 s).
2. `PluginHostService` (Dart):
   - `MethodChannel "com.infomak.moai.tv/plugin"`:
     `install(url)`, `list()`, `resolve(pluginId, channelId)`,
     `update(url)`, `remove(url)`.
   - Modelo `PluginEntry` (id, nombre, versión, canales) para la UI.
3. `ChannelService`/`ChannelRepository`: nueva implementación que consolida
   los canales de los plugins instalados (sin red, como hoy: el catálogo lo
   aportan los plugins).
4. UI mínima:
   - Pantalla "Fuentes" para pegar una URL y ver estado (instalar/update/remove).
   - Los canales del plugin aparecen en el navegador de canales existente.
5. Contrato v1 congelado en documento aparte (`Contrato_Plugin_v1.md`).
6. Criterio: pegar una URL de prueba, ver el canal en la lista.

**Entregable:** moai3 instala fuentes por URL y muestra sus canales.

---

## Fase 4 — Primer plugin `.dex` (un canal) en git

**Objetivo:** probar el b) end-to-end: URL de git → canal → reproducción.

Tareas:
1. Crear proyecto Gradle mínimo (Kotlin) para fabricar un `.dex`:
   - Implementa `IPlugin` (contrato v1) para **un canal** (pendiente D4).
   - Compila con `d8` → `plugin.dex` + genera `manifest.json` (con `sha256`).
   - Mantener el dex liviano (bajo 64K métodos; sin librerías pesadas).
2. Publicar en un repositorio git propio:
   - `plugin.dex`, `manifest.json`, `build.gradle.kts`, README.
   - Tag por versión (ej: `v1.0.0`).
3. Prueba end-to-end en moai3:
   - Pegar `https://raw.githubusercontent.com/<repo>/v1.0.0/plugin.dex` (o el
     manifest) → aparece el canal → abrir → `resolve()` → motor reproduce.
   - Verificar log de sesión (debug) y estados accionables ante fallo.
4. Criterio de aceptación:
   - Sin recompilar el APK: instalar, reproducir, actualizar a `v1.0.1` y
     que el cambio se refleje re-descargando el tag.

**Entregable:** el flujo completo funcionando del paso 1.

---

## Checklist fuera del alcance (no-goals en esta iteración)

- iOS / web / desktop (Android only).
- Google Play (solo sideload/TV).
- Varios plugins con prioridad de canales (v1: primer instalado gana).
- DRM complejo multi-sesión (el motor soporta ClearKey/Widevine simple).
- Publicar en pub.dev.

## Entregables documentados resultantes

1. `Plugins_Resolucion_Runtime_Dex.md` — (paso 1, ya existe).
2. **`Plan_Implementacion_Moai3_Motor_Plugins.md`** — este documento.
3. `Contrato_Plugin_v1.md` — la interfaz y JSONs congelados (se crea al cerrar
   el contrato, antes de la Fase 4).
4. `Plan_Moai3_Limpieza.md` — resultado de la auditoría de la Fase 1 (qué se
   elimina y por qué).

## Secuencia y verificación

```
Fase 1 (limpieza) ─▶ Fase 2 (motor) ─▶ Fase 3 (host plugins) ─▶ Fase 4 (primer dex)
     analyze 0            reproduce            instala por URL          reproducción e2e
```

Cada fase termina con su criterio de aceptación cumplido y `flutter analyze`
sin issues. Nada de la Fase siguiente empieza si la anterior no pasa.

---

## Fases terminadas

- [x] Fase 1 (limpieza) — completada y verificada (analyze 0, 46/46 tests, APK debug OK). Ver `Plan_Moai3_Limpieza.md`.
- [x] Fase 2 (motor único) — completada y verificada (analyze 0, 46/46 tests, APK debug OK):
      canales `com.infomak.moai.tv/player` + `/player/events/<id>`, render por `Texture`,
      keep-screen-on nativo, watchdog 45 s → error `-30 BufferingTimeout`, reemplazo total
      de `video_player`/`wakelock_plus`.
- [x] Fase 3 (host de plugins) — completada y verificada (analyze 0, 46/46 tests, APK debug OK):
      `PluginLoader` Kotlin (descarga HTTPS, **sha256 siempre-on**, caché `files/plugins/<id>/`,
      `DexClassLoader` + reflexión, `resolve()` en hilo con timeout 20 s), canal
      `com.infomak.moai.tv/plugin` (`install/update/list/remove/resolve`), `PluginHostService` Dart,
      catálogo consolidado en `ChannelRepository`, playback por `resolvePlayback()`,
      pantalla **Fuentes** (Ajustes → Generales) para pegar URL y ver estado.
      Contrato congelado: `Contrato_Plugin_v1.md`.

## Pendientes para la Fase 4

- [ ] D4: el **canal concreto** del primer plugin (lo indica el usuario).
- [ ] Crear el repo git para el plugin (nombre y cuenta a definir).
- [ ] Fabricar el `.dex` (proyecto Gradle + `d8`) y publicarlo por tag.
- [ ] Prueba end-to-end: pegar URL → ver canal → reproducir → update a `v1.0.1`.