# SPEC-45: Buscador de películas

> **Estado**: Aprobada, en implementación (rama `cristal`)  
> **Área**: Features / Películas  
> **Archivos de Referencia** (previstos):  
> - `lib/features/home/areas/home_movies_area.dart` (pasa a 2 paneles)  
> - `lib/features/movies/widgets/movie_search_panel.dart` (nuevo)  
> - `lib/features/movies/controllers/movie_search_controller.dart` (nuevo)  
> - `lib/services/moiamov_api_service.dart` (`searchMovies`)  
> - `lib/services/movie_search_history.dart` (nuevo: últimas búsquedas)  
> - `lib/features/home/areas/home_calendar_area.dart` (modelo de 2 paneles)  
> - `lib/features/search/widgets/search_panel.dart` (modelo del campo + X)  
> - `lib/widgets/tv_input/tv_input.dart` (`TvTextField`)  

---

## 1. Propósito y alcance

Buscar cualquier película de la biblioteca de Moiamov desde la sección **Películas**, no sólo las del catálogo guardado.

**Por qué el servidor:** el catálogo guardado (`getNextColumns masnew_movies`, página 1) son **27 categorías × 10 películas = 270**. La página 2 viene vacía. La búsqueda del servidor recorre la biblioteca entera.

### Non-Goals
- Buscar series (Series está oculta en el rail).
- Ver cada categoría completa (más de 10): pendiente aparte, ver §8.
- Búsqueda por voz propia: alcanza con el micrófono del teclado del sistema.

---

## 2. Disposición: dos paneles

Películas usa el acordeón `TvAccordionRowPreview` con **2 paneles**, igual que Calendario:

| Índice | Panel | Contenido |
| :---: | :--- | :--- |
| 0 | **Películas** | La grilla actual (categorías, 5 columnas). Sin cambios. |
| 1 | **Buscar** | Campo + "X" y grilla de resultados. |

El panel abierto ocupa el ancho; el otro queda como columna angosta con su ícono.

### 2.1 Navegación
| Desde | Tecla | Va a |
| :--- | :--- | :--- |
| Última película de **cualquier** fila (panel 0) | → | Panel 1, foco en el campo |
| Campo de búsqueda | ← | Panel 0, a la última tarjeta enfocada |
| Primera columna de resultados | ← | Panel 0 |
| Campo | → | "X" (si hay texto) |
| Campo o "X" | ↓ | Primer resultado (o primera búsqueda reciente) |
| Primera fila de resultados | ↑ | Campo |
| Primera película de una fila (panel 0) | ← | Rail (como hoy) |

- Desde el rail, Películas **siempre abre en el panel 0** (no se recuerda el panel).
- Sólo `HomeSection.movies` tiene el panel Buscar; Destacados y Series (ocultos) siguen con un panel.

---

## 3. Panel Buscar

### 3.1 Encabezado
- `TvTextField` (`TvKeyboardType.search`) con ícono de teclado y "X" para borrar, como el buscador de canales.
- Al entrar al panel, el foco queda en el campo **sin abrir el teclado**. OK lo abre. El teclado del sistema trae micrófono (dictado).
- "X": borra el texto, vuelve a las búsquedas recientes y deja el foco en el campo.

### 3.2 Campo vacío: últimas búsquedas
- Hasta **10** búsquedas recientes (la más nueva primero) como pastillas **una al lado de la otra**; si no entran pasan a la fila siguiente (2026-10-30). Una muy larga se corta con "…". OK sobre una la vuelve a buscar.
- Al final, la pastilla **"Borrar búsquedas"** (ícono `delete`): vacía la lista y lo guardado, y el foco vuelve al campo.
- Flechas según dónde quedó cada pastilla (`FocusNode.rect`): ←/→ dentro de la fila (← al principio sale a la grilla); ↑/↓ a la más cercana en horizontal de la fila de arriba o de abajo; ↑ desde la primera fila vuelve al campo.
- Se guarda una búsqueda cuando se **abre una película** desde sus resultados (no en cada letra).
- Sin duplicados (sin importar tildes ni mayúsculas): repetir una la sube al principio.
- Se guardan en `SharedPreferences` (`movie_search_history`, lista JSON).
- Sin búsquedas guardadas: mensaje "Buscá por título, actor o director".

