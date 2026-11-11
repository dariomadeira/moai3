# SPEC-42: Inicio (tablero de tarjetas)

> **Estado**: Vigente (rama `cristal`)  
> **Área**: Experiencia de Usuario / Inicio  
> **Archivos de Referencia**:  
> - `lib/features/home/areas/home_dashboard_area.dart` (orden y armado), `areas/dashboard/home_dashboard_items.dart` (cada tarjeta y sus teclas)  
> - `lib/features/home/areas/home_dashboard_movies.dart` (part: tarjetas de películas), `home_dashboard_series.dart` (part: tarjetas de series)  
> - `lib/features/home/widgets/home_card_parts.dart` (`HomeCardSummary`, con ícono SVG opcional)  
> - `lib/features/home/widgets/home_weather_card.dart`  
> - `lib/features/home/widgets/home_events_card.dart`  
> - `lib/features/home/widgets/home_friends_card.dart`, `home_friend_requests_card.dart`  
> - `lib/features/home/widgets/home_discounts_card.dart` (ver SPEC-43)  
> - `lib/features/home/widgets/home_movie_big_card.dart` (tarjeta doble de películas/series: rótulo, ícono SVG y etiquetas por ítem), `home_continue_card.dart`, `home_watchlist_big_card.dart`, `home_recommendations_card.dart`, `home_series_continue_card.dart`, `home_series_watchlist_card.dart`, `tv_movie_card.dart` (`badge`)  
> - `lib/features/home/widgets/home_trailers_card.dart`  
> - `lib/features/home/widgets/home_arcade_card.dart`  
> - `lib/features/home/widgets/home_clock.dart`  
> - `lib/features/home/widgets/weather_kind.dart` (tipo de tiempo para el ícono del clima)  
> - `lib/features/home/widgets/tv_vertical_nav_rail.dart`  

---

## 1. Propósito

El Inicio es un tablero vertical de tarjetas con lo que importa hoy: clima, eventos, amigos conectados, descuentos, películas para retomar o ver después, adelantos y el arcade. Cada tarjeta se maneja con el control remoto sin salir del Inicio.

## 2. Encabezado y rail

- Título: saludo según la hora ("Buenas tardes"); subtítulo: **"¿Qué vamos a hacer ahora?"**.
- A la derecha, el logo de MOAI y `HomeClock`: hora (`MoaiFormats.time`) y "MIÉ · 11 Nov". Se actualiza alineado al cambio de minuto (un `Timer` por minuto, no por segundo).

## 3. Tarjetas y orden

Lista con páginas de **4 lugares** (`_windowSize = 4`; alto = alto disponible / 4, máx. 140). Las tarjetas dobles ocupan 2. `TvWindowedList.packPages` acomoda las páginas sin huecos: una doble que no entra en lo que queda de la página pasa a la siguiente y una simple de más abajo ocupa ese lugar (por eso "Seguir series" suele quedar en la segunda página, después de Descuentos). Orden de prioridad (`_visibleWidgets`) y condición de cada una:

| # | Tarjeta | Lugares | Se muestra si | Color |
|---|---------|:---:|---------------|-------|
| 1 | Película destacada (+ recuadro libre a la derecha, reservado para "Series destacadas") | 2 | Películas en el rail y hay estrenos | — |
| 2 | Clima | 1 | siempre | según el tiempo (`weatherKindOf`) |
| 3 | Eventos | 1 | hay eventos de hoy sin terminar | — |
| 4 | Seguir (películas) | 2 | Películas en el rail y alguna empezada | 16A34A |
| 5 | Seguir (series) | 2 | Series en el rail y alguna en curso (SPEC-46 §6) | cian de Series 0891B2 |
| 6 | Recomendadas (películas) | 2 | Películas en el rail y alguna recomendada (SPEC-51) | DB2777 |
| 7 | Recomendadas (series) | 2 | Series en el rail y alguna recomendada (SPEC-51 §7) | DB2777, ícono de Series |
| 8 | Descuentos | 1 | siempre (sin bancos pide elegirlos) | CA8A04 |
| 9 | Amigos | 1 | Miremos Juntos activado | 116699 |
| 10 | Solicitudes | 1 | Miremos Juntos y alguna solicitud recibida | 8E4EC6 |
| 11 | Marcadas (películas) | 2 | Películas en el rail y alguna marcada | EA580C |
| 12 | Marcadas (series) | 2 | Series en el rail y alguna marcada (SPEC-46 §7) | cian de Series 0891B2 |
| 13 | Adelantos | 1 | Ajuste "Adelantos en el Inicio" activo **y** hay adelantos | C026D3 |
| 14 | Arcade | 1 | plugin instalado y una ROM activa | 585EDC |

Las tarjetas son de cristal sólido (`MoaiGlass`); el color es el de su ícono.

### 3.1 Clima
Ícono animado (56) a la izquierda, temperatura (40), condición, máx/mín, sensación y lluvia; a la derecha la tira por hora. El lugar es `WeatherProvider.placeName`: con ubicación automática muestra la **región**, no el barrio que devuelve la geolocalización por IP (antes salía "Liberdade"). La ubicación automática sale de la IP (cae donde el proveedor tiene el nodo, no en el pueblo); para eso está la localidad elegida a mano. Su búsqueda usa **Open-Meteo** (`geocoding-api.open-meteo.com`, GeoNames, sin clave; Argentina primero), porque el buscador de WeatherAPI no tiene pueblos chicos (para "Quines" sólo daba el de España); si falla, cae al de WeatherAPI. El clima se sigue pidiendo a WeatherAPI, por coordenadas.

