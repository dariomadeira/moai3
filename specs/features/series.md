# SPEC-46: Series (detalle, reproducción, vistos, Seguir series y Marcadas)

> **Estado**: Vigente (rama `cristal`, 2026-11-11)  
> **Área**: Features / Películas y series  
> **Archivos de Referencia**:  
> - `lib/features/movies/screens/series_detail_screen.dart` (detalle)  
> - `lib/models/series_models.dart` (`SeriesSeason`, `SeriesEpisode`, `SeriesSeasonDetail`)  
> - `lib/features/movies/series_playlist.dart` (`SeriesPlaylist`, `episodeItem`)  
> - `lib/features/movies/movie_playback.dart` (`playEpisode`, `askResume`)  
> - `lib/features/movies/screens/movie_player_screen.dart` (reproductor compartido con películas, SPEC-44)  
> - `lib/services/moiamov/moiamov_playback.dart` (`resolveEpisodeStream`), `moiamov_catalog.dart` (`fetchSeriesSeason`)  
> - `lib/services/series_watch_service.dart` (vistos y dónde retomar)  
> - `lib/services/series_continue_service.dart` ("Seguir series")  
> - `lib/services/series_watchlist_service.dart` ("Marcadas" de series)  
> - `lib/features/home/areas/home_dashboard_series.dart`, `lib/features/home/widgets/home_series_continue_card.dart`, `home_series_watchlist_card.dart` (Inicio, SPEC-42)  
> - `lib/focus/opening_focus_guard.dart` (foco al abrir, SPEC-30)  
> - `lib/features/movies/movie_promo.dart` (`pickPromoSeries`, `pickBestSeries`), `lib/features/movies/widgets/movie_hero_card.dart` (tarjeta grande)  
> - Recomendar series a los amigos: SPEC-51 §7.  

---

## 1. Propósito y alcance

Las series del catálogo (sección **Series** del rail, mismo sistema que Películas: grilla sin repetidas, "Ver todas" y buscador, SPEC-44/45) se pueden abrir, reproducir capítulo por capítulo, marcar como vistas, retomar desde el Inicio y guardar para después.

### Non-Goals
- Títulos o imágenes por capítulo: el portal no los trae (sólo número y, a veces, duración).

---

## 2. Datos del portal