### 3.3 Resultados
- Misma tarjeta que la grilla (`TvMovieCard`, con la estrella de las buenas), grilla de 5 columnas: `MoviePosterGrid` (`lib/features/movies/widgets/movie_poster_grid.dart`, la misma de "Ver todas", SPEC-44 §3.3). Un solo foco para todos los resultados, alturas fijas y scroll calculado (antes un nodo por tarjeta y `ensureVisible`). ↑ desde la primera fila vuelve al campo; ← desde la primera columna sale a la grilla; una búsqueda nueva vuelve la selección al principio.
- OK → `MovieDetailScreen`. Al volver del detalle, el texto, los resultados, el scroll y el foco siguen como estaban.
- Mientras se busca: indicador de carga en el lugar de los resultados (los anteriores se reemplazan cuando llega la respuesta).
- Sin resultados: "No encontramos películas para «…»".

---

## 4. Búsqueda en el servidor

### 4.1 Cuándo se busca
- **Sólo con "Buscar" del teclado** (decisión del usuario 2026-10-30, reemplaza el debounce de 600 ms). Cerrar el teclado con atrás descarta lo escrito y no busca, como en el resto de la app. **No se busca mientras se escribe**: en el TV cada letra tarda 1–2 s con el control y el debounce dispararía una búsqueda por letra ("ba", "bat"…), con cientos de resultados basura (el servidor es laxo con poco texto) y resultados que cambian detrás del teclado, que igual tapa la pantalla. Con el micrófono el texto llega entero.
- Desde **2 caracteres**; menos muestra las recientes.
- `MovieSearchController.submit` no repite una búsqueda igual (sin importar tildes ni mayúsculas): se conservan resultados y scroll. Si la anterior cayó al catálogo guardado (§4.5), se reintenta con el servidor.
- Cada búsqueda nueva descarta la respuesta de la anterior si llega tarde (sólo cuenta la última).

### 4.2 Pedido
`POST /api/portalCore/v3/searchByName` (cifrado y headers como el resto del portal, `_postEncrypted`):

```json
{ "userToken", "userId", "portalCode",
  "columnId": "-1", "value": "<texto>", "type": "1",
  "pageSize": 20, "pageNum": 1, "filter": "" }
```

Respuesta (`data` cifrado):
```text
{ totalSize, searchItemList: [ { programType: "others", itemList: [ <asset> ... ] } ] }
```
Cada `<asset>` tiene el mismo formato que los del catálogo (`posterList`, `actorDisplay`, `director`, `score`, `alias`, `tags`, `programType`, `contentId`) más `releaseTime` (fecha de estreno). Se convierte con `MovieItem.fromJson`.

Comprobado en el emulador (2026-10-26):
- Funciona **sin VPN** con la sesión del arranque: 0,4–0,9 s.
- No le importan las tildes ("rapidos" = "rápidos"), tolera errores de tipeo ("terminatr" → Terminator) y busca por actor ("brad pitt").
- `type` no cambia los resultados.

### 4.3 Limpieza de resultados
1. **Sólo películas:** se descarta `programType != movie` (las series vienen como `teleplay`, "Batman T1", "T2"…) y los adelantos (`isTrailer`).
2. **Sin repetidos:** por `contentId`; y entre ítems distintos con el mismo título normalizado y el mismo año, queda el primero.
3. **Orden:** se respeta el del servidor, pero suben primero los que tienen **todas** las palabras buscadas en el título o el alias (normalizado sin tildes). Con varias palabras el servidor es laxo ("rey leon" → 1297 resultados con "Reyes", "Leone"…).

### 4.4 Paginado
- Cuando quedan **2 filas o menos** debajo de la elegida (o ↓ en la última) se pide la página siguiente (`pageNum + 1`) y se agrega abajo sin mover el foco; mientras baja, una fila de "cargando" al pie.
- Se deja de pedir cuando una página viene vacía o se alcanza `totalSize`.
- Como la limpieza puede dejar una página con pocas películas (p. ej. "batman" trae muchas series), si tras limpiar quedan **menos de 10** se pide automáticamente la siguiente (máximo 3 páginas por búsqueda en ese caso).

### 4.5 Si el servidor falla
Sin sesión, sin red, tiempo agotado (**8 s**) o `returnCode != 0`:
- Se busca en el catálogo guardado (las 270 de `FeaturedMoviesProvider`, sección Películas) por título, alias, actores y director, sin tildes, con las mismas reglas de orden.
- Arriba de los resultados, aviso: "Sin conexión con el servidor: resultados limitados".
- La búsqueda siguiente vuelve a intentar con el servidor.

