# SPEC-51 · Seguimiento de mejoras de moai3

Lista de trabajo que sale del análisis del código del **2026-11-13** (rama
`cristal`, 340 archivos, 65.500 líneas en `lib/`, 836 tests). Se sigue día a
día hasta cerrarla.

**Cómo usar este archivo**

- Cada tarea tiene un código (`R-1`, `D-3`…), su estado y el criterio para
  darla por terminada.
- Al terminar una: marcar `[x]`, poner la fecha y una línea de qué se hizo.
- Lo que se decida no hacer pasa a la sección 9, con el motivo.
- Los números de este archivo son del 2026-11-13. Antes de empezar una tarea,
  volver a contar (sección 10): pueden haber cambiado.
- El análisis fue estático (lectura del código). Nada de esto se midió en el
  TV salvo que la tarea lo diga.

**Reglas que valen para todas**

- No cambiar el diseño visual sin aprobación; las pruebas visuales las hace
  el usuario.
- No commitear sin pedido.
- `dart format` sólo sobre los archivos tocados.
- Cada tarea termina con `flutter analyze` sin errores y `flutter test` verde.
- Lo que no se pueda probar (netplay, un solo TV) se arregla igual y se avisa
  que es teórico.

---

## Tablero

| Código | Tarea | Prioridad | Estado |
|---|---|---|---|
| R-1 | Reusar el reproductor al cambiar de canal | Alta | Pendiente |
| R-2 | Apagar los logs en release | Alta | Hecho (2026-11-13), falta decisión |
| R-3 | Afinar escuchas de providers | Media | Hecho (2026-11-13) |
| R-4 | Volver a medir Impeller | Baja | Recurrente |
| R-5 | Temporizador del netplay | Baja | Pendiente |
| T-1 | Teclas multimedia del control | — | No se hace (2026-11-13): se programó y se deshizo; no es un error, es una función que no está |
| T-2 | Centralizar el manejo de teclas | Media | Empezado (PIN hecho, faltan las flechas) |
| A-1 | Partir `series_detail_screen.dart` | Alta | Pendiente |
| A-2 | Partir `home_dashboard_area.dart` | Media | Pendiente |
| A-3 | Unificar el guardado local | Media | Pendiente |
| A-4 | Interfaz que habla directo con servicios | Media | Pendiente |
| A-5 | Providers que bajan, parsean y guardan | Baja | Pendiente |
| A-6 | Colores dentro de `calendar_provider.dart` | Baja | Hecho (2026-11-13) |
| L-1 | Borrar 9 claves de traducción sin uso | — | Descartada (2026-11-13): no hay ninguna sin uso |
| L-2 | Plurales con el mecanismo del paquete | Baja | Pendiente |
| L-3 | Motivos de error sin traducir | Media | Hecho (2026-11-13): "URL vacía" centralizado; los errores crudos quedan a propósito |
| L-4 | Test guardián de claves sin uso | — | Descartada: ya existía (`translations_test.dart`) |
| D-1 | Tokens de tamaño de letra | Media | Empezado (piso hecho) |
| D-2 | Tokens de radios | Media | Pendiente |
| D-3 | Tokens de duraciones | Media | Pendiente |
| D-4 | Tokens de espaciado y transparencias | Baja | Pendiente |
| D-5 | Blancos, negros y colores fijos fuera del tema | Alta | Pendiente |
| D-6 | Pesos 800 y 900 | Baja | Hecho (2026-11-13); los 3 de 900 quedan a propósito |
| D-7 | Etiquetas de estado a 8 puntos | Media | Pendiente (necesita diseño) |
| D-8 | Etiqueta del rail | Media | Pendiente (necesita diseño) |
| D-9 | Foco de las tarjetas | Media | Pendiente (necesita diseño) |
| C-1 | Envoltorio único de foco | Baja | En pausa (2026-11-13): riesgo en el foco sin beneficio visible |
| C-2 | Una sola clase para las listas guardadas | Media | Pendiente |
| C-3 | Piezas privadas duplicadas | — | Descartada (2026-11-13): mismo nombre, piezas distintas |
| S-1 | Secretos dentro del APK | Alta | Falta decisión |
| S-2 | Certificados inválidos y tráfico sin cifrar | Media | Falta decisión |
| E-1 | `catch` vacíos | Media | Hecho (2026-11-13) |
| E-2 | Tests de las piezas grandes sin test directo | Media | Pendiente |
| E-3 | Dependencias atrasadas | Baja | Pendiente |
| E-4 | Fijar `openvpn_flutter` a un commit | Baja | En pausa: el lock ya lo fija; tocar sólo con prueba completa de VPN |

**Orden sugerido:** de lo más simple a lo más complejo, y primero lo que no
puede romper nada. C-2 y A-3 → D-1 a D-5 por secciones, con goldens → A-1 →
R-1 (el más delicado: reproductor). C-1 y E-4 en pausa. T-1 no se hace.
S-1 y S-2 esperan decisión.

---

## Por qué vale (o no) cada tarea pendiente

