# SPEC-50: Plan Maestro de Optimización, Limpieza y Refactor

> **Estado**: Borrador v2
> **Versión de destino**: v3.1.x (escalonado, una fase por release)
> **Área**: Arquitectura / Limpieza / Rendimiento / Calidad
> **Base de análisis**: rama `xumovies` @ `f00d8af` (2026-10-23) — 199 archivos Dart (47.873 líneas), 20 archivos nativos (3.253 líneas), `specs/` completo, `docs/` y `../docs/`.

---

## 1. Propósito y Alcance

Dejar moai3 **sin código muerto, sin piezas rotas ni redundantes, con traducciones e iconos centralizados, responsabilidades separadas y rápido en TV**, sin cambiar el diseño visual. Prioridades, en este orden:

1. Código muerto (borrar).
2. Cosas que no andan o son redundantes (arreglar, unificar o sacar).
3. Centralización de traducciones.
4. Centralización de iconos.
5. División de responsabilidades.
6. Optimización (CPU, memoria, rebuilds, arranque, APK).

### 1.1. Fuera de alcance

- **Películas / Series (VOD)**: no se toca su lógica ni su UI. Archivos excluidos:
  `lib/features/movies/**`, `home_movies_area.dart`, `tv_movie_card.dart`, `moiamov_api_service.dart`, `movie_progress_service.dart`, `titan_ranger_service.dart`, `tmdb_trending_service.dart`, `vpn_service.dart`, `featured_movies_provider.dart`, `movie_models.dart`, `settings_movies_series_panel.dart`, `settings_catalog_frequency_row.dart`, el bloque de catálogo de `loading_screen.dart`, `assets/data/`, `assets/vpn/`, `assets/images/{movie,series,trailer}.png` y el código nativo `titan/**` + `com/titan/ranger/**`.
  En tareas transversales (`LocaleKeys`, `MoaiIcons`, canales nativos) solo se hace el reemplazo mecánico, sin cambiar comportamiento. Lo muerto que aparezca ahí se **reporta**, no se borra.
- **`.env`**: se mantiene como está (empaquetado como asset).
- **Diseño**: ningún cambio de colores, tamaños, tipografía, layout ni animaciones visibles. Si algo cambia lo visible, se descarta o se consulta.
- Funcionalidades nuevas (salvo §12, opcionales).

### 1.2. Reglas de ejecución

- Un PR por tarea (o grupo chico de la misma fase), con referencia `SPEC-50 §x.y`.
- Cada PR deja `flutter analyze` limpio y `flutter test` verde.
- Borrar código muerto: antes de cada borrado se vuelve a correr la búsqueda (`grep -rw` en `lib/` y `test/`) para confirmar 0 usos.
- Rendimiento: se mide antes y después (§3.1) en el TV real con `--profile`.
- Las tareas **[verificar en dispositivo]** son deducciones del código: primero se reproducen; si no se reproducen, se descartan.
- Si se toca comportamiento cubierto por una spec congelada (SPEC-22, 30, 33, 35, 37, 38), se actualiza en el mismo PR.

---

## 1.3. Avance

| Fase | Estado (2026-10-23) |
| :--- | :--- |
| 0 | **Hecha.** 0.1: línea base de arranque en `specs/verification/baseline_performance.md` (Chromecast HD, profile: ~9,1 s hasta video). Tests: 211 OK / 1 falla (películas, fuera de alcance). `flutter analyze` limpio con lints estrictos. Detector en `tool/find_unused.dart`. |
| 1 | **Hecha.** Ver hallazgos extra abajo. |
| 2 | **En curso.** Hechos: 2.1 (error de canales visible; bitrate borrado), 2.3 (invitación ya no se rechaza sola; Arcade suspende avisos de fondo y responde "ocupado"), 2.4 (`PresenceCoordinator` + bloqueo en vivo), 2.5, 2.6 (`lib/platform/platform_channels.dart`), 2.7 (calendario y arcade vía `AppPreferences`), 2.8 (`AppInfo`), 2.9 (`SafeChangeNotifier`, búsquedas de provider nullable, catches con log), parte de 2.10 (`VoiceAudioService`, `normalizeText`, envoltorios de cards, reloj por minuto). Hechos después: 2.2 (TLS estricto en hosts críticos y en la descarga del `.dex`; streams siguen permisivos), 2.10 `TvPressDetector` + tecla OK uniforme. Pendientes: `FocusRequester` (va con 5.4) y variantes de botón (requiere aprobar capturas). |
| 3 | **Hecha** salvo 3.4 (helper de formatos) y ordenar `es.json`. 689 literales → `LocaleKeys`; claves genéricas en `common_*`; guarda en `test/translations_test.dart` (sincronía, claves sin uso, literales y textos hardcodeados). |
| 4 | **En curso.** Hechos: 4.3 (`moai_icons.dart` 1.736 → 802 líneas, sin comentarios `Origen`/`Usos` desactualizados; mapas de categorías y grupos con búsqueda normalizada), 4.5 (`test/icons_usage_test.dart`; ningún archivo fuera de `MoaiIcons` importa paquetes de íconos, incluidas películas por reemplazo mecánico). Pendientes: 4.1 colapsar duplicados en semánticos, 4.4 tamaños, 4.2 familia única (requiere aprobar capturas, D-3). |
| 6 | **En curso.** Hechos: 6.1 (sondeo de amigos sin notificar si no cambia nada; overlay del video, barra superior y "Acerca de" con `select`; `HomeTvArea` evita recorrer el catálogo si la lista no cambió; `LoadingScreen` sin reconstruir todo a 60 fps; `TvShortcuts.dpad` estable) y 6.2 (arranque en paralelo). Descartado: `precacheImage(fondo.png)`, la pantalla de carga ya la deja en caché. Pendientes: 6.3 (tras 5.4) y 6.4 split por ABI. |
| 5 | **En curso.** Hechos: 5.1 (`HomeSection`), 5.2 (todas las áreas son `HomeAreaState` con `requestEntryFocus`/`handleBack`; Ajustes, Agenda y Arcade dueños de sus 12 nodos; `HomeScreen` usa un mapa sección → clave y solo recuerda el panel abierto de Agenda/Ajustes; 653 → 512 líneas), 5.4 (`TvTab`, `FocusRequester`, `TvBrowserSession`: TV conserva pestaña, panel, país, categoría y canal al volver de otra sección — probado en Chromecast; `HomeTvArea` partido en `areas/tv/*.dart`, ninguno de más de 400 líneas; `TvExplorePanel` reemplaza índices, `remapPanelIndex` y `TvFocusController`), parte de 5.3 (`PresenceCoordinator`, `StartupUpdateChecker`), 5.7 (`ArcadeLauncher` + `ArcadeGameArgs`), 5.9 (`PlayerEngine.kt` fuera de `MainActivity`), 5.8 (`AppBootstrap` + `AppDependencies` en `lib/app/bootstrap.dart`, `MoaiApp` en `lib/app/moai_app.dart`, `main.dart` 290 → 25 líneas, `PluginHostController` inyectado en `ChannelProvider`; probado en Chromecast). 5.5 UI (partidos en `part`s, sin cambios de comportamiento: `calendar_events_panel` 1.525 → 334 + diálogo de detalle aparte, `tv_friends_dialog` 1.141 → 347, `sources_screen` 906 → 375, `tv_pin_dialog` 840 → 415, `tv_gamepad_config_dialog` 853 → 288, `arcade_games_screen` 782 → 323, `general_plugins_screen` 679 → 294, `tv_voice_test_dialog` 781 → 304; `TvIconActionButton` reemplaza 3 copias de `_IconButtonAction`). 5.5 lógica (`CalendarRepository` en `data/` + `LiveEventDetector`; `FriendsRoster` saca la lista de amigos de `WatchPartyProvider` —la red ya estaba en `WatchPartyService`—; `arcade_netplay_service` 737 → 455 partido en `part`s). Pendientes: 5.8 leer singletons, señalización de netplay como clase propia (requiere probar con dos TVs) por Provider (~30 usos, varios fuera de widgets: bajo beneficio hoy) archivos grandes, 5.6 capas, 5.8. |
| 7 | **Hecha** para specs (SPEC-11/20/22/30/34). `docs/` está en `.gitignore` (local): su reorganización y la copia duplicada en `../docs` quedan a criterio del usuario. |
| 8 | **En curso.** `test/home_screen_dpad_test.dart` monta el `HomeScreen` real: rail con flechas+OK, back desde el rail vuelve a TV, back desde el contenido vuelve al rail. |

