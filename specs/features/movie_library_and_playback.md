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
> - `lib/services/movie_metadata_service.dart` (año de estreno vía TMDb)  
> - `lib/features/home/areas/home_movies_area.dart`, `lib/features/home/widgets/tv_movie_card.dart` (grilla)  
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
- Grilla de Películas (2026-10-30): **un único `FocusNode`** para toda la grilla (`movies_grid`). La película elegida es un índice (categoría, fila, columna) y las tarjetas (`TvMovieCard` con `isSelected`) sólo la dibujan; no tienen nodo propio ni manejan teclas. Encabezados (50 px) y filas (alto de tarjeta + 12) miden siempre lo mismo y se declaran con `itemExtentBuilder`, así el scroll a cualquier película se calcula (`_reveal`) en vez de buscar contextos en el árbol con `Scrollable.ensureVisible`. `ScrollCacheExtent` baja a 1 fila. Cada tarjeta va en `RepaintBoundary`: mover la selección repinta dos. Las repeticiones de ←/→ se ignoran; ↑/↓ con repetición sí avanzan.
- Puntaje en la tarjeta (2026-10-30, opción elegida por el usuario): las películas con puntaje **mayor a 7** (`MovieItem.isWellRated`, mismo umbral que el dorado del detalle) llevan una estrella dorada rellena (`MoaiFilledStar`, dibujada porque HugeIcons sólo trae la de contorno; 12 px de `MoaiIconSizes.xs`; `#FBBF24` en oscuro, `#B45309` en claro) a la derecha del título, dentro de la barra del título: el póster no se tapa y la tarjeta mide lo mismo. El resto no muestra puntaje en la grilla; `0` o vacío = sin puntaje. Vale también para los resultados de Buscar. Test: `tv_movie_card_test`.
- **Sin repetidas (2026-10-30, §3.2)**: el catálogo trae 10 por categoría y un tercio de los lugares eran películas repetidas en varias categorías. `MovieGridCatalog.build` (`lib/services/movie_grid_catalog.dart`, pura) recorre las categorías en orden (la fila de TMDb primero): cada una se queda con las que no aparecieron antes y completa hasta 10 con su lista del servidor (`MoiamovApiService.fetchShelf`, `getShelveData` con `columnType "2"`, páginas de 30, SPEC-45 §8). Si no llega, se recorta al múltiplo de 5 (filas completas); con menos de 5 queda como está; vacía se saca. El provider (`FeaturedMoviesProvider`) pide las listas a la par de TMDb, de a 6, y por vueltas pide la página siguiente (máx. 3) de las que siguen cortas; todo **antes** de mostrar la grilla (no cambia después) y con tope de 5 s (`shelfWait`): lo que no llegó se recorta. Las listas quedan en memoria por la sesión (un catálogo nuevo las descarta; los pedidos fallidos se reintentan en la próxima carga). Los adelantos y la lista plana se publican sin esperar a la grilla. Log: `Grilla sin repetidas: … repetidas que quedan: 0`. Probado con el servidor real: 27/27 categorías completas, 18 listas, unos 2,5 s después de TMDb (Películas se precarga al arrancar). Tests: `movie_grid_catalog_test`, `featured_movies_unique_grid_test`.
- **"Ver todas" (2026-10-30, §3.3)**: cada categoría del servidor (no la fila de TMDb) muestra 9 películas + la tarjeta `TvShowAllCard` como último casillero (mismo tamaño y marco que una película; en el lugar del póster el ícono `moviesShowAll` y "Ver todas", abajo el nombre de la categoría): siguen siendo 2 filas completas. Si la categoría queda corta se recorta a 4 + la tarjeta. Esas categorías no muestran el contador en la cabecera (no dice cuántas hay). OK en la tarjeta abre `MovieCategoryScreen` (`lib/features/movies/screens/movie_category_screen.dart`): la categoría completa, con Volver a la izquierda como el detalle, panel de cristal con el nombre y la misma grilla de 5 columnas (un solo foco, alturas fijas, scroll calculado). Arranca con lo que ya bajó la grilla (`FeaturedMoviesProvider.shelfSnapshot`) y pide de a 30 cuando quedan 2 filas o menos debajo de la elegida; mientras baja, una fila de "cargando" al pie; las páginas se suman abajo y el foco no se mueve. Sin películas: aviso de vacío o de error (OK reintenta: `TvEmptyStateCard` ahora responde al OK si tiene `onTap`). ← desde la primera columna va a Volver; OK abre el detalle; al volver, la grilla sigue en la misma tarjeta. Tests: `movie_category_screen_test`, `home_movies_area_test`.
- **Totales (2026-10-30)**: el catálogo no trae totales; salen de `getShelveData` (`assetListTotalSize`) pidiendo una sola película (`MoiamovApiService.fetchShelfTotal`). En "Ver todas" el título lleva "5.942 películas" (si no llega, sin número). En **Ajustes › Acerca de**, la fila "Películas disponibles" (sólo con Películas disponible) muestra el total de "Todos" ("All", toda la biblioteca: 31.419 el 2026-10-30); `FeaturedMoviesProvider.loadLibraryTotal` lo pide una vez por sesión al abrir el panel (si Películas está cargando, apenas termina) y toma el `columnId` de "Todos" del catálogo, no fijo. Miles con `MoaiFormats.thousands` (también lo usa `DiscountFormat.money`). Tests: `settings_about_movies_test`, `movie_category_screen_test`, `featured_movies_unique_grid_test`, `moai_formats_test`.
- **"Mejor puntuadas" (2026-10-30, §3.4)**: fila local (`MovieGridCatalog.topRated`, `columnId` 77777) después de "Estrenos de Cartelera" y antes de las del servidor: las películas del catálogo con puntaje mayor a 7, de mayor a menor (a igual puntaje, en el orden del catálogo). Pasa por el armado sin repetidas como las demás: muestra 10 (o recorta a filas completas), sin "Ver todas", y sus películas no se repiten abajo (las categorías que las pierden se completan con su lista del servidor). Tests: `movie_grid_catalog_test`, `featured_movies_unique_grid_test`.
- Al volver a la grilla (desde Buscar o desde el rail) se conserva la selección y el scroll (`_savedOffset`); si la lista se desarmó, un `ScrollController` nuevo arranca en esa posición.
- Estrenos: `NewReleaseRanker` ordena con TMDb (calidad 45 %, novedad 35 %, popularidad 20 %, plus en cines) porque el catálogo no trae año.