Pedido del usuario (2026-11-13): cada arreglo tiene que tener su porqué.
"Qué gana" es lo que cambia para quien usa la app o para quien la mantiene.

### Valen la pena

| Tarea | Qué gana | Riesgo |
|---|---|---|
| R-1 · Reusar el reproductor | Cambiar de canal más rápido: hoy cada cambio apaga y prende el motor de video. Es lo único de la lista que el usuario notaría. Cuánto gana no se sabe hasta medirlo en el TV | Alto: es la reproducción. Hacerlo con E-2 antes |
| E-2 · Tests del visor y la reproducción | Una red de seguridad: hoy un cambio puede romper el visor de TV sin que ningún test avise | Ninguno: sólo agrega tests |
| S-1 · Secretos en el APK | Que nadie saque del APK el usuario y clave del túnel, del servidor de voz y los tokens, y los use o los queme | Medio: cambia el arranque. Espera decisión |
| S-2 · Certificados | Que en una red ajena no puedan hacerse pasar por un servidor de la app | Medio: puede dejar canales sin andar. Espera decisión |
| D-7, D-8, D-9 · Etiquetas a 8 puntos, rail, foco de tarjetas | Legibilidad a distancia: son textos y marcas que hoy cuestan leer desde el sillón | Es diseño: sólo con aprobación del usuario |

### Opcionales: ordenan por dentro, no cambian nada a la vista

| Tarea | Qué gana | Riesgo |
|---|---|---|
| D-1 a D-4 · Tokens de tamaños, radios, duraciones | El próximo cambio de diseño se hace en un lugar. Ejemplo real: subir el piso de letra pidió tocar 34 textos en 24 archivos. Sólo rinde si va a haber más rediseño | Bajo si se conservan los valores exactos; si se juntan valores parecidos, cambia el diseño |
| D-5 · Colores fijos | Menos chance de un texto ilegible en modo oscuro. El guardián ya impide que aparezcan nuevos y el modo oscuro ya se revisó, así que lo que queda es probable que sea a propósito | Bajo |
| A-1, A-2 · Partir pantallas grandes | Tocar Series o el Inicio con menos chance de error: hoy son archivos de más de 1.000 y 800 líneas | Bajo si sólo se mueve código |
| C-2, A-3 · Listas guardadas y guardado local | Menos código repetido. Cuidado: si cambia el nombre con que se guarda, el usuario pierde su lista | Medio por ese motivo |
| E-3 · Dependencias | Arreglos de seguridad y compatibilidad con Flutter nuevo | Medio: probar en el TV. Nunca tocar OpenVPN (E-4) |

### No recomendadas

| Tarea | Por qué no |
|---|---|
| T-2 · Flechas centralizadas | Toca la navegación con el control, el mismo riesgo que C-1, y no cambia nada a la vista |
| A-4, A-5 · Reordenar servicios y providers | Prolijidad de arquitectura sin efecto para nadie; mucho código movido |
| L-2 · Plurales | Los textos ya salen bien; sólo cambia cómo están escritos por dentro |
| R-5 · Temporizador del netplay | No se puede probar con un solo TV. Sólo si se nota retraso jugando en red |

---

## 1. Rendimiento

La base está sana: no hay desenfoques en vivo (`BackdropFilter` 0), no hay
`Image.network`, las imágenes se decodifican al tamaño de pantalla, los
catálogos grandes se procesan en otro hilo (`Isolate.run`) y el caché de
imágenes está limitado (100 imágenes, 30 MB).

### R-1 · Reusar el reproductor al cambiar de canal — `[ ]`

- **Problema:** cada cambio de canal destruye el motor y crea uno nuevo.
  Lo mismo al reintentar y al cambiar de servidor.
- **Dónde:** `lib/widgets/player/tv_viewer.dart`, `_playChannel`:
  `await _disposeEngine()` (línea ~271) y `MoaiEngineController()` (~308).
- **Arreglo:** conservar el `MoaiEngineController` y llamar `setMedia` con
  la fuente nueva; destruirlo sólo al ir a segundo plano, al salir del visor
  o si el motor quedó en error irrecuperable. Revisar que el lado nativo
  (`lib/engine/moai_engine_player.dart` y su plugin Kotlin) acepte un segundo
  `setMedia` sobre el mismo reproductor.
- **Cuidado:** DRM (cambia `drmScheme`/`drmLicenseUri` entre canales),
  `PlaybackSessionGuard`, el watchdog del motor y el primer cuadro
  (`_hasFirstFrame` debe volver a `false` para no mostrar el canal anterior).
- **Hecho cuando:** el cambio de canal no crea un motor nuevo, los tests del
  visor pasan y se midió en el Chromecast (release) el tiempo de cambio de
  canal antes y después, en varios canales.

### R-2 · Apagar los logs en release — `[x]` 2026-11-13 (queda una decisión)

- **Problema:** 184 `debugPrint` que en release siguen escribiendo en logcat.
- **Hecho:** `AppBootstrap.silenceLogsIfPublished()` en
  `lib/app/bootstrap.dart` calla `debugPrint` en release cuando `DEBUG_MODE`
  está apagado. Test: `test/silence_logs_test.dart`.
