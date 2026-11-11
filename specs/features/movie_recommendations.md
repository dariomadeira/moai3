# SPEC-51: Recomendaciones entre amigos (películas y series)

> **Estado**: Vigente (rama `cristal`; series desde 2026-11-11)  
> **Área**: Features / Películas y series / Social  
> **Archivos de Referencia**:  
> - `supabase/migrations/006_create_movie_recommendations.sql`, `008_create_series_recommendations.sql`  
> - `lib/state/movie_recommendations_provider.dart`, `lib/state/series_recommendations_provider.dart`  
> - `lib/services/movie_recommendations_api.dart`, `lib/services/series_recommendations_api.dart`  
> - `lib/features/home/widgets/home_recommendations_card.dart` (`series: true` para la de series)  
> - `lib/features/movies/screens/movie_player_screen.dart` (`movie_player/movie_player_recommend.dart`), `movie_detail_screen.dart`, `series_detail_screen.dart`  
> - `lib/app/bootstrap.dart` (los dos proveedores reciben los mismos amigos)  

---

## 1. Propósito y alcance

Recomendar películas y series a los amigos y ver las de ellos en tarjetas del Inicio. Las series se describen en §7; lo demás vale para las dos.

### Non-Goals
- Notificaciones de recomendaciones nuevas.
- Comentarios o puntajes visibles: 👎 no sale del TV.
- Recomendar tráileres.
- Recomendar una temporada suelta (se recomienda la serie; ver §7).

---

## 2. Amigos

Sólo cuentan los **mutuos** (`WatchPartyProvider.mutualFriends`): se agregaron entre sí. Sin amigos mutuos no hay pregunta, botón ni tarjeta.

## 3. Cómo se recomienda

### 3.1 Al final de la película
- En los últimos 5 minutos, una vez por reproducción, si la película no se respondió antes.
- No aparece en tráileres ni si se llegó a esos minutos saltando.
- Cartel en una esquina, **sin pausar**; se va solo a los 20 s y entonces se puede volver a preguntar otra vez que se vea.
- Mientras se ve: ←/→ eligen, OK confirma, atrás cierra. Arranca en **Cancelar**, para que un OK distraído no recomiende.

| Opción | Efecto |
| :--- | :--- |
| 👍 | Se guarda en Supabase y lo ven los amigos |
| 👎 | Queda en el TV: no se vuelve a preguntar |
| Cancelar | Nada |

### 3.2 En el detalle
Dos botones de ícono al lado de Marcar, 👍 y 👎, con el elegido resaltado (Marcar → 👍 → 👎). Apretar el voto actual lo quita y apretar el otro lo cambia. 👍 publica; dejar 👍 borra la publicación; 👎 no sale del TV.

## 4. Tarjeta del Inicio
- "Recomendadas", 2 lugares, como "Seguir viendo"; sólo si hay alguna y Películas está en el rail.
- La película elegida dice quién la recomendó ("Juan y 2 más").
- OK abre el detalle; mantener OK borra una; el botón borra todas, con confirmación.
- **Borrar es sólo para este TV** y se guarda localmente. No aparecen las películas ya votadas ni las ya vistas enteras.

## 5. Datos y carga

Tabla `movie_recommendations` (migración 006): quién, `content_id`, la película en JSON (para abrir el detalle sin el catálogo) y fecha.

| Punto | Regla |
| :--- | :--- |
| Tiempo real | No se usa, ni sondeo |
| Lectura | Al abrir el Inicio, como máximo cada 2 min salvo que cambien los amigos |
| Volumen | 40 filas, hasta 20 películas |
| Escritura | Una fila por persona y película |
| Limpieza | `pg_cron` diario: 60 días |
| Sin conexión | Publicar y quitar quedan pendientes y se reintentan en la próxima lectura |

Seguridad como `device_friends`: acceso anónimo por dispositivo, lectura abierta.

## 6. Implementación compartida

- `MovieRecommendationsProvider` guarda en el TV los votos, las borradas y los envíos pendientes (`storageKey`, por defecto `movie_recommendations_state`). `setVote(item, vote, {extra})`: el `extra` va con lo publicado; un 👍 repetido con `extra` se vuelve a publicar (actualiza la fila).
- Lo pendiente se manda con `MovieRecommendationsApi.recommendJson(deviceId, json)`; la de películas lo convierte en la película, la de series agrega la temporada.
- `FriendRecommendation.seasonReached`: en series, hasta qué temporada llegó quien la recomendó.

## 7. Series

Decisión del usuario (2026-11-11): **la recomendación es de la serie** (una tarjeta por serie, no una por temporada), pero se pregunta **al terminar cada temporada** y la fila guarda la última temporada votada, que el amigo ve como "Hasta T3".

- **Tabla aparte** `series_recommendations` (migración 008, aplicada en Supabase el 2026-11-11): `recommender_device_id`, `content_id` (la serie), `series` (JSON, para abrir el detalle sin el catálogo), `season_number`, `created_at`; mismas políticas, índice y limpieza a 60 días (`cleanup_series_recommendations`). Aparte para que las versiones viejas de la app no vean series mezcladas con películas.
- **La serie es la misma en todos los TV**: `SeriesSeasonDetail.recommendationKey` = la temporada 1 y, si tiene dos versiones (SPEC-46 §2), la de `contentId` menor. El detalle la calcula con todas las versiones y se la pasa al reproductor (`SeriesPlaylist.recommendationKey`).
- **En el detalle**: 👍 y 👎 al lado de Marcar (sólo con amigos; Marcar → 👍 → 👎). El 👍 lleva como temporada la más alta con algún capítulo visto (o la que se está mirando).
- **Al terminar cada temporada**: en los últimos 5 min del **último capítulo** de la temporada (no en los del medio), el cartel "Terminaste la T2. ¿Se la recomendás a tus amigos?". Se pregunta **una vez por temporada** (`shouldAskSeason` / `markAskedSeason`, aunque ya se haya votado otra). Sí: 👍 con esa temporada (publica o actualiza). No: 👎 (borra la publicación). Cancelar: vuelve a preguntar la próxima vez que se termine esa temporada.
- **Tarjeta del Inicio**: "Recomendadas" de series (`HomeRecommendationsCard(series: true)`), después de la de películas, con "Series" arriba, el ícono de Series y la etiqueta "Hasta T3" sobre cada una. OK abre el detalle; mantener OK la borra de este TV; "Borrar todas". No aparecen las series votadas ni las ya empezadas (en "Seguir series", `SeriesRecommendationsProvider.startedSeries`).
- `SeriesRecommendationsProvider` extiende el de películas con su API y su guardado (`series_recommendations_state`); el Inicio refresca los dos juntos.
- Tests: `series_recommendations_test`, `series_detail_screen_test` (👍 en el detalle), `movie_player_screen_test` (recomendar al terminar la temporada).
