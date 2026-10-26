# SPEC-42: Inicio (tablero de tarjetas)

> **Estado**: Vigente (rama `cristal`)  
> **Área**: Experiencia de Usuario / Inicio  
> **Archivos de Referencia**:  
> - `lib/features/home/areas/home_dashboard_area.dart`  
> - `lib/features/home/areas/home_dashboard_movies.dart` (part: tarjetas de películas)  
> - `lib/features/home/widgets/home_card.dart` (`HomeCard`, `HomeCardColors`)  
> - `lib/features/home/widgets/home_weather_card.dart`  
> - `lib/features/home/widgets/home_events_card.dart`  
> - `lib/features/home/widgets/home_discounts_card.dart` (ver SPEC-43)  
> - `lib/features/home/widgets/home_movie_list_card.dart`, `home_continue_card.dart`, `home_watchlist_card.dart`, `home_movie_strip.dart`  
> - `lib/features/home/widgets/home_trailers_card.dart`  
> - `lib/features/home/widgets/home_arcade_card.dart`  
> - `lib/features/home/widgets/home_clock.dart`  
> - `lib/features/home/widgets/home_sky.dart` (EN PAUSA)  
> - `lib/features/home/widgets/tv_vertical_nav_rail.dart`  

---

## 1. Propósito

El Inicio es un tablero vertical de tarjetas con lo que importa hoy: clima, eventos, descuentos, películas para retomar o ver después, adelantos y el arcade. Cada tarjeta se maneja con el control remoto sin salir del Inicio.

## 2. Encabezado y rail

- Título: saludo según la hora ("Buenas noches"); subtítulo: **"Revisá tu actividad para hoy"**.
- A la derecha, `HomeClock`: hora (`MoaiFormats.time`) y "LUN · 26 Oct". Se actualiza alineado al cambio de minuto (un `Timer` por minuto, no por segundo).
- Rail: en el Inicio, arriba del rail va el **logo SVG de MOAI vertical** (`_RailLogo`, sin pill). En las demás secciones vuelve la pill de hora y clima (`TvBottomWeatherPill`). Cambia con un `AnimatedSwitcher`.

## 3. Tarjetas y orden

Lista con ventana de **4 tarjetas visibles** (`_windowSize = 4`; alto = alto disponible / 4, máx. 140). Orden y condición de cada una:

| # | Tarjeta | Se muestra si | Color (`HomeCardColors`) |
|---|---------|---------------|--------------------------|
| 1 | Clima | siempre | según el tiempo (`weatherKindOf`) |
| 2 | Eventos | hay eventos de hoy sin terminar | `events` F97316 |
| 3 | Descuentos | siempre (sin bancos pide elegirlos) | `discounts` EAB308 |
| 4 | Seguir viendo | hay películas empezadas | `continueWatching` 22C55E |
| 5 | Interesantes | Películas está en el rail | `watchlist` A855F7 |
| 6 | Adelantos | Ajuste "Adelantos en el Inicio" activo **y** hay adelantos | `trailers` F43F5E |
| 7 | Arcade | siempre | `arcade` 14B8A6 |

`HomeCard`: cristal sólido (`MoaiGlass`) con un halo radial fijo del color de la tarjeta arriba a la izquierda (alfa 0,14 oscuro / 0,18 claro). Es un degradado estático: no agrega trabajo por cuadro.

### 3.1 Clima
Ícono animado (56) a la izquierda, temperatura (40), condición, máx/mín, sensación y lluvia; a la derecha la tira por hora. El lugar es `WeatherProvider.placeName`: con ubicación automática muestra la **región**, no el barrio que devuelve la geolocalización por IP (antes salía "Liberdade").

### 3.2 Eventos
Sólo eventos de hoy no terminados (`CalendarProvider`). El ticker del calendario notifica cuando cambia el estado de un evento (`todayStatusKey()`), así la tarjeta pasa de "próximo" a "en vivo" o se oculta sola. Al cambiar el día se recargan los eventos. La competición va en la fila de arriba ("· Liga Profesional") para que no desborde.

### 3.3 Seguir viendo / Interesantes
Ambas usan `HomeMovieListCard`: resumen y botón a la izquierda, tira de portadas 16:9 a la derecha (`HomeMovieStrip`) con barra de progreso flotante (separada 8 del borde inferior).

- **Seguir viendo**: películas empezadas (ver SPEC-44). OK la retoma donde quedó. **Mantener OK** en una película o el botón "Marcar todas" la(s) marca como vista(s), con confirmación.
- **Interesantes**: películas guardadas para después; OK abre el detalle; botón "Quitar todas".
- Una película está en **un solo lugar**: Interesantes → Seguir viendo → vista.

### 3.4 Adelantos
Fila de adelantos del catálogo (ya no aparecen en la grilla de Películas). Se puede ocultar en **Ajustes › Películas y series › Adelantos en el Inicio** (`TvSettingsProvider.showHomeTrailers`, clave `home_show_trailers`, por defecto `true`).

### 3.5 Arcade
Juego listo con acciones **Jugar**, **Cambiar** e **Invitar**. "Invitar" sólo aparece si hay amigos en línea (`WatchPartyProvider.hasOnlineFriends`) y abre la partida a distancia (`ArcadeLauncher.playTogether`, SPEC-38). Si los amigos se desconectan, la selección vuelve a "Jugar".

## 4. Fondo de cielo (EN PAUSA)

`home_sky.dart` tiene un fondo fotográfico según hora y clima (8 imágenes WebP en `assets/images/home_sky/`, créditos en `CREDITOS.md`). Al usuario no le convenció: el código quedó **comentado** con la marca `EN PAUSA` en `home_dashboard_area.dart` y la carpeta comentada en `pubspec.yaml`. No borrar: se va a revisar.

## 5. Criterios de aceptación

- En el TV (960×540 lógicos) entran 4 tarjetas sin desbordes en tema claro y oscuro.
- Sin eventos hoy, la tarjeta de Eventos no se renderiza.
- Con el ajuste de adelantos apagado, la tarjeta de Adelantos no aparece.
- En el Inicio el rail muestra el logo; en otra sección, la pill de hora y clima.
- Tests: `home_dashboard_area_test`, `home_clock_test`, `home_arcade_card_test`, `tv_vertical_nav_rail_test`, `home_sky_test`, `weather_location_test`.