- Cada **temporada es un ítem propio** del catálogo ("Serie T2"). `v4/getItemData` con `type="0"`, `sortType="0"` (`fetchSeriesSeason`) devuelve la ficha, `sameSeasonSeriesList` (todas las temporadas: `contentId` + `seasonNumber`) y `simpleProgramList` (capítulos: `contentId`, `seriesNumber`). También `audioInfo` ("por,eng,spa") y `subsInfo` ("pt,es,en") de la temporada.
- **Capítulos por salir** (visto 2026-11-11 con VisionQuest T1): `volumnCount` es cuántos capítulos **va a tener** la temporada ("8") y `updateCount` cuántos están subidos ("7"); se lee `volumnCount` (`SeriesSeasonDetail.plannedEpisodes`). `keyWords` trae el id de IMDb de la serie ("tt23112594", `SeriesSeasonDetail.imdbId`): **el mismo en todas las temporadas** (Derrota a Bobby Flay T7–T17: `tt3205302`), y **sólo en el detalle**: el catálogo (`getShelveData`) y la búsqueda no lo traen, así que no sirve para agrupar temporadas ni para cruzar con TMDb las filas de Películas. Las series del catálogo sí traen `volumnCount` y `updateCount`. Los capítulos traen `name` ("VisionQuest T1_1"), `quality` y `posterList` vacío: sin títulos ni imágenes reales. No hay ningún dato de temporadas por venir: la lista trae sólo las subidas.
- **Temporadas repetidas**: el portal puede listar dos versiones del mismo número (Bob's Burgers: la oficial "Bob's Burgers T1", con tres idiomas y 1080p, y una carga paralela "Bobs Burgers 1", grabada de la TV, audio "und", sin subtítulos, 480p). El detalle pide la ficha de **todas** las versiones repetidas y muestra una por número: la más completa (`SeriesSeasonDetail.completeness` = idiomas de audio + subtítulos + sinopsis; `bestSeasons`). Mientras no se conocen, la primera. Si la abierta es la descartada, pasa a la elegida conservando el capítulo.
- **Pedir un capítulo** (`resolveEpisodeStream`, probado en el TV): `v10/startPlayVOD` con el `contentId` del **capítulo** y `seriesContentId` = el de su **temporada**, `type "1"`. Sólo el capítulo da "参数异常"; la temporada da "节目不存在". Si la respuesta trae otro `programContentId`, se descarta. El resto (calidad, audio, Titan Ranger) es igual que en películas.

## 3. Detalle (`SeriesDetailScreen`)

- Ficha como la de una película (título sin "T2", puntaje, año, "N temporadas" sólo con más de una, "N capítulos", géneros, director, elenco, sinopsis).
- **Temporadas**: fila de números ("1", "2"…), una por número. Se muestra **aun con una sola** (para poder marcarla entera); si el portal no lista temporadas, la abierta. ←/→ cambian de temporada (se pide 300 ms después de parar). La elegida va sólida en el acento sin foco y con el borde del foco con él.
- **Capítulos**: fila de cuadrados con el número; puntos de página abajo (sin flechas). Al abrir desde "Seguir series" queda elegido el capítulo pedido (`initialEpisodeId` / `initialEpisodeNumber`).
- **Foco al abrir**: en los capítulos hasta la primera tecla (`OpeningFocusGuard`, SPEC-30 §2.1.2). En el TV la pantalla le daba el foco a su grupo al terminar de abrirse y la primera tecla se iba a Atrás.
- **Navegación**: ↑ desde capítulos → temporadas → **Marcar**; desde Marcar ← y ↑ van a Atrás, → a 👍 y 👎 (con amigos), ↓ a temporadas. ← desde la primera temporada o el primer capítulo va a Atrás.
- **Marcar / Desmarcar** (abajo a la derecha, como en películas): la serie va a "Marcadas" (§7).
- **👍 / 👎**: recomendar a los amigos (SPEC-51 §7).

### 3.1 OK en una fila
- OK corto actúa **al soltar**; el KeyUp sin KeyDown previo (el del OK que abrió el detalle) se ignora.
- OK en un capítulo: si quedó a la mitad pregunta "¿Cómo querés verla? Te quedaste en 12:30" (Desde el principio / Reanudar, `askResume`, el mismo cartel de películas); mientras se pide el video el número se cambia por una ruedita gris; después reproduce (§4).
- OK en una temporada: baja a los capítulos.
- **Mantener OK** (`TvTiming.longPress`, 800 ms): en un capítulo alterna su marca de visto; en una temporada marca todos sus capítulos o, si ya estaban todos, se las saca. No reproduce.

## 4. Reproducción

- `playEpisode(context, SeriesPlaylist, {startAt})` usa `playMovie` y el reproductor de películas con `series:`. Termina cuando se cierra el **último** reproductor de la serie (`SeriesPlaylist.done`).
- Título: "Serie · T2 · Capítulo 5" (`episodeItem`).
- **Siguiente automático**: al terminar un capítulo (motor `ended`) el reproductor muestra "Siguiente: Capítulo 6" (o "Siguiente: Temporada 3 · Capítulo 1") y se reemplaza por el del siguiente (`Navigator.pushReplacement`). Al final de una temporada sigue con el capítulo 1 de la próxima (la pide si no estaba). Después del último de la serie vuelve al detalle, con el último visto elegido. Si el siguiente no carga: aviso y vuelve.
- **Titan Ranger**: el capítulo que termina cierra Ranger (`TitanPlaybackBridge.close`, una sola vez) **antes** de pedir el siguiente: su "end" va a la instancia 0 y, si llegaba después, cortaba el capítulo nuevo ("Source error").
- Audio y subtítulos: como películas (ajustes globales; píldoras sólo si hay más de una opción). El audio elegido a mano vale para **toda la serie** (`SeriesPlaylist.audioKey`).
- Sin cartel de recomendar en cada capítulo: sólo al final de cada temporada (SPEC-51 §7).
- Atrás: lo maneja el pop del sistema (SPEC-30 §2.3).

## 5. Vistos (`SeriesWatchService`)

| Posición | Qué se guarda |
|------|---------------|
| < 3 min | Nada |
| ≥ 3 min, antes de los últimos 3 | Dónde retomar (`series_resume_<capítulo>`) |
| Últimos **3 min** (películas: 5) | Visto: entra al conjunto de la temporada (`series_season_<temporada>`: vistos + cantidad de capítulos); se borra el punto de retomar |

- La temporada está **completa** con todos sus capítulos vistos; la cantidad se anota al cargarla (`rememberEpisodeCount`), así se sabe aunque no esté abierta.
- `setWatched` marca o desmarca a mano (marcar borra el punto de retomar). `clearAll` borra todo (Ajustes, §8).
- Guardado aparte del de películas: el tope de 300 vistas de películas no alcanza (One Piece tiene 1180 capítulos).
- **Cómo se ve lo visto** (decisión del usuario, se descartaron el check y el fondo verde): el recuadro pasa a **píldora** (radio = alto/2) y el número va **4 pt más grande, w900 y verde** (`MoaiPalette.watched`: #15803D en claro, #4ADE80 en oscuro). Sobre la temporada sólida en el acento, el número va en `onPrimary`.
- Cada cambio avisa por `SeriesContinueService.changes` para que el Inicio relea "Seguir series".

## 6. "Seguir series" (`SeriesContinueService`)

- Una entrada por serie (`seriesKey` = `series:<contentId de la primera temporada>`), la más reciente primero, hasta 30. Guarda título, imagen, temporadas, el último capítulo visto (`current`) y el siguiente (`next`), en `series_continue_v1`.
- Se anota cuando el reproductor guarda pasados los 3 min (`SeriesPlaylist.record`) y al **marcar a mano** como visto (capítulo: el más avanzado de los vistos de esa temporada; temporada entera: su último capítulo). Desmarcar no anota.
- `items()`: si el último quedó a la mitad, ese capítulo con su barra ("T2 · Cap. 5"); si se terminó o se marcó, el siguiente ("Sigue: T2 · Cap. 6"). Visto el último de la serie: sale y se olvida, **salvo** que la temporada tenga capítulos por salir (§6.1).
- Tarjeta del Inicio (SPEC-42): OK abre el **detalle** en esa temporada con el foco en ese capítulo (no reproduce directo); mantener OK la quita (lo visto queda); "Quitar todas".
- Anotarse en Seguir series saca a la serie de "Marcadas" (como películas: Interesantes → Seguir viendo).
- Lo visto antes de 2026-11-11 no aparece hasta ver otro capítulo (antes no se guardaba de qué serie era cada capítulo).

### 6.1 Capítulos y temporadas nuevas (2026-11-11, `SeriesNews`)

- **Al día sin terminar**: si se vio el último capítulo subido y la temporada tiene más por salir (`plannedEpisodes` > el último visto; "7 de 8"), la entrada queda guardada (`awaiting`) pero **no se muestra**. Se espera hasta 180 días desde el último visto; después se olvida.
- **Revisión**: una vez por día (`series_news_checked_at`), cuando el Inicio tiene Series cargado (ya hay sesión), se pide la temporada de cada serie que espera (un `getItemData` por serie). Si nadie contesta (sin sesión), se vuelve a probar en el próximo arranque.
- **Si apareció algo**, vuelve a "Seguir series", **primera**, con el capítulo listo:
  - el que sigue al último visto: **"Capítulo nuevo · T1 · Cap. 8"**;
  - si no, una temporada nueva en la misma respuesta (`sameSeasonSeriesList`): su capítulo 1, **"Temporada nueva · T2"**.
  - Al ver ese capítulo la entrada se reescribe y la etiqueta se va.
- **Quitada a mano** (OK mantenido, "Quitar todas", "Borrar series vistas"): no vuelve (decisión del usuario).
- **Temporadas nuevas (TMDb)**: vista toda la serie subida (última temporada completa), la entrada guarda el id de IMDb y espera (`awaitingSeason`). La revisión le pregunta a TMDb (`TmdbSeriesService`: `/find/{imdb}?external_source=imdb_id` y `/tv/{id}`, dos pedidos; se repite cada 30 días):
  - **terminada o cancelada** y sin más temporadas que la vista: se olvida;
  - **sigue** (en emisión, en producción, planeada) o tiene más temporadas que la vista: espera hasta **2 años**. Si TMDb anunció la próxima temporada (`next_episode_to_air`), no se le pregunta al portal antes de esa fecha (`seasonAirsAt`);
  - TMDb no contesta o no la conoce: se le pregunta al portal una vez por día, como máximo 180 días.
  - Cuando el portal la sube, vuelve con "Temporada nueva · T2".
- **Rescate** (una vez, `series_news_rescued_v2`): las series que ya se habían olvidado por estar al día se buscan por las temporadas con todo visto (`SeriesWatchService.completedSeasonIds`, hasta 25) que no están en la lista; si la temporada es la última de la serie y le faltan capítulos o tiene id de IMDb, la serie entra esperando (TMDb decide después).
- Tests: `series_news_test`.

## 7. "Marcadas" de series (`SeriesWatchlistService`)

- La marca es de la **serie**, no de la temporada: guarda la serie (como `MovieItem` de la primera temporada, con el nombre sin "T2") y **todos** los `contentId` de sus temporadas, así se reconoce se entre por la que se entre (también con temporadas repetidas). Clave `series_watchlist`, la última marcada primero.
- Tarjeta del Inicio "Marcadas" de series (cian, SPEC-42): OK abre el detalle; mantener OK pregunta y la desmarca; "Desmarcar todas".
- Al empezarla (anotada en Seguir series) sale de Marcadas.

## 7.1 Tarjeta grande de series (2026-11-11)

- **Qué series**: sólo las mejores del **catálogo** (decisión del usuario: sin las recomendaciones de los amigos), igual que el banner de Películas. `pickPromoSeries` (`lib/features/movies/movie_promo.dart`): una por serie (de cada serie, la temporada de mejor puntaje), con el nombre sin "T2", primero las de este año o del anterior con puntaje mayor a 7 y después las mejor puntuadas de cualquier año; hasta 6 y sólo con imagen horizontal.
- **Arriba de Series** (`HomeMoviesArea(promoBanner: true)`, como Películas): `MovieHeroCard` con **"Ver serie"** (abre el detalle: desde acá no se sabe qué capítulo), **Marcar** (series marcadas) y sin "…" (`playLabel`, `showMore: false`). Debajo, **"Lo mejor del 2026"** de series (`pickBestSeries`, del catálogo porque TMDb no tiene series): una por serie, las recientes mejor puntuadas primero, sin las del banner. Sin esa fila el banner ocupaba toda la pantalla.
- **En el Inicio**, a la derecha de la película destacada (SPEC-42 §3.0).
- Las dos arrancan con la misma serie: la que eligió el Inicio (`HomeHeroRotation.series`, SPEC-42 §3.0).

## 8. Ajustes

En **Ajustes › Películas y series** (SPEC-39 §2): **Borrar series vistas** (ícono `HugeIcons.bodySoap`; confirmación Cancelar / Borrar) borra vistos, puntos de retomar y "Seguir series". No toca Marcadas.

En **Ajustes › Acerca de**, "Temporadas disponibles": el total de la categoría "Todos" del catálogo de Series (`FeaturedMoviesProvider.libraryTotalFor(sectionSeries)`). Cuenta **temporadas**, no series: cada temporada es un ítem del portal, y contar series exigiría bajar y agrupar todo el catálogo. Usa el ícono de Series del rail (`TvTile.svgIcon`). Sin "Todos" en el catálogo, no hay fila.

## 9. Criterios de aceptación

- Bob's Burgers muestra una sola temporada 1 y una sola 2 (las oficiales, con tres idiomas).
- OK en un capítulo lo reproduce; al terminar pasa solo al siguiente y, al fin de temporada, al primero de la próxima, sin "Source error".
- A 3 min del final el capítulo queda visto (número verde en píldora); con todos vistos, la temporada también.
- La primera flecha al abrir el detalle mueve dentro de los capítulos, no a Atrás.
- Una sola "atrás" desde el reproductor vuelve al detalle.
- Marcar un capítulo pone la serie en "Seguir series" con el siguiente; OK en la tarjeta abre el detalle en ese capítulo.
- Tests: `series_detail_screen_test`, `series_playlist_test`, `series_watch_service_test`, `series_continue_service_test`, `series_watchlist_service_test`, `movie_player_screen_test` (capítulos de una serie, atrás en el TV), `goldens/theme_golden_test` (`serie_detalle`).