- **Falta decidir:** el `.env` que va dentro del APK tiene `DEBUG_MODE=true`,
  así que **hoy los logs siguen prendidos**. Opciones: publicar con
  `DEBUG_MODE=false` (también apaga el panel de log de TV), o separar una
  variable sólo para los logs.

### R-3 · Afinar escuchas de providers — `[x]` 2026-11-13

- **Hecho:** la tarjeta Solicitudes del Inicio se redibuja sólo si cambian
  las solicitudes (`home_friend_requests_card.dart`); Ajustes › General y
  Descuentos › Configurar escuchan sólo el nombre del lugar del clima.
- **Revisado y sin cambios (ya estaba bien):** `WatchPartyProvider` avisa
  sólo si cambió algo visible; `home_tv_area` compara antes de redibujar;
  las tarjetas de clima y eventos del Inicio se redibujan solas.
- **Queda sin tocar a propósito:** los demás paneles de Ajustes escuchan su
  provider entero; usan casi todos los campos y están en pantalla un rato.

### R-4 · Volver a medir Impeller — recurrente

- Impeller está apagado en `AndroidManifest.xml` (33 ms por cuadro con
  Vulkan contra 11 ms con Skia en el Chromecast). La opción está deprecada.
- **Cada vez que se actualice Flutter:** medir de nuevo en el TV y anotar
  acá la versión y el resultado.

**Flutter 3.50 (salió el 2026-11-11), analizado el 2026-11-13 sin instalar
ni medir nada. Veredicto: no conviene actualizar ahora.** moai está en
3.47.8.

- *No trae mejoras de velocidad para Android.* Las del anuncio son de
  escritorio (dibujo de bordes y degradados en la GPU), iOS (un cuadro menos
  de latencia táctil) y web. Para Android no se publicó ningún número.
- *moai dibuja con Skia* (Impeller apagado) y 3.50 a Skia no le suma nada:
  casi todo lo gráfico nuevo es de Impeller.
- *Impeller sigue lento en la GPU del Chromecast.* Hay un reporte abierto,
  prioridad alta, con una Mali-G31 (la familia de GPU del Chromecast con
  Google TV): Impeller tarda el doble que Skia por cuadro (11 ms contra
  6 ms), **igual en 3.44, 3.50 beta y master**. El arreglo que entró en 3.50
  no le cambió los números. Coincide con lo medido en moai (33 ms contra
  11 ms).
- *El apagado de Impeller sigue funcionando en 3.50*, con el aviso de
  "deprecado" de siempre. Las notas de 3.50 no lo quitan en Android.
- *Costos de pasar a 3.50:* `material.dart` queda deprecado y lo importan
  240 archivos (el análisis dejaría de dar limpio hasta migrar al paquete
  `material_ui`); cambian las versiones de Gradle y del plugin de Android; y
  hay que volver a probar OpenVPN (ver E-4).