### 3.2 Eventos
Sólo eventos de hoy no terminados (`CalendarProvider`). El ticker del calendario notifica cuando cambia el estado de un evento (`todayStatusKey()`), así la tarjeta pasa de "próximo" a "en vivo" o se oculta sola. Al cambiar el día se recargan los eventos. La competición va en la fila de arriba ("· Liga Profesional") para que no desborde.

### 3.3 Amigos
Sólo con **Miremos Juntos** activado. A la izquierda "Miremos juntos · Amigos" y cuántos están conectados (con foco: "OK: ir a su canal"); a la derecha los amigos **conectados** en fila con ventana (como Eventos), cada uno con su nombre y el canal que mira (`displayChannelName`: los de adultos no se muestran) o "No está mirando TV". Sin nadie conectado la izquierda dice "Nadie está conectado". Si mira lo mismo que yo, la tarjeta va teñida con el chip "Con vos". Sin amigos conectados: "Ninguno de tus amigos está conectado ahora."

←/→ eligen el amigo y **OK sintoniza su canal** (`onTuneChannel`, el mismo camino que el detalle de un evento), así quedan en el mismo canal y pueden hablar. El canal se busca en la lista propia por id y, si viene de otra extensión, por nombre normalizado (`HomeFriendsItem.channelOf`). Si el amigo no mira nada o el canal no está en la lista, un aviso lo dice.

### 3.4 Tarjetas de películas y series
Todas usan `HomeMovieBigCard` (dos lugares): a la izquierda el rótulo de sección ("Películas" o "Series", `sectionLabel`), el ícono (o el SVG de Series), el título, la cantidad y el botón para todas; a la derecha las imágenes 16:9 (`TvMovieCard` `wide`) con barra de lo visto y, si hay, una etiqueta en el acento arriba a la izquierda (`badge`). ←/→ recorren; a la izquierda de la primera, el botón.

- **Seguir (películas)**: empezadas (SPEC-44). OK la retoma donde quedó; **mantener OK** o "Marcar todo como visto" la(s) marca como vista(s), con confirmación.
- **Seguir (series)**: una por serie, con "T2 · Cap. 5" (a la mitad, con barra) o "Sigue: T2 · Cap. 6" (SPEC-46 §6). OK abre el **detalle** con el foco en ese capítulo; mantener OK la quita ("¿Quitar de Seguir?", lo visto queda); "Quitar todas". Se relee sola cuando cambia lo visto (`SeriesContinueService.changes`; detrás del reproductor no).
- **Recomendadas**: lo que recomendaron los amigos (SPEC-51), con quién la recomendó; la de series con "Hasta T3". OK abre el detalle; mantener OK la borra de este TV; "Borrar todas".
- **Marcadas (películas)**: guardadas para después; OK abre el detalle; mantener OK la desmarca; "Desmarcar todas".
- **Marcadas (series)**: lo mismo con series (SPEC-46 §7).
- Una película está en **un solo lugar**: Marcadas → Seguir → vista. Con series igual: al empezarla sale de Marcadas y pasa a Seguir.

### 3.5 Adelantos
Fila de adelantos del catálogo (ya no aparecen en la grilla de Películas). Se puede ocultar en **Ajustes › Películas y series › Adelantos en el Inicio** (`TvSettingsProvider.showHomeTrailers`, clave `home_show_trailers`, por defecto `true`).

### 3.6 Arcade
Juego listo con acciones **Jugar**, **Cambiar** e **Invitar**. "Invitar" sólo aparece si hay amigos en línea (`WatchPartyProvider.hasOnlineFriends`) y abre la partida a distancia (`ArcadeLauncher.playTogether`, SPEC-38). Si los amigos se desconectan, la selección vuelve a "Jugar".

## 4. Fondo de cielo (descartado)

Hubo un fondo fotográfico según hora y clima detrás del saludo (`home_sky.dart`, fotos en `assets/images/home_sky/`). Se descartó (decisión del usuario, 2026-10-30): se borraron el widget, las fotos, el código comentado del Inicio y su test. Del archivo sólo quedó `WeatherKind`/`weatherKindOf` (`weather_kind.dart`), que usa la tarjeta del clima para el color del ícono.

## 5. Criterios de aceptación

- En el TV (960×540 lógicos) entran 4 tarjetas sin desbordes en tema claro y oscuro.
- Sin eventos hoy, la tarjeta de Eventos no se renderiza.
- Con el ajuste de adelantos apagado, la tarjeta de Adelantos no aparece.
- El rail no lleva logo ni pill de hora: el logo y la hora van en el encabezado del Inicio.
- Con Series en el rail y una serie en curso aparece "Seguir" de series; sin ninguna, no ocupa lugar.
- Tests: `home_dashboard_area_test`, `home_clock_test`, `home_arcade_card_test`, `home_friends_card_test`, `tv_vertical_nav_rail_test`, `weather_kind_test`, `weather_location_test`, `series_continue_service_test` (tarjeta de series), `series_recommendations_test` (Recomendadas de series).