---

## 5. Estado

`MovieSearchController` (ChangeNotifier, vive en `HomeMoviesAreaState`):
- `query`, `results`, `page`, `totalSize`, `isLoading`, `isLoadingMore`, `isOffline` (resultados locales), `history`.
- Se conserva mientras la sección está montada. Al salir de Películas desde el rail se descarta el texto y los resultados (la próxima vez abre en la grilla, §2.1); el historial queda guardado.
- (2026-10-30) Con el acordeón que conserva paneles (SPEC-33 §4.3), la grilla y Buscar quedan montados al alternar: ← desde Buscar vuelve a la misma película y al mismo scroll de la grilla sin re-armarla. La grilla usa un único foco (SPEC-44 §3).

---

## 6. Textos nuevos (`es.json`)

| Clave | Texto |
| :--- | :--- |
| `movies_panel_search_title` | Buscar |
| `movies_search_hint` | Buscar película, actor o director |
| `movies_search_recent` | Búsquedas recientes |
| `movies_search_empty_history` | Buscá por título, actor o director |
| `movies_search_no_results` | No encontramos películas para «{query}» |
| `movies_search_offline` | Sin conexión con el servidor: resultados limitados |

---

## 7. Criterios de aceptación

- → desde la última película de cualquier fila abre Buscar con el foco en el campo y **sin** teclado; ← vuelve a la grilla.
- Entrar a Películas desde el rail abre siempre la grilla.
- "brad pitt" muestra películas de Brad Pitt; "batman" no muestra series ("Batman T1"…); "toy story" no repite "Toy Story 4".
- "rey leon": El rey león, El rey león 2 y Mufasa aparecen antes que "Reyes T10".
- Bajar hasta la última fila carga más resultados sin mover el foco.
- Abrir una película y volver deja la búsqueda igual; la búsqueda queda en Recientes.
- Con el servidor caído, la búsqueda devuelve coincidencias de las 270 guardadas con el aviso.
- Tests: `movie_search_controller_test` (limpieza, `submit`, descarte de respuestas viejas, paginado, fallback, historial), `movie_search_panel_test` (navegación con el control, paginado, recientes).

---

## 8. Categorías completas (probado 2026-10-30)

Cada categoría del catálogo trae 10 películas. El listado completo sale de `POST /api/portalCore/v3/getShelveData`:

```json
{ "userToken", "userId", "portalCode",
  "columnId": 76275, "columnType": "2",
  "pageNum": 1, "pageSize": 30, "numDisplay": 30, "encryptVersion": 1 }
```

- **`columnType` es `"2"`** (con `"movie"`, `"1"`, `"vod"`… responde `rc=0` y 0 películas; vacío da "parámetros inválidos"). El `columnId` es el mismo de cada fila del catálogo.
- `data` viene cifrada como el resto. Trae `assetList`, `assetListTotalSize`, `version` y `freshTime` (600).
- Las páginas no se pisan; `pageSize` acepta al menos 100. Sólo `programType = movie`. Los ítems tienen los mismos campos que el catálogo **más `releaseTime`** (año de estreno). `score` puede ser `0` = sin puntaje.
- La página 1 empieza con las mismas 10 películas de la fila del catálogo, en el mismo orden.
- Totales (2026-10-30): All 31.419 · Prime 10.653 · Comedia 9.308 · Apple TV+ 7.327 · Suspenso 7.325 · Acción 5.942 · Romántico 4.469 · Horror 4.342 · Crimen 4.059 · Aventuras 4.048 · Misterio 2.741 · Familia 2.694 · Fantástico 2.511 · 2026 2.412 · Ciencia ficción 2.306 · Documental 1.820 · Biografía 1.468 · Historia 1.097 · HBO 603 · Hulu 362 · Occidental 346 · 2026 teatrales 235 · Paramount+ 207 · Tráiler 32 · Nativo 14. Las dos primeras filas (cambian seguido, p. ej. "Rompecabezas diplomático") tienen 10.
- Árbol: `v3/getColumnContents {columnId: 0, isAv1: "", specialFlag: "", …}` da el menú raíz (Movies = 76177, `masnew_movies`); sus hijas son las 27 filas, sin subcategorías. `getNextColumns` con el `code` de una fila viene vacío.
- La sesión obtenida con VPN en el arranque sirve también sin VPN.

El diseño de "Ver todas" y de la grilla sin repetidas va en su propia spec.
