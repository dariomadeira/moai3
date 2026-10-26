# SPEC-44: Biblioteca de películas (progreso, Seguir viendo, Interesantes) y reproducción

> **Estado**: Vigente (rama `cristal`)  
> **Área**: Features / Películas y series  
> **Archivos de Referencia**:  
> - `lib/services/movie_library.dart` (reglas entre progreso e Interesantes)  
> - `lib/services/movie_progress_service.dart`  
> - `lib/services/movie_watchlist_service.dart`  
> - `lib/features/movies/movie_playback.dart` (`playMovie`)  
> - `lib/features/movies/screens/movie_player_screen.dart`  
> - `lib/features/movies/widgets/movie_player_osd.dart`, `lib/features/movies/movie_player_format.dart`  
> - `lib/features/movies/titan_playback_bridge.dart`, `lib/services/titan_vod_preparer.dart`, `lib/services/titan_ranger_service.dart`  
> - `lib/engine/moai_engine_player.dart`, `android/.../PlayerEngine.kt`, `android/.../TsAudioSwapDataSource.kt`  
> - `lib/features/settings/widgets/settings_audio_language_row.dart`, `settings_subtitle_language_row.dart`  
> - `lib/services/new_release_ranker.dart`  
> - `lib/utils/image_decode.dart`  
> - `lib/services/moiamov_crypto.dart`, `lib/services/moiamov_catalog_store.dart`  

---

## 1. Estados de una película

```text
(nada) ──agregar──▶ Interesantes ──pasa 3 min──▶ Seguir viendo ──últimos 5 min / "Marcar como vista"──▶ Vista
```

Una película está en **un solo lugar**. `MovieLibrary` es la única puerta: el reproductor y el Inicio sólo llaman a sus operaciones.

### 1.1 Zonas de progreso (`MovieProgressService.saveProgress`)
| Zona | Posición | Qué se guarda |
|------|----------|---------------|
| 1 | < 3 min | Nada; se conserva lo anterior (si se reabrió y se salió enseguida, sigue el punto viejo; una vista sigue vista). |
| 2 | ≥ 3 min y antes de los últimos 5 | Punto para retomar, **con la película** (Seguir viendo la muestra sin esperar el catálogo). |
| 3 | últimos 5 min | Vista (sin la película). Se recuerdan las últimas `maxWatched = 300` vistas. |

### 1.2 Reglas de `MovieLibrary`
- `recordProgress`: guarda y, desde los 3 min (`startedAfter`), **quita de Interesantes**. Antes de los 3 min no la toca (una vista que se volvió a marcar como interesante sigue ahí aunque se abra un ratito).
- `markWatched(movies)`: vista aunque haya quedado a la mitad; sale de Seguir viendo y de Interesantes.
- `continueWatching({lookup})`: las empezadas, la última vista primero; progresos viejos sin película se buscan en el catálogo. También limpia de Interesantes las que quedaron en los dos lados.

## 2. Reproducción

- `playMovie(context, movie, {startAt, resolveStream})`: única forma de abrir el reproductor; los adelantos no guardan progreso.
- Reproductor: consulta el estado al motor cada 600 ms (`getStatus`) y sólo repinta la barra inferior (`ValueListenableBuilder` + `RepaintBoundary`). Rebuffer: corta a los 90 s.
- Búsqueda: ←/→ saltan 10 s; mantenidas aceleran (30 s, 1 min, 5 min); el destino se muestra antes de saltar.
- OSD de cristal siempre en tema oscuro (sobre el video).
- Buffer del motor: 40 MB (`setTargetBufferBytes`).

### 2.1 Titan Ranger
- `TitanVodPreparer`: SetEnv → SetEntries → PrepareProgram como la app oficial; devuelve la URL del proxy local (`127.0.0.1/vod/0/<media>.m3u8`).
- `TitanPlaybackBridge`: le avisa a Ranger posición, pausa, reanudación y saltos (`beforeSeek`) y **detiene el programa al salir** (`endProgram`, instancia 0). Antes los programas nunca se detenían.
- El detalle de la película precalienta Titan al abrirse.

### 2.2 Audio y subtítulos
- Ajustes globales "Idioma del audio" y "Subtítulos" (apagados o idioma), en vez de elegir en cada película.
- `TsAudioSwapDataSource` (Android): en los TS de Titan hay varios audios del mismo tipo y ExoPlayer toma el de PID más bajo; se intercambia paquete por paquete el PID del idioma pedido con el primero (y las etiquetas de la PMT, recalculando el CRC).
- Pendiente: distinguir las dos pistas "spa" (latino / España).

## 3. Catálogo y memoria

- Descifrado (3DES) y parseo del catálogo corren en **otro isolate** (`MoiamovCatalogStore.processDownload`, `load`). En el hilo principal congelaban la carga (≈100 ms en PC, segundos en el Chromecast). Dentro del isolate no hay `.env` ni traducciones: la clave se pasa como argumento y los textos con `CatalogStrings`.
- `MoiamovCrypto` (cifrado, md5, base64) y `MoiamovCatalogStore` (secciones, archivos, fecha) separados de `MoiamovApiService`.
- Imágenes: las fotos llegan hasta 4096 px. Se decodifican al tamaño en pantalla con `coverDecodeWidth` (`memCacheWidth`, considera hasta 2,4:1). `ResizeImage` nunca agranda.
- Grilla de Películas: filas perezosas, `ScrollCacheExtent` de 2,5 filas.
- Estrenos: `NewReleaseRanker` ordena con TMDb (calidad 45 %, novedad 35 %, popularidad 20 %, plus en cines) porque el catálogo no trae año.

## 4. Criterios de aceptación

- Empezar una película de Interesantes y pasar los 3 min la mueve a Seguir viendo.
- Mantener OK en Seguir viendo y confirmar la marca como vista y la saca de ambas listas.
- Al salir del reproductor, Ranger detiene el programa.
- La carga del catálogo no congela la animación de la pantalla de carga.
- Tests: `movie_library_test`, `movie_progress_service_test`, `movie_player_screen_test`, `titan_playback_bridge_test`, `moiamov_crypto_test`, `moiamov_catalog_parse_test`, `moiamov_quality_test`, `image_decode_test`, `new_release_ranker_test`, `featured_movies_trailers_test`.