### 3.1 Año de estreno (2026-10-30)
- `MovieItem.year` ya **no** sale de `shelveTime` (fecha en que se subió al catálogo, daba años falsos como "2025" para *Rocky*). Viene de `year`, `releaseYear` o `releaseTime`. `formattedYear` devuelve sólo un año válido (19xx/20xx) o `null`.
- El detalle muestra el año del catálogo si lo hay; si no, lo pide a `MovieMetadataService.resolveYear` (`lib/services/movie_metadata_service.dart`): TMDb `/search/movie` por nombre y alias (es-MX), prefiere coincidencia exacta de título y luego popularidad. Caché en memoria y en `SharedPreferences` (`tmdb_year_<contentId>`). `MovieDetailScreen.resolveYear` permite reemplazarlo en tests.
- Sólo se guarda lo que TMDb contestó: el año, o `-` si no hubo coincidencia. Un error de red, un timeout, un estado distinto de 200 o la falta de clave no se guardan, y la próxima vez se vuelve a consultar. Un vacío (`''`) guardado por la versión anterior se ignora. Dos pedidos seguidos de la misma película comparten la consulta.
- `MovieItem.toJson` guarda sólo el año (4 dígitos). Al leer, un `year` con forma de fecha completa ("2025-08-10") es la fecha de subida que guardaban las versiones anteriores en Interesantes/Seguir viendo: se descarta y el detalle busca el año real.

## 4. Criterios de aceptación

- Empezar una película de Interesantes y pasar los 3 min la mueve a Seguir viendo.
- Mantener OK en Seguir viendo y confirmar la marca como vista y la saca de ambas listas.
- Al salir del reproductor, Ranger detiene el programa.
- La carga del catálogo no congela la animación de la pantalla de carga.
- Tests: `movie_library_test`, `movie_progress_service_test`, `movie_player_screen_test`, `titan_playback_bridge_test`, `moiamov_crypto_test`, `moiamov_catalog_parse_test`, `moiamov_quality_test`, `image_decode_test`, `new_release_ranker_test`, `featured_movies_trailers_test`, `movie_metadata_service_test`, `home_movies_area_test`, `movie_detail_screen_test`.