- *Lo único que podría servirle a moai:* un arreglo de una carrera al
  registrar la textura del video (#192951) y un arreglo de un cierre
  inesperado en GPU Mali (sólo con Impeller). Ninguno es un problema que
  moai tenga hoy.

**Cuándo sí actualizar:** cuando Flutter quite de verdad el apagado de
Impeller, cuando se cierre el reporte de la Mali-G31 (flutter/flutter
#195767), o cuando una dependencia o la tienda lo exijan. Y en ese caso: con
una segunda copia del SDK, sin tocar la instalada, esperando al menos el
primer parche (3.50.x), y midiendo en el Chromecast Skia contra Impeller como
la vez anterior. El emulador no sirve para esto: su GPU no se parece a la
del TV.

### R-5 · Temporizador del netplay — `[ ]`

- **Problema:** `arcade_screen.dart:143` usa `Timer.periodic` de 16 ms para
  las entradas del netplay; un `Timer` no va sincronizado con los cuadros y
  se desfasa.
- **Arreglo:** pasar a un `Ticker`. Es teórico: no se puede probar con un
  solo TV.

---

## 2. Teclas

### T-1 · Teclas multimedia del control — `[ ]`

- **Problema:** no se maneja ninguna tecla multimedia en toda la app (no hay
  ni una referencia a `mediaPlayPause`, `mediaPlay`, `mediaPause`,
  `mediaFastForward`, `mediaRewind`, `mediaStop`, `channelUp`, `channelDown`).
- **Arreglo:** en el reproductor de películas y series
  (`lib/features/movies/screens/movie_player/movie_player_keys.dart`):
  play/pausa, adelantar, retroceder, detener. En el visor de TV: canal
  arriba/abajo y play/pausa.
- **Hecho cuando:** probado en el Chromecast con el control (release).

> **No se hace (2026-11-13).** Se llegó a programar en el reproductor de
> películas y series y **se deshizo el mismo día**: el código quedó como
> estaba. Motivos: el control del Chromecast no trae estas teclas (sólo
> llegan desde el control del televisor por HDMI-CEC o desde un control con
> botones multimedia), no había forma de probarlo en el TV, y abría
> decisiones de comportamiento que el usuario no necesita tomar (qué hace
> "detener", qué lista recorre "canal siguiente"). Como estaba, andaba bien.
>
> No es un error de la app: es una función que no está. Retomar sólo si
> alguien la pide y hay un control con el que probarla. Lo que se había
> hecho, por si sirve de punto de partida: reproducir/pausar alterna,
> reproducir y pausar por separado sólo hacen lo suyo, y adelantar y
> retroceder buscan igual que → y ←.

### T-2 · Centralizar el manejo de teclas — `[ ]`

- **Problema:** las flechas se comparan a mano unas 180 veces
  (`arrowLeft` 49, `arrowRight` 45, `arrowUp` 43, `arrowDown` 43) y
  `tv_pin_input.dart:135-171` tiene diez `if` seguidos para los dígitos.
- **Arreglo:** usar `TvKeyHandler.handleDirectional` (ya existe en
  `lib/focus/tv_key_handler.dart`) donde hoy se compara a mano, y un mapa
  tecla → dígito para el PIN.
- **Hecho (2026-11-13), la parte del PIN:** los diez `if` de
  `tv_pin_input.dart` pasaron a una búsqueda en dos listas (`_pinDigitOf`).
  Test nuevo para el teclado numérico en `test/tv_pin_dialog_test.dart`.
- **Falta:** las flechas.

---

## 3. División de responsabilidades

### A-1 · Partir `series_detail_screen.dart` — `[ ]`

- **Problema:** 1.175 líneas; `SeriesDetailScreenState` va de la línea 71 a
  la 1125 en un solo archivo, sin `part`.
- **Arreglo:** igual que `movie_player_screen.dart` (ya partido en
  `movie_player/…`): separar carga de temporadas y capítulos, teclas y foco,
  recomendaciones, y las vistas (`_SeasonPill`, `_EpisodeTile`).
- **Hecho cuando:** ningún archivo pasa de ~450 líneas y los goldens
  `serie_detalle` no cambian.

### A-2 · Partir `home_dashboard_area.dart` — `[ ]`

- **Problema:** 795 líneas; `HomeDashboardAreaState` ocupa unas 600.
- **Arreglo:** ya tiene `dashboard/home_dashboard_items.dart`; seguir por
  ese camino con los oyentes de servicios y la navegación entre tarjetas.

### A-3 · Unificar el guardado local — `[ ]`

- **Problema:** 49 llamadas a `SharedPreferences.getInstance` en 18
  archivos, aunque existe `AppPreferences`. Los que más:
  `discounts_service.dart` (7), `series_watch_service.dart` (7),
  `movie_progress_service.dart` (5), `moiamov_session.dart` (4).
- **Arreglo:** que los servicios reciban `AppPreferences` (o una interfaz
  mínima de leer/escribir) en vez de pedir la instancia. Ayuda a los tests.

### A-4 · Interfaz que habla directo con servicios — `[ ]`

- **Problema:** 61 de 229 archivos de interfaz importan servicios. Conviven
  dos modelos: providers y singletons `.instance`
  (`MovieWatchlistService` 19 usos, `SeriesWatchlistService` 19,
  `MoiamovApiService` 18, `ArcadeNetplayService` 17, `ModalRouteTracker` 15).
- **Arreglo:** por secciones, empezando por Películas y Series: pasar las
  listas guardadas a providers del árbol, como ya está `ArcadeNetplayService`.
  No hace falta hacerlo todo: cortar donde deje de simplificar.

### A-5 · Providers que bajan, parsean y guardan — `[ ]`

- **Dónde:** `weather_provider.dart`, `home_trailers_provider.dart`,
  `movie_recommendations_provider.dart` hacen la red, el parseo y el caché
  en el mismo archivo.
- **Arreglo:** mover red y caché a un servicio o repositorio (como
  `lib/data/repositories/`), y dejar en el provider sólo el estado.

### A-6 · Colores dentro de `calendar_provider.dart` — `[x]` 2026-11-13

Los 6 colores por deporte pasaron tal cual (mismos valores) a
`lib/theme/moai_sport_colors.dart` (`MoaiSportColors.of`). Los usan igual
que antes Agenda › Suscripciones, la ficha de evento de la grilla y la
tarjeta de eventos del Inicio. El diseño no cambia: los goldens pasan sin
regenerar. Se actualizó la lista de `test/hardcoded_colors_test.dart`.

---

## 4. Traducciones

Ya están centralizadas y vigiladas por `test/translations_test.dart`: 920
claves (919 al momento del análisis) en `assets/translations/es.json`, todas
con su constante en `locale_keys.g.dart`, y no hay textos visibles escritos
a mano en la interfaz (sólo líneas de log y nombres de juegos).

### L-1 · Borrar 9 claves sin uso — descartada (2026-11-13)

El análisis las dio por no usadas por error: las nueve se usan, pero el
formateador las parte en dos renglones (`LocaleKeys` arriba y `.clave`
abajo) y la búsqueda sólo miraba `LocaleKeys.clave` en un mismo renglón.
Recontado bien: **0 claves sin uso**. No hay nada que borrar.

### L-2 · Plurales con el mecanismo del paquete — `[ ]`

- **Problema:** 24 claves de plural hechas a mano, con sufijos mezclados
  (`_one`, `_single`, `_singular`, `_plural`, `_zero`, `_two`, `_multiple`).
- **Arreglo:** pasarlas a `plural()` de `easy_localization`, o al menos
  dejar un único sufijo.

### L-3 · Motivos de error sin traducir — `[x]` 2026-11-13 (parte)

- **Confirmado:** el motivo llega a pantalla. Al agotar los servidores,
  `reconnection_coordinator.dart` muestra "No se pudo conectar… · motivo".
- **Hecho:** `'URL vacía'` (dos lugares de `tv_viewer.dart`) pasó a la clave
  nueva `player_error_empty_url`, con el mismo texto: en pantalla se ve
  igual.
- **Queda como está, a propósito:** `'resolve: $e'` y `'$e'` muestran el
  error crudo. Es la misma regla que ya usa `friendlyPlaybackError` (lo que
  no reconoce, lo muestra tal cual) y sirve para diagnosticar en el TV.
  Si algún día se quiere prolijo: pasarlos por `friendlyPlaybackError`, que
  ya traduce 401/403, geobloqueo y DRM.

### L-4 · Test guardián de claves sin uso — descartada: ya existía

`test/translations_test.dart` (SPEC-50 §3.6) ya vigila todo esto y más: que
`LocaleKeys` esté sincronizado con el json, que no haya claves sin uso
(contempla el salto de renglón del formateador), que no se traduzca con
literales, que el json esté ordenado y que no haya textos de interfaz
escritos a mano. El análisis no lo había visto. El test que se había sumado
el 2026-11-13 (`unused_translations_test.dart`) era un duplicado y se borró.

**Al agregar un texto:** va en `es.json` en orden alfabético y su constante
en `lib/l10n/locale_keys.g.dart` (o regenerar con
`dart run easy_localization:generate -f keys -o locale_keys.g.dart -S assets/translations -O lib/l10n`).

---

## 5. Diseño

### D-1 · Tokens de tamaño de letra — empezado

- **Hecho (2026-11-13):** piso `MoaiText.sizeCaption` 12 y `sizeDense` 11;
  fuente Quicksand.
- **Falta:** 168 `fontSize:` con número suelto contra 33 con token.
  Reparto: 12 ×53, 13 ×46, 14 ×21, 18 ×12, 12,5 ×11, 11 ×5, 10 ×3, 15 ×3,
  16 ×3, 22 ×2, 28 ×2 y sueltos (8, 9,5, 13,5, 19, 20, 26, 40).
- **Arreglo:** una escala corta en `MoaiText` (por ejemplo 12 / 13 / 14 / 16
  / 18 / 22 / 28) y migrar por secciones. Decidir qué pasa con 12,5 y 13,5.
- **Los que más tienen:** `movie_player_osd.dart` (13), `update_dialog.dart`
  (9), `gamepad_config_columns.dart` (7).

### D-2 · Tokens de radios — `[ ]`

65 radios sueltos con 16 valores distintos: 999 ×12, 16 ×10, 20 ×8, 2 ×5,
10 ×4, 14 ×4, 5 ×4 (escrito `5` y `5.0`), 4 ×3, 8 ×3, 12 ×3, 15 ×3, 6 ×2,
100 ×2, 1, 9. Proponer 4 o 5 tokens (pastilla, tarjeta, ficha, chico) y
revisar a ojo los que cambian (9 → 8 o 10, 15 → 14 o 16).

### D-3 · Tokens de duraciones — `[ ]`

106 `Duration(milliseconds: n)` con 30 valores distintos. Para lo mismo
conviven 150 ×12, 200 ×12, 180 ×10, 120 ×8, 220 ×7. Proponer 3 o 4 tokens
(rápida, normal, lenta, entrada de pantalla). `loading_boot.dart` (8) y
`movie_player_screen.dart` (5) son tiempos de lógica, no de animación: no
van a tokens de diseño.

### D-4 · Tokens de espaciado y transparencias — `[ ]`

- Separadores `SizedBox`: 318, dominan 8 ×58, 12 ×52, 6 ×48, 10 ×46, con
  sueltos (3, 5, 9, 22, 38).
- Transparencias: 144 usos con 35 valores distintos.
- Es la de menor retorno: hacerla al final y sólo si D-1 a D-3 salieron bien.

### D-5 · Blancos, negros y colores fijos fuera del tema — `[ ]`

- **Problema:** fuera de `lib/theme/` hay 91 `Color(0x…)`, 96
  `Colors.white` y 27 `Colors.black`. Cada uno es un posible error en modo
  oscuro o claro.
- **Los que más tienen:** `gamepad_config_columns.dart` (8),
  `movie_player_screen.dart` (7), `channel_source_tag.dart` (6),
  `calendar_provider.dart` (6), `tv_movie_card.dart` (4),
  `discount_format.dart` (4).
- **Arreglo:** revisar uno por uno. Los que van sobre video o sobre una foto
  (reproductor, tarjetas con póster) son blancos a propósito y se quedan,
  con un comentario. El resto pasa a `ColorScheme` o `MoaiPalette`.
- **No tocar:** las etiquetas de fuente de los canales, que son sólidas a
  propósito.
- **Ya hay un guardián** (el análisis no lo había visto):
  `test/hardcoded_colors_test.dart` tiene la lista de cuántos colores fijos
  se permiten por archivo y falla si aparece uno nuevo o si la lista quedó
  vieja. O sea que no pueden crecer; esta tarea es bajar esa lista, archivo
  por archivo, y bajar el número ahí cada vez.
- **Regla del usuario (2026-11-13):** el diseño tiene que quedar como está.
  Un color que se usa se conserva con su valor exacto; sólo se mueve de
  lugar.

### D-6 · Pesos 800 y 900 — `[x]` 2026-11-13

- **Medido** con la fuente real (un test temporal, ya borrado): Quicksand a
  800 se dibuja **idéntico** a 700 (0 píxeles de diferencia). A 900 **no**:
  Flutter lo engrosa artificialmente (mismo ancho, trazo más gordo).
- **Hecho:** los 16 `w800` pasaron a `w700` (15 en `lib/` y uno en
  `test/goldens/theme_golden_test.dart`); en 5 lugares el peso quedó igual al
  de fábrica de `MoaiText.display` y se quitó. Los goldens pasan sin
  regenerar: no cambió nada en pantalla.
- **Quedan a propósito los 3 `w900`:** el día de hoy en la grilla semanal
  (`tv_week_grid.dart:91` y `:101`) y el número de capítulo o temporada ya
  visto (`series_detail_screen.dart`, `_numberStyle`). Se ven más gruesos
  que 700 y bajarlos cambiaría el diseño. Ojo: ese grosor es sintético, no
  un peso real de la fuente; si algún día se quiere prolijo, hay que sumar
  un archivo de peso mayor o marcar "hoy" y "visto" de otra forma.

### D-7 · Etiquetas de estado a 8 puntos — `[ ]` necesita diseño

`MoaiStatusTag` chico y `TvWeekStatusChip` siguen en 8: van en una fila con
`FittedBox` y agrandarlos achica toda la fila. Hace falta rediseñar la
cabecera de la ficha. También quedó chico el comercio en la tarjeta de
Descuentos del Inicio (9,5).

### D-8 · Etiqueta del rail — `[ ]` necesita diseño

Pendiente del análisis anterior, sin empezar.

### D-9 · Foco de las tarjetas — `[ ]` necesita diseño

Pendiente del análisis anterior. Hacerla junto con C-1. Hoy la escala al
enfocar es 1,03 en un lugar y 1,08 en otros.

---

## 6. Reutilización de componentes

### C-1 · Envoltorio único de foco — en pausa (2026-11-13)

> **En pausa por decisión conjunta.** El foco anda bien hoy y esta tarea no
> le da nada al usuario: sólo ordena código. Los 29 widgets no son iguales
> (unos escuchan el nodo a mano y se vuelven a suscribir si cambia, otros
> reciben el aviso de `TvPressDetector`, otros crean su propio nodo), así
> que un envoltorio único tendría que cubrir todas las variantes y un
> descuido rompe la navegación con el control, que es lo más delicado de la
> app y lo que los tests cubren peor.
>
> **No migrar en masa.** Si algún día se retoma: crear el envoltorio y usarlo
> sólo en widgets nuevos, o en uno existente cuando ya haya que tocarlo por
> otro motivo, de a uno y con prueba en el TV. El foco de las tarjetas (D-9)
> no depende de esto.

- **Problema:** 29 widgets repiten el mismo código para saber si tienen
  foco (un `bool _focused` o `_isFocused`, escuchar el nodo, `setState`).
- **Dónde:** botones (`tv_back_pill`, `tv_glass_icon_pill`,
  `tv_icon_action_button`, `server_skip_button`), tarjetas
  (`channel_grid_tile`, `new_channel_card`, `tv_group_tile`,
  `alphabet_letter_card`, `tv_movie_card`, `tv_movie_hero_card`), tarjetas
  del Inicio (`home_friends_card`, `home_discounts_card`,
  `home_friend_requests_card`), diálogos (`tv_dialog`, `friend_tile`,
  `request_tile`), `tv_tile`, `tv_m3`, `tv_panel_header`, `tv_tab_bar`,
  `tv_vertical_nav_rail`, `tv_text_field` y otros.
- **Arreglo:** un `TvFocusBuilder(focusNode, builder: (context, focused))`
  en `lib/widgets/tv_common/`, y migrar de a un grupo por vez.
- **Hecho cuando:** los 29 lo usan (o está anotado por qué alguno no) y los
  goldens no cambian.

### C-2 · Una sola clase para las listas guardadas — `[ ]`

`movie_watchlist_service.dart` (78 líneas) y `series_watchlist_service.dart`
(110) tienen la misma interfaz: `contains`, `ensureLoaded`, `toggle`,
`remove`, `clear`, `_load`, `_save`. Sacar una clase genérica. Va de la mano
con A-3.

### C-3 · Piezas privadas duplicadas — descartada (2026-11-13)

Revisados los cinco pares: comparten el nombre pero **ninguno es un
duplicado**. El análisis los contó sólo por el nombre.

| Nombre | Una | La otra |
|---|---|---|
| `_DayColumn` | Agenda: columna de un día con sus eventos | Tarjeta de Descuentos del Inicio: un día con su mejor descuento |
| `_ProgressBar` | Diálogo de actualización: barra de descarga | Tarjeta de película: barrita de lo visto sobre el póster |
| `_FriendTile` | Modal de amigos: con foco propio, OK y OK mantenido | Tarjeta Amigos del Inicio: sólo se dibuja |
| `_RequestTile` | Modal de amigos: aceptar y rechazar | Tarjeta Solicitudes del Inicio: sólo se dibuja |
| `_Message` | Buscador de películas: ícono y texto centrados | Tarjeta de Descuentos: una línea de texto |

Lo que sí era compartible ya lo está: Agenda y Descuentos usan las dos
`TvWeekDayColumn`. Unificar las fichas del modal con las del Inicio sería
forzado (unas manejan el control, las otras no) y arriesga el diseño.

No se renombran: son clases privadas, cada una vive sólo en su archivo, y el
renombrado no cambia nada para el usuario.

---

## 7. Seguridad (esperan decisión del usuario)

### S-1 · Secretos dentro del APK — falta decisión

- **Problema:** `.env` se empaqueta como asset (`pubspec.yaml`) con 23
  claves, entre ellas `TUNNEL_USER`/`TUNNEL_PASS`, `TURN_USER`/`TURN_PASS`,
  `MOIAMOV_PORTAL_KEY`, `MOIAMOV_DEFAULT_USER_TOKEN`,
  `MOIAMOV_DEVICE_CIPHER_KEY`, `TMDB_API_KEY`, `WEATHER_API_KEY`. Quien abra
  el APK las lee en texto plano. (El archivo sí está en `.gitignore`.)
- **Opciones:** (a) dejarlo así, sabiendo el riesgo; (b) entregarlas desde
  un servidor propio después de identificar el dispositivo (Supabase ya
  está); (c) ofuscarlas, que sólo lo hace más incómodo, no seguro.

### S-2 · Certificados inválidos y tráfico sin cifrar — falta decisión

- **Problema:** `BadCertHttpOverrides` (`lib/app/bootstrap.dart`) acepta
  certificados inválidos en todo host que no esté en `kStrictSslHosts`, y el
  manifiesto tiene `usesCleartextTraffic="true"`.
- **Por qué está:** streams, logos y scrapers con certificados rotos.
- **Opción:** invertir la lista (estricto por defecto, permisivo sólo en los
  hosts de streams conocidos). Puede romper canales: probar con el catálogo
  real.

---

## 8. Robustez y mantenimiento

### E-1 · `catch` vacíos — `[x]` 2026-11-13

Había 20 `catch (_) {}`; quedan 0. Ninguno cambió de comportamiento (el
error se sigue ignorando), sólo deja rastro o explica por qué no:

- **Ahora dejan una línea en el log (13):** desconexión de la VPN al fallar
  el arranque (`loading_boot.dart`, 2) y al cancelar (`vpn_service.dart`,
  2); progreso guardado ilegible (`movie_progress_service.dart`,
  `series_watch_service.dart`); `seek`, `playerOperation`, `playerEvent` y
  `stopProgram` de Ranger; `pause`, `resume`, `reset` y `stop` del emulador.
- **Con comentario, sin log a propósito (7):** los que corren en cada
  vuelta y llenarían el log (`playBuffer` de Ranger, la entrada del juego en
  red, el sondeo de posición del reproductor), los cierres de conexiones
  (`moiamov_api_service.dart`, 2) y el guardado de la sesión
  (`moiamov_session.dart`).

**Observación sin tocar:** en `moiamov_session.dart` el `try` no llega a
atrapar un fallo del guardado, porque el guardado corre después (no se
espera). Hoy no molesta; anotado por si se toca esa parte.

### E-2 · Tests de las piezas grandes sin test directo — `[ ]`

Por nombre de archivo, ningún test menciona: `tv_windowed_grid.dart` (493
líneas), `moiamov_playback.dart` (492), `tv_viewer.dart` (429),
`moiamov_session.dart` (332), `loading_boot.dart` (344). La búsqueda es por
nombre: los archivos `part` pueden estar cubiertos desde su archivo padre,
confirmar antes de escribir tests. `tv_viewer.dart` conviene cubrirlo antes
de hacer R-1.

### E-3 · Dependencias atrasadas — `[ ]`

`flutter pub outdated` marca 33 paquetes con versión nueva que las
restricciones actuales no dejan tomar. Revisar de a uno, con la suite verde
y una prueba en el TV; medir Impeller si sube Flutter (R-4).

### E-4 · Fijar `openvpn_flutter` a un commit — `[ ]`

`pubspec.yaml` apunta a la rama `android_16kb` del repositorio.

**Revisado el 2026-11-13, sin tocar nada:** el riesgo es menor de lo que
decía el análisis. `pubspec.lock` (que está en git) ya fija el commit
`44b2bf02769982dafef4ad369ded2c807ad4f16f`, y la rama hoy apunta a ese mismo
commit. Mientras nadie corra `flutter pub upgrade`, el build no se mueve.

**Cuidado (aviso del usuario):** esta dependencia ya dio errores antes y hubo
que ir a ese commit a propósito. Si algún día se cambia el `ref`:

- poner exactamente ese hash, no otro;
- comprobar que `resolved-ref` en `pubspec.lock` no cambia;
- probar en el Chromecast, en release: arranque con VPN, conexión del túnel,
  reproducción de una película y de un capítulo, y reconexión al volver de
  segundo plano.

Nunca correr `flutter pub upgrade` sin revisar después esa línea del lock.

---

## 9. Decidido no hacer

| Qué | Motivo |
|---|---|
| Títulos con degradado: `ShaderMask` → `foreground` | Decidido en la limpieza del 2026-11-11 |
| Unificar los botones circulares | Decidido en la limpieza del 2026-11-11 |
| Pasar a cristal las etiquetas de fuente de los canales | Son sólidas a propósito |
| Ficha unificada en la cabecera de TV | Se rechazó; título y píldoras van sueltos |
| Acortar la espera de la carga inicial del catálogo | Es intencional |
| Juntar los dos temporizadores de Agenda | No son duplicados: el del panel (30 s) refresca "en vivo / en X minutos", el del provider (60 s) el resumen del Inicio |
| `select` en `WatchPartyProvider`, `ChannelProvider`, clima y eventos del Inicio | Ya avisan sólo cuando cambia algo visible (ver R-3) |

---

## 10. Cómo volver a contar

Desde la raíz del proyecto, con `rg` (ripgrep). Sumar excluyendo
`locale_keys.g.dart`.

| Qué | Patrón |
|---|---|
| Tamaños de letra sueltos | `rg -c "fontSize:\s*\d" lib` |
| Radios sueltos | `rg -c "Radius\.circular\(\s*\d" lib` |
| Duraciones sueltas | `rg -c "Duration\(milliseconds:\s*\d" lib` |
| Colores fijos fuera del tema | `rg -c "Color\(0x" lib -g "!lib/theme/**"` |
| Blancos y negros fijos | `rg -c "Colors\.(white|black)" lib -g "!lib/theme/**"` |
| Widgets con foco propio | `rg -l "bool _(focused|isFocused|hasFocus)\b" lib` |
| Guardado local directo | `rg -c "SharedPreferences\.getInstance" lib` |
| `catch` vacíos | `rg -n "catch\s*\(_\)\s*\{\s*\}" lib` |
| Teclas multimedia | `rg -n "LogicalKeyboardKey\.(media|channel)" lib` |
| Logs | `rg -c "debugPrint\(" lib` |

---

## 11. Bitácora

| Fecha | Qué se hizo |
|---|---|
| 2026-11-13 | Análisis general. Piso tipográfico y Quicksand (D-1, parcial). R-2 y R-3. Se crea este archivo. Todo sin commit. |
| 2026-11-13 | L-4 hecho (test guardián de traducciones). L-1 descartada: era un error del análisis, no hay claves sin uso. |
| 2026-11-13 | E-4 en pausa (el lock ya fija OpenVPN). D-6 hecho: 800 → 700 sin cambio visual; los 900 se quedan. |
| 2026-11-13 | A-6 hecho (colores por deporte al tema, mismos valores). E-1 hecho (20 `catch` vacíos → 0). 839 tests, goldens sin regenerar. |
| 2026-11-13 | L-3 hecho ("URL vacía" a clave). T-2: PIN hecho. L-4 descartada: el guardián ya existía; se borró el test duplicado. 837 tests. |
| 2026-11-13 | C-3 descartada: los cinco pares comparten nombre pero dibujan cosas distintas. Sin cambios de código. |
| 2026-11-13 | C-1 en pausa (riesgo en el foco sin beneficio visible). T-1: se programó y se deshizo; queda como "no se hace". 837 tests. |
| 2026-11-13 | **Criterio del usuario:** este archivo es para arreglar y ordenar lo que hay, sin cambiar cómo se comporta ni cómo se ve. Las funciones nuevas no entran salvo que las pida. |
| 2026-11-13 | **Lección del día:** el análisis no vio tres guardianes que ya existían (`translations_test.dart`, `hardcoded_colors_test.dart`, `unused_assets_test.dart`). Antes de empezar una tarea, buscar en `test/` si ya hay algo que la cubra. |