Verificado en el emulador de TV (`Television_1080p`): arranque, catálogo, home con video, logos y Agenda sin eventos falsos, sin excepciones en el log. Tests: 219 OK / 1 falla (películas).

Hallazgos que aparecieron al ejecutar (no estaban en el análisis original):
- **Agenda con partidos inventados**: `CalendarProvider.generateMockFixturesForWeek` mezclaba ~20 partidos falsos por semana con los reales (y podían disparar avisos "en vivo" falsos). Borrado junto con sus 31 claves (decisión del usuario).
- **`sessionType` guardaba texto traducido** y `estimatedDuration` comparaba contra "práctica"/"qualy": ahora guarda claves estables (`f1_type_*`, `calendar_session_match`) y se traduce solo al mostrar.
- **Logos de canal deformados**: un commit de rendimiento volvió a poner `memCacheWidth` + `memCacheHeight` (decodifica a 120×120 sin respetar proporción). Corregido; también en banderas.
- **Overlay de Miremos Juntos mostraba "Carlos TV"** (nombre de prueba) si el hablante llegaba sin nombre. Ahora muestra "escuchando audio", como la barra superior. Se borraron todas las simulaciones de diseño (`debugForceVisible`, timers simulados) de los widgets de producción.
- `PlaybackStatsController`: bitrate, buffer y % de buffering nunca se cargaban; backends `legacyVideoPlayer`/`youtube` nunca se usaban. Reducido a estado, backend y servidor activo.
- `ArcadeEmulatorService` era un `ChangeNotifier` sin oyentes que notificaba en un evento nativo (`onFrameRendered`) que nadie emite. Ahora es una clase simple.
- `WatchPartyService.subscribeToVoiceMessages` devuelve una función de cancelación en vez de `RealtimeChannel`: el coordinador de voz ya no depende de tipos de Supabase.
- El repo tiene finales de línea mezclados (49 archivos CRLF, 5 mixtos en el índice). Pendiente: `.gitattributes` con `* text=auto eol=lf` + renormalizar en un PR aparte.
- `docs/evidencias/` no está vacía (capturas de películas): se deja.
- **Miremos Juntos con datos viejos**: cuando un amigo entraba al canal que se mira, el aviso salía pero la lista no se actualizaba y el siguiente sondeo podía repetir el aviso; y `FriendInfo.copyWith` usa `??`, así que un canal `null` (el amigo dejó de mirar) conservaba el anterior hasta el sondeo de 15 s. Corregido en `FriendsRoster`.

## 2. Resumen de Fases

| Fase | Tema | Esfuerzo | Depende de |
| :--- | :--- | :--- | :--- |
| 0 | Línea base: tests verdes, métricas, guardas automáticas | S | — |
| 1 | Borrar código muerto | S | 0 |
| 2 | Arreglar lo que no anda y unificar lo redundante | M | 0 |
| 3 | Traducciones centralizadas | M | 1 |
| 4 | Iconos centralizados | M | 1 |
| 5 | División de responsabilidades | L | 1, 2 |
| 6 | Optimización e interfaz más rápida | M | 0 (algunas tras 5) |
| 7 | Documentación y specs al día | S | en paralelo |
| 8 | Regresión D-pad | M | 5, 6 |

S = menos de 1 día · M = 1-3 días · L = más de 3 días.

---

## 3. Fase 0 — Línea Base y Guardas

### 0.1. Métricas (antes de optimizar)
Con `flutter run --profile` + DevTools, en el TV:

| Métrica | Cómo |
| :--- | :--- |
| M1 Arranque hasta primer frame | timeline `main()` → primer frame |
| M2 Arranque hasta `/home` | log con timestamp en `context.go('/home')` |
| M3 ↓ ×20 en lista de canales | frames > 16 ms |
| M4 TV → Ajustes → TV | tiempo hasta foco usable + frames lentos |
| M5 Rebuilds/min en reposo con video | `WatchPartyOverlay`, `TvWatchPartyHeaderBar`, `HomeTvArea` |
| M6 Memoria tras cargar canales | DevTools Memory (FocusNodes vivos) |
| M7 Tamaño APK release | `flutter build apk --analyze-size` |

Resultados en `specs/verification/baseline_performance.md`.

### 0.2. Tests en verde (hoy: **197 OK / 18 fallan**)
- **Iconos**: los tests buscan `Icons.chevron_left`, `Icons.today_outlined`, etc., que ya no se usan tras migrar a Reicons. Pasar a `find.byIcon(MoaiIcons.x)`. Afecta `calendar_events_panel_test`, `calendar_subscriptions_panel_test`, `sources_screen_test`, `tv_pin_dialog_test`, `tv_tab_bar_test`, `tv_voice_test_dialog_test`, `tv_watch_party_header_bar_test`, `watch_party_overlay_test`, `tv_list_card_leading_logo_test`.
- **Fecha real**: `calendar_provider_test` (F1 "eventos de hoy") depende de `DateTime.now()`. Inyectar un reloj en `ArgentinaTime` (`now` sobreescribible) y fijar fechas.
- **Supabase sin inicializar**: `WatchPartyVoiceCoordinator` llama a `Supabase.instance` en tests (`Failed assertion '_instance._isInitialized'`). Inyectar el `SupabaseClient` (o un `RealtimeSubscriber`) por constructor.
- `movie_detail_screen_test` (películas): se reporta, no se toca.

