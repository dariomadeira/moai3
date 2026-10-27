# SPEC-45: Buscador de películas

> **Estado**: Aprobada, sin implementar (rama `cristal`)  
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
- Lista de hasta **10** búsquedas recientes (la más nueva primero). OK sobre una la vuelve a buscar.
- Se guarda una búsqueda cuando se **abre una película** desde sus resultados (no en cada letra).
- Sin duplicados (sin importar tildes ni mayúsculas): repetir una la sube al principio.
- Se guardan en `SharedPreferences` (`movie_search_history`, lista JSON).
- Sin búsquedas guardadas: mensaje "Buscá por título, actor o director".

### 3.3 Resultados
- Misma tarjeta que la grilla (`TvMovieCard`), grilla de 5 columnas.
- OK → `MovieDetailScreen`. Al volver del detalle, el texto, los resultados, el scroll y el foco siguen como estaban.
- Mientras se busca: indicador de carga en el lugar de los resultados (los anteriores se reemplazan cuando llega la respuesta).
- Sin resultados: "No encontramos películas para «…»".

---

## 4. Búsqueda en el servidor

### 4.1 Cuándo se busca
- Desde **2 caracteres**, **600 ms** después de la última tecla (debounce).
- Cada búsqueda nueva descarta la respuesta de la anterior si llega tarde (sólo cuenta la última).
- Al cerrar el teclado con texto, se busca enseguida si no se buscó ya.

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
- Al enfocar la **última fila** de resultados se pide la página siguiente (`pageNum + 1`) y se agrega abajo sin mover el foco.
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
- Tests: `movie_search_controller_test` (debounce, descarte de respuestas viejas, paginado, fallback), `movie_search_cleanup_test` (filtro de series, repetidos, orden), `movie_search_history_test`.

---

## 8. Pendiente: categorías completas

Cada categoría trae 10 películas. Ver más requiere el listado paginado por categoría (`v3/getShelveData` por `columnId`); con `{columnId, columnType: "movie", pageSize, pageNum, numDisplay, encryptVersion: 1}` respondió `rc=0` pero vacío. Falta replicar los parámetros exactos de la app original. Se tratará en otra spec.