### 0.3. Guardas automáticas (para que no vuelva el código muerto)
- `analysis_options.yaml`: hoy solo `flutter_lints` por defecto. Agregar reglas:
  `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `unnecessary_lambdas`, `avoid_redundant_argument_values`, `cancel_subscriptions`, `close_sinks`, `unawaited_futures`, `use_build_context_synchronously` (como error), `always_declare_return_types`.
- Herramienta de código muerto público (el analizador solo detecta privados): `dart_code_linter` (fork mantenido de DCM) como `dev_dependency`, con `check-unused-code lib` y `check-unused-files lib` en CI. El script ad hoc usado para este análisis queda como respaldo en `tool/find_unused.dart`.
- Tests de guarda: `test/translations_test.dart` (§3.6) y `test/icons_usage_test.dart` (§4.5).

**Aceptación**: `flutter test` sin fallos (salvo el de películas, documentado) y CI corriendo las guardas.

---

## 4. Fase 1 — Borrar Código Muerto

Todo lo de esta fase fue verificado con 0 usos fuera de su declaración (búsqueda por identificador en `lib/`). "Solo test" = lo usa únicamente un test: se borra junto con ese test o se mueve al fake del test.

### 1.1. Clases y widgets sin uso
| Elemento | Ubicación | Acción |
| :--- | :--- | :--- |
| `TvPanel` | `widgets/tv_common/tv_m3.dart:251` | borrar |
| `TvFocusController` (un solo método) | `focus/tv_focus_controller.dart` | absorber en `TvFocusGraph` (§5.4) y borrar el archivo |
| `MoaiThemeContext.elevatedSurface` | `theme/moai_text.dart:7` | borrar (dejar `scheme`) |
| `SafeProviderContext.*` sin try/catch | `utils/context_extensions.dart` | reescribir con `Provider.of<T?>` (§2.9) |

### 1.2. Foco: nodos y métodos sin uso (impacto alto en memoria)
`ChannelBrowserController` (`countryFocusNodes`, `categoryFocusNodes`, `channelFocusNodes`, 3 `ScrollController`, `focusSelectedCountry` `:288`, `focusSelectedCategory` `:301`) y `GroupsBrowserController` (`groupFocusNodes`, `channelFocusNodes`, 2 `ScrollController`, `focusSelectedGroup` `:175`) crean **un FocusNode por canal** que nadie usa: `TvWindowedList`/`TvWindowedGrid` tienen sus propios nodos. Son miles de nodos creados y destruidos en cada sync.
**Acción**: borrar nodos, scroll controllers, `syncFocusNodes` y sus `dispose`. Ajustar `channel_browser_controller_test` y `groups_browser_controller_test`. Actualizar SPEC-30 §2.1 (todavía describe el modelo con `ListView`).

### 1.3. Miembros públicos sin uso
| Archivo | Miembros |
| :--- | :--- |
| `data/repositories/channel_repository.dart` | `loadGroups` `:74` |
| `engine/moai_engine_player.dart` | `hasFirstFrame` `:95`, `disposed` `:97` |
| `features/calendar/widgets/calendar_events_panel.dart` | `focusFromLeft` `:91`, `focusFromRight` `:100` (solo test) |
| `features/games/models/arcade_netplay_state.dart` | `areBothReady` `:113`, `playerNumber` `:117` (solo test) |
| `features/games/services/arcade_emulator_service.dart` | `isRunning`, `isPaused`, `currentRomPath`, `currentInputMask` `:57-60` |
| `features/games/services/arcade_netplay_service.dart` | `onRemoteInputReceived` `:49`, `pendingIncomingInvite` `:56`, `isWebRtcConnected` `:61` |
| `features/games/services/arcade_rom_manager_service.dart` | `localEmulatorManifestUrl` `:15` |
| `features/home/areas/home_tv_area.dart` | `isPlayerFullScreen` `:494` |
| `focus/tv_layout_constants.dart` | `viewerSectionGap`, `viewerHorizontalPaddingStart`, `viewerHorizontalPaddingEnd`, `viewerFavoritesBarHeight`, `viewerFavoritesTitleGap` `:8-18` |
| `widgets/tv_common/tv_panel_header_metrics.dart` | `viewerTopInset`, `titleFontSize`, `bottomInset` (queda casi vacío: fusionar con `tv_layout_constants.dart`) |
| `helpers/notification_helper.dart` | `updateContext` `:15`, `removeCurrent` `:61` |
| `services/app_preferences_service.dart` | `resetAll` `:12`, `readPreferenceString` `:16` |
| `services/modal_route_tracker.dart` | `activeModalCount` `:20`, `resetForTesting` `:43` (solo test) |
| `services/playback_stats_controller.dart` | `showLoadingOverlay` `:38`, `showsMediaKitStats` `:44` (resto de media_kit, que ya no existe), `setIdle` `:108` (solo test) |
| `services/supabase_presence_service.dart` | `watchDevice` `:186` → ver D-5 (§2.4): se usa o se borra |
| `services/watch_party_voice_coordinator.dart` | `currentAudioDurationMs` `:50`, `queueLength` `:51` (solo test) |
| `services/calendar/f1_calendar_service.dart` | `parseRacesForTest` `:45` (solo test → `@visibleForTesting`) |
| `state/calendar_provider.dart` | `allEvents` `:192`, `eventsGroupedByDay` `:216`, `checkNewLiveEvents` `:152` (solo test) |
| `state/watch_party_provider.dart` | `friendsWatchingCurrentChannelCount` `:93` |
| `state/weather_provider.dart` | `cityDisplay`, `conditionDisplay`, `iconUrlDisplay` `:72-78`, `customLocationName` `:49` (solo test) |
| `widgets/dialogs/tv_pin_dialog.dart` | `transformInternal` `:12` |

Reportados sin tocar (películas): `movie_models.isAnySpanish`, `moiamov_api_service.{cachedCatalog, syncCancelled, syncAll}`, `movie_progress_service.clearProgress`, `vpn_service.{currentStage, currentStatus}`.

### 1.4. Hooks de debug/mock dentro de widgets de producción
`TvWatchPartyHeaderBar.setDebugMode` / `mockFriendsCount` (`tv_watch_party_header_bar.dart:39-43`) y `WatchPartyOverlay.debugMockFriendsCount` (`watch_party_overlay.dart:23`) existen solo para tests. Se reemplazan por un `FakeWatchPartyProvider` en `test/` y se borran del código de producción.

### 1.5. Iconos sin uso (38 constantes en `MoaiIcons`)
`hourglassEmpty`, `installDesktop`, `keyboardOutlined`, `libraryBooks`, `linkRounded`, `locationCity`, `playArrowRounded`, `playlistAddOutlined`, `remoteGen`, `restaurantMenuOutlined`, `searchRounded`, `sportsBasketballOutlined`, `sportsFootballOutlined`, `sportsMotorsportsOutlined`, `stadiaController`, `symbolBookmarks`, `symbolChevronRight`, `symbolFavorite`, `symbolTv`, `theaterComedyOutlined`, `tvSignin`, `tvWithAssistant`, `twoWheelerOutlined`, `calendarMonth`, `settingsOutlined`, `addRounded`, `backspaceOutlined`, `book2`, `bookmarksOutlined`, `bookmarkHeart`, `categoryOutlined`, `starRounded`, `childCare`, `childHat`, `confirmationNumber`, `emojiEventsOutlined`, `exploreOutlined`, `tvAccordionMoviesFeatured`*.
(*de películas: se reporta.) Antes de borrar, revisar que no estén referenciadas dentro de los mapas `tvCategoryIcons` / `calendarSubIcons`.

### 1.6. Traducciones sin uso (48 de 637 claves)
- `home_rail_{home,tv,featured,series,calendar,arcade,settings}_title` (7): **se usan** como `Semantics(label:)` de cada destino del rail (accesibilidad, sin cambio visual).
- El resto (41) se borra de `es.json`, salvo las que reemplacen textos hardcodeados (§3.3):
  `calendar_empty_events`, `calendar_empty_subscriptions`, `calendar_status_today`, `calendar_status_upcoming`, `calendar_day_today`, `calendar_day_tomorrow`, `calendar_event_details`, `calendar_event_competition`, `settings_general_weather_desc`, `weather_location_type_to_search`, `weather_location_search_prefix`, `weather_location_search_desc_modify`, `accent_active_desc`, `friends_back_tooltip`, `friends_empty_desc`, `friends_status_last_seen`, `friends_delete_success`, `friends_accept_success`, `friends_time_just_now`, `friends_time_minutes`, `friends_time_hours`, `blocked_exit_button`, `arcade_gamepad_detected_snack`, `arcade_delete_dialog_title`, `arcade_delete_dialog_desc`, `arcade_err_invalid_name`, `gamepad_test_focus_hint`, `gamepad_test_hint`, `gamepad_status_connected`, `gamepad_device_section`, `gamepad_device_detected`, `gamepad_mode_bt`, `gamepad_mode_bt_desc`, `gamepad_mapping_section`, `plugins_count_plural`, `plugins_status_installed`, `plugins_status_installing`, `plugins_status_downloading`, `plugins_action_install`, `plugins_arcade_uninstall_dialog_title`, `plugins_arcade_uninstall_dialog_desc`.
  Ojo: `calendar_status_upcoming` reemplaza el `'PROX.'` hardcodeado (§3.3) → se conserva.

### 1.7. Assets y dependencias muertas
| Elemento | Motivo | Acción |
| :--- | :--- | :--- |
| `assets/images/background.png` (1,1 MB), `foreground.png` (0,5 MB), `iconApp.png` (0,6 MB) | solo los usa `flutter_launcher_icons`; 0 referencias en `lib/` | mover a `assets_src/launcher/` (fuera del bundle) y actualizar la config del launcher. **−2,3 MB de APK** |
| `material_symbols_icons` | solo 49 constantes en `moai_icons.dart` | se elimina al terminar §4.2 |
| `dynamic_color` | solo se usa `.harmonized()` sobre un esquema `fromSeed` (`main.dart:276,280`), que casi no cambia nada | comparar captura con y sin; si es idéntica, quitar la dependencia |
| `MoaiImageCacheManager.clearLegacyCache()` | migración de caché v2 → v3 que corre en **cada** arranque | ejecutar una vez (flag en prefs) y borrar en la release siguiente |
| `docs/evidencias/` | carpeta vacía | borrar |

---

## 5. Fase 2 — Lo que No Anda y lo Redundante

### 2.1. Estados que se calculan pero nunca funcionan
| Problema (verificado) | Ubicación | Acción |
| :--- | :--- | :--- |
| `ChannelRepository._loadError` solo se asigna a `null`; `channelLoadError` nunca se lee. **Un error de carga de canales nunca se registra ni se muestra.** | `channel_repository.dart:18,71`, `channel_provider.dart:55` | registrar el error en el `catch` de carga y mostrarlo en `EmptyViewerPanel` / `TvEmptyStateCard` existentes; o borrar ambos si se decide no mostrarlo |
| `PlaybackStatsController.setBitrateMbps` nunca se llama: **el bitrate del panel de stats siempre está vacío** | `playback_stats_controller.dart:70` | emitir `bitrate` desde `PlayerEntry` (Kotlin, `onVideoSizeChanged`/`analytics`) por el EventChannel y conectarlo; si no se quiere, borrar el campo y su UI |
| `watchDevice` (Realtime de `devices`) sin uso: un bloqueo desde Supabase **solo se aplica al reiniciar la app**, aunque SPEC-22 pide tiempo real | `supabase_presence_service.dart:186` | **D-5**: conectarlo en `PresenceCoordinator` (§5.3) para ir a `/blocked` en vivo, o borrarlo y corregir SPEC-22 |

### 2.2. Seguridad: TLS desactivado globalmente
- **Nativo**: `MainActivity.configurePermissiveSsl()` instala un `TrustManager` que acepta todo y un `HostnameVerifier` que devuelve `true`, como default de **todo** el proceso (`MainActivity.kt:58-89`, llamado dos veces: en el `companion init` y en `configureFlutterEngine`). Afecta a ExoPlayer, `PluginLoader` (descarga de `.dex` que luego se **ejecuta**) y la instalación de APK.
- **Dart**: `BadCertHttpOverrides` acepta cualquier certificado salvo 3 hosts (`main.dart:37`), y `arcade_rom_manager_service.dart:114,176` lo vuelve a desactivar por su cuenta.
**Cambio**:
- Invertir la regla: validación estricta por defecto; `kInsecureSslHosts` (lista explícita de hosts que realmente lo necesitan, ej. fuentes de streams de plugins) en `config/constants.dart`.
- Nativo: borrar el default global; si un plugin lo necesita, un `SSLSocketFactory` permisivo **solo** para el `DataSource` de ExoPlayer de ese stream.
- `PluginLoader` y actualización de APK: siempre TLS estricto (ya se verifica SHA-256 del `.dex`, mantenerlo).
- Sacar la llamada duplicada.
**Aceptación**: Supabase, GitHub Releases, WeatherAPI y descarga de plugins funcionan con TLS estricto; los streams de los hosts listados siguen reproduciendo.

### 2.3. Snacks y notificaciones
- **Arcade sin snacks de segundo plano**: mientras se juega, los avisos de eventos en vivo/invitaciones pueden aparecer y robar el foco (`ArcadeScreen` es opaca y `ModalRouteTracker` no la cuenta). Nuevo `NotificationGate` (`suspend/resume` por motivo). Se suspenden solo los snacks de segundo plano (eventos en vivo, invitaciones, "amigo se unió", avisos de watch party); el feedback de acciones del usuario nunca. Los eventos quedan encolados y se muestran al salir del juego. **D-1**: invitación arcade durante el juego → por defecto responder "ocupado".
- **Invitación arcade rechazada por accidente (verificado)**: `MoaiSnackBar.show` hace `removeCurrentSnackBar()` (`moai_snackbar.dart:75`) y el `onDismiss` de la invitación llama a `rejectIncomingInvite` (`home_screen.dart:190`). Cualquier snack posterior o abrir un diálogo la rechaza. Pasar a `onDismiss` solo cierres por `timeout`/`dismiss`; los snacks de alta prioridad no se pisan, se encolan.

### 2.4. Presencia con dos dueños
`main.dart:131-147` reporta el canal en cada notificación de `ChannelProvider`, mientras `HomeScreen._updatePresenceForSection` lo pone en `null` fuera de TV/Arcade. En Ajustes, un refresh de plugins vuelve a mostrar "viendo X". Un único `PresenceCoordinator` (§5.3) es dueño de online/offline, heartbeat, canal actual y (D-5) bloqueo en vivo. Se borra el listener de `main.dart`.

### 2.5. Router reevaluado para nada
`routers.dart:38` usa `refreshListenable: tvSettingsProvider` pero el `redirect` no lee ajustes. Quitarlo.

### 2.6. Canales nativos con nombres repetidos
El mismo `MethodChannel` se declara en varios archivos:
- `com.infomak.moai.tv/device`: 6 veces (`double_back_exit_scope`, `device_identity_service`, `device_memory_service`, `update_service`, `tv_settings_provider`, `moiamov_api_service`*).
- `com.infomak.moai/arcade_channel`: 3 (`arcade_emulator_service`, `arcade_rom_manager_service`, `gamepad_manager_service`).
- `com.infomak.moai.tv/player`: 2 (`moai_engine_player`, `arcade_screen` para `pauseAll/resumeAll`).
**Cambio**: `lib/platform/platform_channels.dart` con los nombres como constantes y **un wrapper por canal**: `DeviceChannel` (RAM, id, fingerprint, emulador, `finishApp`, sonidos D-pad, `installApk`), `ArcadeChannel`, y `MoaiEnginePlayer.pauseAll/resumeAll` estáticos para Arcade. Nadie más crea `MethodChannel`. Mismo criterio del lado Kotlin (§5.9).

### 2.7. Preferencias fuera de `AppPreferences`
`SharedPreferences.getInstance()` directo en `calendar_provider.dart` (6 veces), `arcade_plugin_service.dart` (3), `arcade_rom_manager_service.dart` (2) (+ películas). Cada uno con sus claves sueltas.
**Cambio**: todos reciben `AppPreferences` por constructor; claves en `lib/config/pref_keys.dart` (`abstract final class PrefKeys`) para evitar colisiones y tener un inventario único. `AppPreferences` agrega `readOptionalInt`/`readOptionalDouble` si hace falta.

### 2.8. Información de la app repetida
`PackageInfo.fromPlatform()` se llama en 3 lugares (`player_config.dart:11`, `device_identity_service.dart:177`, `update_service.dart:125`). `PlayerConfig` no configura el reproductor: solo guarda versión y RAM para el log de debug.
**Cambio**: renombrar a `AppInfo` (`version`, `buildNumber`, `totalRamMb`), cargarlo una vez en el arranque y usarlo en los 3 lugares. Borrar `player_config.dart`.

### 2.9. Errores silenciados
- 55 `catch (_) {}` / `catch (_) {` sin log. Revisarlos uno por uno: los esperables quedan con un comentario de por qué; el resto pasa a `debugPrint`/`DebugLogController` o `FlutterError.reportError`.
- `SafeChangeNotifier` (`utils/safe_change_notifier.dart`) traga las excepciones de los listeners → `FlutterError.reportError` (se loguea sin crashear).
- `SafeProviderContext.watchOptional/readOptional/selectOptional` usan try/catch como control de flujo → `Provider.of<T?>(context, listen: …)`.

### 2.10. Componentes redundantes
| Redundancia | Unificación |
| :--- | :--- |
| ~13 widgets reimplementan tap / long-press / repetición con `Timer` + `_isKeyDown` + `_longPressTriggered` (`channel_grid_tile`, `tv_icon_list_card`, `new_channel_card`, `alphabet_letter_card`, `tv_tile`, `viewer_favorite_tile`, `watch_party_overlay`, `tv_watch_party_header_bar`, `tv_friends_dialog`, `calendar_events_panel`, `alphabet_jump_panel`, `arcade_screen`; `tv_movie_card`*) | un `TvPressDetector` (`widgets/tv_common/tv_press_detector.dart`) con los tiempos actuales en `TvTiming` (long press 800 ms, tap en KeyUp si hay long press, repeticiones horizontales bloqueadas). Resetea el estado al perder el foco |
| 21 de 28 archivos que miran `LogicalKeyboardKey.select` no aceptan `numpadEnter` y algunos tampoco `gameButtonA` (ej. `tv_dialog.dart:291`) | usar siempre `TvKeyHandler.isActionKey` (lo absorbe `TvPressDetector`) |
| ~10 variantes de reintento de foco (`_focusSelectedX` en `home_tv_area.dart:414+`, `requestFocusWithRetry`, `_requestFocusWithRetry` en `home_screen.dart:424`, `FocusScrollSync.requestFocusAtIndex` con hasta 40 frames), ninguna cancelable | `FocusRequester` único por área con `epoch`: un pedido nuevo cancela el anterior; aborta si el área se desmontó o el usuario movió el foco. Borra las demás |
| `CountryCard`, `CategoryCard`, `GroupCard` son envoltorios de 50-60 líneas que solo pasan props a `TvIconListCard` | constructores con nombre o funciones (`TvIconListCard.country(...)`) en el mismo archivo; borrar los 3 archivos |
| ~~`UpdateDialog` y `PluginUpdateDialog`~~ | **Descartado** al revisarlo: el de plugins no tiene progreso ni cancelación; solo comparten un esquema de estados simple. Unificarlos no reduce código. |
| Botones enfocables: `TvFocusButton` (`tv_m3.dart`), `TvDialogButton`, `TvTile`, `TvBackPill`, `TvInstallPill`, `TvSettingsActionRow` | inventariar estilos; los que solo difieren en relleno/borde pasan a variantes (`TvButton.filled/outlined/pill`) sobre `TvPressDetector`. Sin cambio visual |
| Normalizadores de acentos duplicados (`calendar_channel_matcher.dart:190`, `tmdb_trending_service.dart:21`*) y comparaciones contra texto en español (`calendar_event.dart:41-45` con `'práctica'`, mapa `tvCategoryIcons` con `'Películas'`, `'Música'`, `'Niños'`) | `lib/utils/text_normalize.dart` (minúsculas, sin acentos) usado en todos |
| Relojes: `TvBottomWeatherPill` con `Timer` de 1 s para detectar el cambio de minuto, además de `AgendaClockProvider` | un `MinuteTicker` compartido (`ValueNotifier<DateTime>`, timer al próximo minuto exacto y luego cada 60 s) |
| `RemoteVoiceTestService` se llama "test" (SPEC-34, PoC) pero es el motor de audio real de Miremos Juntos | renombrar a `VoiceAudioService` (Dart) / `RemoteVoiceManager` ya está bien en Kotlin; el diálogo de prueba queda como consumidor más |
| `docs/` y `../docs/`: los 10 archivos de `../docs` son **copias idénticas** de `moai3/docs` | ver §7 |

---

## 6. Fase 3 — Traducciones Centralizadas

Estado (verificado): 637 claves en `assets/translations/es.json`, 0 faltantes, 48 sin uso (§1.6), ~665 usos `'clave'.tr()` con strings sueltos.

### 3.1. Claves tipadas
- `dart run easy_localization:generate -f keys -o locale_keys.g.dart -S assets/translations -O lib/l10n`.
- Migración mecánica con script: `'home_tv_favorites'.tr()` → `LocaleKeys.home_tv_favorites.tr()` (también en películas, solo el reemplazo textual).
- Listas de claves dinámicas (`MoaiAccentColors.labelKeys`, mapas de estados) pasan a `LocaleKeys`.
- Resultado: una clave mal escrita o borrada da **error de compilación**.

### 3.2. Organización del JSON
- Ordenar `es.json` por prefijo de feature (`home_`, `tv_`, `calendar_`, `arcade_`, `gamepad_`, `friends_`, `settings_`, `plugins_`, `weather_`, `common_`) y alfabéticamente dentro de cada uno (script, sin cambiar valores).
- Textos genéricos repetidos ("Cancelar", "Aceptar", "Volver", "Reintentar", "Cerrar") en `common_*` y reutilizados; borrar los duplicados por feature (detectar valores iguales con script).

### 3.3. Textos hardcodeados (fuera de películas)
| Lugar | Texto | Acción |
| :--- | :--- | :--- |
| `games/widgets/arcade_view_container.dart:35` | "El emulador de Arcade requiere un dispositivo Android." | `arcade_requires_android` |
| `calendar/widgets/calendar_events_panel.dart:1253,1508` | `'PROX.'` | `calendar_status_upcoming` (ya existe sin uso) |
| `arcade_controller_overlay.dart:200,207`, `tv_gamepad_config_dialog.dart:484,492` | `COIN` / `START` | se mantienen (nombres de botón), en `ArcadeButtonLabels` |
| concatenaciones `'${'x'.tr()}: $valor'` (`arcade_games_screen.dart:653`, `reconnection_coordinator.dart:134`, `tv_voice_test_dialog.dart:665`, …) | — | `namedArgs` (`"mic_test_devices_header": "Dispositivos: {info}"`) |
Películas (`movie_detail_screen.dart:109,491`, `tv_movie_hero_card.dart:218`): se reportan.

### 3.4. Formatos
Fechas, horas y números siempre con `intl` + locale actual desde un helper `MoaiFormat` (hoy `DateFormat` se arma suelto en cada widget). Plurales con `.plural()` de easy_localization en vez de claves `_plural` manuales.

### 3.5. Lógica que depende del idioma
`calendar_event.dart:41-45` y `tvCategoryIcons` usan `text_normalize` (§2.10) o, mejor, el tipo de sesión/categoría de la fuente cuando exista.

### 3.6. Guarda
`test/translations_test.dart`: carga `es.json`, recorre `lib/` y falla si (a) falta una clave, (b) hay claves sin uso (lista blanca), (c) hay `Text('…')`/`label: '…'` con letras fuera de una lista blanca.

---

## 7. Fase 4 — Iconos Centralizados

Estado (verificado): `MoaiIcons` (1.736 líneas, 295 constantes, ~1.000 líneas de comentarios) es la única puerta de entrada salvo 2 usos directos en películas. Mezcla 3 familias: `Icons` (74), `Symbols` (49), `ReiconIcons`/`ReiconFilledIcons` (168). 44 valores están repetidos bajo nombres distintos (`ReiconIcons.gamepad` ×6, `tv` ×5, `trash4` ×5, `football` ×4, …).

### 4.1. Capa semántica + alias
```dart
abstract final class MoaiIcons {
  // 1) Semánticos: fuente de verdad, uno por concepto.
  static const delete = ReiconIcons.trash4;
  static const gamepad = ReiconIcons.gamepad;
  // 2) Alias por ubicación: solo si esa zona tiene que poder divergir sola.
  static const friendsDelete = delete;
}
```
Regla: una ubicación nueva usa el semántico. Los 44 duplicados se colapsan al semántico (los alias que no tienen motivo para divergir se borran y sus usos pasan al semántico).

### 4.2. Una sola familia
- Inventario por familia (script) en este spec.
- Reicons como familia por defecto (ya la usa el rail). Migrar `Symbols.*` e `Icons.*` por pantalla, con captura antes/después y aprobación por tanda.
- Con `Symbols` en 0 se quita `material_symbols_icons` del `pubspec`.
- **D-3**: confirmar Reicons como familia única.

### 4.3. Archivo más chico
- Comentarios: uno corto por grupo, no por constante (las ~1.000 líneas de `///` repiten el nombre).
- Separar en `lib/theme/icons/`: `moai_icons.dart` (semánticos), `moai_category_icons.dart` (mapas `tvCategoryIcons`, `calendarSubIcons` con búsqueda normalizada), reexportados desde `moai_icons.dart`.

### 4.4. Tamaños
`MoaiIconSizes` (`rail = 20`, `list = 22`, `dialog = 18`, …) si el inventario muestra tamaños repetidos; los números sueltos de `size:` pasan a esas constantes.

### 4.5. Guarda
`test/icons_usage_test.dart`: falla si aparece `Icons.`, `Symbols.` o `Reicon` fuera de `lib/theme/icons/` (lista blanca: películas). Los tests usan siempre `find.byIcon(MoaiIcons.x)`.

---

## 8. Fase 5 — División de Responsabilidades

### 5.1. `enum HomeSection` compartido
Las secciones están duplicadas como `int` en `home_screen.dart:52-59` y `tv_vertical_nav_rail.dart:35-42` →
`enum HomeSection { home, tv, featured, movies, series, calendar, arcade, settings }`, usado por el rail, `HomeScreen` y la sección inicial.

### 5.2. Todas las áreas implementan `HomeAreaState`
Hoy solo `HomeTvArea` lo hace. `HomeScreen` tiene 14 FocusNodes de otras áreas (Ajustes ×6, Agenda ×2, Arcade ×4) y cadenas de `if` en `_onRailFocusRight` / `_interceptBack`.
```dart
abstract class HomeAreaState<T extends StatefulWidget> extends State<T> {
  void requestEntryFocus();
  /// true si consumió el back (no subir al rail).
  bool handleBack() => false;
}
```
Cada área es dueña de sus nodos e índice de panel. `HomeScreen` usa `Map<HomeSection, GlobalKey<HomeAreaState>>` y un `switch` para construirlas.

### 5.3. Adelgazar `HomeScreen` (744 líneas) → coordinadores
En `lib/features/home/coordinators/`:
| Clase | Responsabilidad | Origen |
| :--- | :--- | :--- |
| `LiveEventNotifier` | cola de avisos de eventos en vivo, cooldown, reencolado, `NotificationGate` | `home_screen.dart:117-365` |
| `ArcadeInviteListener` | escuchar invitaciones, snack, aceptar/rechazar, abrir preparación | `home_screen.dart:149-200` |
| `PresenceCoordinator` | online/offline por sección, heartbeat, canal actual, bloqueo en vivo (D-5) | `home_screen.dart:202-235`, `main.dart:131-147` |
| `StartupUpdateChecker` | update de APK y luego de plugins, a los 4 s | `home_screen.dart:367-396` |
`HomeScreen` queda en: shell + rail + `switch` de áreas + back.

### 5.4. Partir `HomeTvArea` (1.333 líneas)
- `enum TvTab { explore, search, groups }` reemplaza el String `_tvTab` y `startupTvTab` (con migración del valor guardado).
- `enum TvExplorePanel { log, country, category, channel }` + `TvPanelLayout` mapea enum ↔ posición. Se acaba el corrimiento manual de índices (`remapPanelIndex`, parámetro `showTvLog` en todos los métodos).
- `TvBrowserSession`: estado de navegación (controllers de canales, grupos, favoritos, búsqueda, tab e índices) que vive por encima del área, así **volver a TV conserva país/categoría/canal** y no recalcula el catálogo. El reproductor sigue destruyéndose al salir de TV (D-2).
- Archivos: `tv_area_sync.dart` (lo que hoy hace `_onStateChanged`), `tv_focus_graph.dart` (←/→/↑ entre paneles, tabs, visor, favoritos; absorbe `TvFocusController`), `explore_tab_view.dart`, `groups_tab_view.dart`, `search_tab_view.dart`.
- Objetivo: ningún archivo de más de 400 líneas.

### 5.5. Archivos grandes
| Archivo | Líneas | División |
| :--- | :--- | :--- |
| `calendar_events_panel.dart` | 1.560 | grilla semanal / tarjeta de evento / diálogo de detalle / badges |
| `tv_friends_dialog.dart` | 1.163 | lista / tile de amigo / acciones / estados vacíos |
| `sources_screen.dart` | 917 | input de URL / instaladas / disponibles |
| `tv_gamepad_config_dialog.dart` | 862 | test de botones / mapeo / detección |
| `tv_pin_dialog.dart` | 856 | teclado numérico / `PinController` |
| `arcade_games_screen.dart` | 791 | columnas / tile / descargas |
| `tv_voice_test_dialog.dart` | 788 | controller de grabación / UI |
| `arcade_netplay_service.dart` | 715 | lobby Supabase / señalización / estado de partida |
| `calendar_provider.dart` | 682 | `CalendarRepository` (fetch + caché en prefs) / provider (estado de UI) / `LiveEventDetector` |
| `general_plugins_screen.dart` | 682 | lista / acciones / estados |
| `watch_party_provider.dart` | 579 | `FriendsRepository` / provider de estado |

### 5.6. Capas: `services/` vs `state/` vs `data/`
Hoy se mezclan: `services/` tiene controllers de UI (`playback_stats_controller`, `debug_log_controller`, `modal_route_tracker`) y `state/` tiene acceso a red y prefs.
Regla:
- `data/` → repositorios (red, Supabase, prefs, caché). Sin `ChangeNotifier`.
- `services/` → integraciones sin estado de UI (plataforma, clima, calendario, updates).
- `state/` → `ChangeNotifier` de UI que consumen repositorios/servicios.
- `platform/` → wrappers de canales nativos (§2.6).
Mover: `playback_stats_controller`, `debug_log_controller` → `state/`; `helpers/notification_helper.dart` → `widgets/feedback/` (y borrar la carpeta `helpers/`); `layout/` → `focus/` o `widgets/tv_common/` (2 archivos sueltos).

### 5.7. Navegación unificada
GoRouter + 9 `MaterialPageRoute` imperativos. `ArcadeScreen` se abre por 3 caminos (`/arcade/game`, `home_arcade_area.dart:62,126`, `home_screen.dart:179`).
- `lib/routers/app_routes.dart` con helpers tipados (`AppRoutes.arcadeGame(context, args)`) y `ArcadeGameArgs` en vez de `extra` `String | Map`.
- Rutas GoRouter para juego arcade, selección de juegos, color de acento, plugins y fuentes. Las de películas no se tocan.

### 5.8. Inyección de dependencias y arranque
- `ChannelProvider` crea su `PluginHostController`: crearlo en `main.dart` e inyectarlo.
- `main.dart` (307 líneas) arma todo a mano: extraer `AppBootstrap` (`lib/app/bootstrap.dart`) que devuelve un `AppDependencies` y `lib/app/moai_app.dart` con el `MaterialApp`. `main()` queda en ~15 líneas.
- Singletons `.instance` (`ArcadePluginService`, `ArcadeNetplayService`, `ModalRouteTracker`, `NotificationGate`) se mantienen pero los widgets los leen por Provider (testeables con overrides).

### 5.9. Nativo: `MainActivity` (798 líneas)
Hoy contiene el canal de device, el de voz, el `PlayerEngine` y `PlayerEntry` (ExoPlayer) y el SSL global.
- `player/PlayerEngine.kt` + `player/PlayerEntry.kt` (≈390 líneas que hoy viven en `MainActivity.kt:411+`).
- `device/DeviceChannel.kt` (`setupDeviceChannel`), `voice/VoiceChannel.kt` (`setupVoiceTestChannel`).
- `channels/Channels.kt` con los nombres (espejo de `platform_channels.dart`).
- `MainActivity` queda en registro + ciclo de vida (~120 líneas).

### 5.10. `LoadingScreen` (opcional, requiere aprobación)
Extraer a `BootstrapController` solo lo que no es catálogo: verificación de presencia, identidad, bloqueo y destino (`/overlap`, `/nickname_setup`, `/home`). Unificar los dos `catch` idénticos.

---

## 9. Fase 6 — Optimización e Interfaz Más Rápida

### 6.1. Menos rebuilds
- `WatchPartyProvider.loadFriends()` corre cada 15 s y siempre notifica: comparar (ids + online + canal) y notificar solo si cambió. Con Realtime activo (`_subscribeToDevicesRealtime`), bajar el polling de respaldo a 60 s.
- `context.watch` amplio → `context.select`: `watch_party_overlay.dart:177,179,228` (encima del video, prioridad), `tv_watch_party_header_bar.dart:90-91`, `home_arcade_area.dart:144`, `settings_about_panel.dart:79`, `settings_tv_panel.dart:52`, `settings_general_panel.dart:54,192,232`, `settings_agenda_panel.dart:46-47`, `calendar_events_panel.dart:463`, `calendar_subscriptions_panel.dart:43`.
- `HomeTvArea._onStateChanged` (`home_tv_area.dart:244`) arma y compara listas de ids de todos los canales en cada notificación: `channelsVersion` / `groupsVersion` / `favoritesVersion` enteros y un listener por provider.
- `LoadingScreen` (`loading_screen.dart:459`): `AnimatedBuilder` reconstruye todo a 60 fps; lo estático va al `child:` y el gradiente a su propio `RepaintBoundary`.
- `TvShortcuts.dpad` es un getter que crea un mapa nuevo en cada build → `static final`. Los `Actions(actions: {...})` de `home_tv_area.dart` pasan a campos.

### 6.2. Arranque
`main()` espera en serie dotenv → `AppConfig` → `PlayerConfig` → `ArcadePluginService.init` → `EasyLocalization` → orientación → prefs → Supabase → identidad.
- `Future.wait` para lo independiente: `AppInfo` (§2.8), `ArcadePluginService.init`, `EasyLocalization.ensureInitialized`, `AppPreferences.init`.
- Después del primer frame lo que la pantalla de carga no necesita (`ArcadePluginService.init`, `clearLegacyCache`).
- `precacheImage(fondo.png)` durante `/loading`.

### 6.3. Latencia D-pad
- `FocusRequester` cancelable (§2.10) evita que un reintento atrasado pise una navegación nueva **[verificar en dispositivo]**.
- `TvBrowserSession` (§5.4) hace instantáneo TV → Ajustes → TV (M4).
- Repeticiones de ←/→: `includeRepeats: false` deja caer las repeticiones a la navegación direccional por defecto en nodos que solo miran `KeyDownEvent` **[verificar en dispositivo]**; si se reproduce, mapear la repetición a `DoNothingAndStopPropagationIntent`.
- Acordeón (`TvAccordionRowPreview`, anima `width` y re-layoutea el contenido) **[medir primero]**: contenido con ancho final dentro de `ClipRect` + `OverflowBox`.

### 6.4. APK
- −2,3 MB por los PNG del launcher (§1.7).
- `material_symbols_icons` fuera tras §4.2.
- `flutter build apk --split-per-abi` para distribución (hoy el APK lleva `arm64-v8a`, `armeabi-v7a` y `x86_64` de `jniLibs`); el actualizador elige el APK por ABI (`Build.SUPPORTED_ABIS` vía `DeviceChannel`).
- Medir con M7.

---

## 10. Fase 7 — Documentación y Specs

- **Duplicados**: los 10 archivos de `G:\moai_func\moai\docs` son copias byte a byte de `moai3/docs`. Dejar una sola copia (en `moai3/docs`, versionada) y borrar `../docs` o reemplazarlo por un `README.md` que apunte a `moai3/docs`.
- **Separar canónico de histórico**: `specs/` es la fuente de verdad; `docs/` pasa a `docs/research/` (investigaciones) y `docs/archive/` (planes terminados o viejos):
  - Terminados/obsoletos → `archive/`: `plan_state_refactoring.md` (los providers ya existen), `Plan_Moai3_Limpieza.md` (habla de `video_player`, `google_fonts`, TvViewer legacy, que ya no están), `Plan_Implementacion_Moai3_Motor_Plugins.md`.
  - Duplicados de specs: `Contrato_Plugin_v1.md` ↔ SPEC-10, `spec_calendar_event_channel_tuning_modal.md` y `spec_lifecycle_and_sorting_sports_events.md` ↔ SPEC-35, `MANDATORY_UPDATES.md` ↔ SPEC-31. Fusionar lo que falte en la spec y archivar el doc.
  - Películas (`ESPECIFICACION_SISTEMA_PELICULAS_VOD`, `REPRODUCCION*`, `PLAN_IMPLEMENTACION_PLAY_PELICULAS`, `SEGUIR_AQUI`, `investigacion-*`): fuera de alcance, se mueven a `docs/research/movies/` sin tocar contenido.
- **Specs desactualizadas** que este plan cambia: SPEC-30 §2.1 (FocusNodes por canal), SPEC-22 (bloqueo en vivo, D-5), SPEC-34 (la voz ya no es PoC), SPEC-00 (nuevas carpetas `platform/`, `app/`, `coordinators/`), SPEC-11 (catálogo único de canales nativos).
- `specs/README.md`: índice actualizado con estas rutas.

---

## 11. Fase 8 — Regresión D-pad

Ampliar `test/home_flow_regression_test.dart` con `tester.sendKeyEvent`:
1. Rail → → en cada sección enfoca la entrada correcta.
2. Back desde contenido → rail; back desde rail (no TV) → TV; doble back → salir.
3. Long press en canal → alfabeto → letra → canal correcto; back → panel.
4. Snack con acción toma el foco y OK la ejecuta (SPEC-35/37).
5. Con `NotificationGate` suspendido no aparece ningún snack de segundo plano.
6. Invitación visible + otro snack → la invitación no se rechaza.
7. TV → Ajustes → TV conserva la posición.
8. OK con `select`, `enter`, `numpadEnter` y `gameButtonA` en cada tipo de botón.
Agregar los casos `CASO-OPT-xx` a `specs/verification/baseline_acceptance_matrix.md`.

---

## 12. Propuestas Opcionales (requieren aprobación)

- CH+/CH- (`channelUp`/`channelDown`) en el visor.
- Arranque sin red (D-4): si falla la verificación de presencia por timeout y hay canales locales, entrar a `/home` en modo limitado.

---

## 13. Decisiones Pendientes

| ID | Pregunta | Estado |
| :--- | :--- | :--- |
| D-1 | Invitación arcade durante el juego | **Decidido (2026-10-23)**: responder "ocupado" automáticamente |
| D-2 | Mantener el reproductor vivo al salir de TV | por defecto no (como hoy) |
| D-3 | Familia única de iconos | propuesta Reicons; se aprueba por tandas con capturas |
| D-4 | Arranque sin red | no por ahora |
| D-5 | Bloqueo de dispositivo en tiempo real (`watchDevice`) | **Decidido**: al instante, conectarlo |
| D-6 | Error de carga de canales y bitrate (§2.1) | **Decidido**: mostrar aviso de error de carga; **borrar** bitrate |
| D-7 | Hosts que realmente necesitan TLS permisivo (§2.2) | técnico: se relevan con los plugins instalados antes de cerrar la lista |

---

## 14. Riesgos

| Riesgo | Mitigación |
| :--- | :--- |
| Borrar algo usado por reflexión, por nombre de ruta o desde nativo | volver a buscar por string además de por identificador; correr la app en el TV tras cada PR de borrado |
| TLS estricto rompe streams de algún plugin | D-7 antes de activar; activar primero en debug con log de los hosts que fallan |
| Refactor de foco rompe flujos sutiles | Fase 8 junto a la 5; probar en el TV cada PR de foco |
| Migración `LocaleKeys` masiva choca con la rama de películas | un PR único y corto, justo después de un merge |
| Cambio de familia de iconos altera el look | tandas con capturas y aprobación |
| `TvPressDetector` cambia tiempos de long press | tiempos centralizados con los valores actuales + test de widget por tiempo |
| Specs congeladas desactualizadas | actualizarlas en el mismo PR (§10) |

---

## 15. Orden Recomendado de PRs

1. **Base**: 0.2 tests verdes → 0.3 lints y guardas → 0.1 métricas.
2. **Código muerto** (rápido, bajo riesgo): 1.2 FocusNodes → 1.3 miembros → 1.1 clases → 1.4 mocks → 1.5 iconos → 1.6 claves → 1.7 assets/deps.
3. **Lo que no anda**: 2.2 TLS (tras D-7) → 2.3 snacks → 2.5 router → 2.1 estados (tras D-5/D-6) → 2.9 errores silenciados.
4. **Centralización**: 2.6 canales nativos → 2.7 prefs → 2.8 `AppInfo` → 3.1 `LocaleKeys` → 3.2-3.6 → 4.1 → 4.3 → 4.5 → 4.2 (por tandas).
5. **Responsabilidades**: 5.1 `HomeSection` → 5.3 coordinadores (incluye 2.4 presencia) → 5.2 áreas → 2.10 `FocusRequester` → 5.4 `HomeTvArea` + `TvBrowserSession` → 2.10 `TvPressDetector` y demás unificaciones → 5.6 capas → 5.7 rutas → 5.8 bootstrap/DI → 5.9 nativo → 5.5 archivos grandes.
6. **Optimización**: 6.1 → 6.2 → 6.4; 6.3 a medida que lo habiliten 5.4 y 2.10 (lo marcado se verifica o mide primero).
7. **Docs** (Fase 7) en paralelo desde el paso 2; **regresión** (Fase 8) en paralelo desde el paso 5.
