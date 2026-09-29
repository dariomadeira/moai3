# SPEC-40: Matriz de Criterios de Aceptación (Baseline v3.0.14)

> **Estado**: Vigente (Baseline v3.0.14)  
> **Área**: Calidad y Verificación / Matriz de Pruebas


---

## 1. Módulo: Motor de Plugins Nativo (.dex)

### CASO-PLUG-01: Validación de Contrato al Instalar
- **Given**: Un archivo `.dex` con `minContrato = 2` y la app MoAI 3 ejecutando `CURRENT_CONTRACT = 1`.
- **When**: Se invoca el método `install` a través de `com.infomak.moai.tv/plugin`.
- **Then**: La instalación debe ser rechazada con código `CONTRACT_MISMATCH` y no agregarse al catálogo.

### CASO-PLUG-02: Sanitización de Cadenas Vacías
- **Given**: Un plugin que declara un canal con `categoria = ""` y `pais = "   "`.
- **When**: `PluginChannelCatalog` procesa la fuente para incorporarla a la app.
- **Then**: El objeto `Channel` resultante debe tener `category = "General"` y `country = "General"`, garantizando que la tarjeta visual se renderice con texto válido.

---

## 2. Módulo: Control Parental y Seguridad

### CASO-PAR-01: Estado Inicial Seguro al Iniciar la App
- **Given**: Una app con PIN parental configurado y un canal para adultos guardado como última reproducción previa.
- **When**: La aplicación se inicia desde cero (cold start).
- **Then**: `isAdultUnlocked` debe ser estrictamente `false` y el reproductor debe sintonizar el canal seguro determinado por `_findSafeFallbackChannel()`, nunca el canal adulto.

### CASO-PAR-02: Desbloqueo Efímero de Sesión
- **Given**: Una sesión bloqueada y un usuario intentando sintonizar un canal marcado con `isAdult == true`.
- **When**: Se ingresa el PIN configurado en el diálogo TV.
- **Then**: `unlockAdultForSession()` debe activarse, permitiendo reproducir el canal sin re-solicitar el PIN hasta que la app sea cerrada o se invoque `lockAdult()`.

---

## 3. Módulo: Navegación y Foco en Android TV

### CASO-NAV-01: Sin Pérdida de Foco en Desplazamiento Rápido
- **Given**: Una lista extensa de 200 canales con virtualización activa.
- **When**: El usuario mantiene presionada la flecha direccional Abajo en el control remoto para saltar 30 posiciones.
- **Then**: `FocusScrollSync.scrollToIndex` debe desplazar el viewport y garantizar mediante `requestFocusAtIndex` que el `FocusNode` del ítem 30 quede enfocado sin saltar al inicio ni caer en el limbo.

### CASO-NAV-02: Retorno a Barra de Pestañas Flotante
- **Given**: El cursor posicionado en la tarjeta de canal superior de la vista activa.
- **When**: El usuario presiona la tecla `ArrowUp`.
- **Then**: `TvKeyHandler` debe transferir el foco a la pestaña activa en la barra de pestañas flotante M3.

---

## 4. Módulo: Reproductor y Watchdog

### CASO-PLY-01: Interrupción por Watchdog ante Buffer Colgado
- **Given**: Un stream en estado `MoaiEngineState.buffering` cuya conexión TCP no envía datos.
- **When**: Transcurren 45 segundos sin emitirse `firstFrame` ni `ready`.
- **Then**: El watchdog debe forzar el paso a `MoaiEngineState.error` y permitir al orquestador solicitar reintento con `fallbackIndex = 1`.

---

## 5. Módulo: Interfaz TV, Pestañas, Rail y Diálogo PIN (SPEC-33)

### CASO-UI-01: Conmutación Outlined / Filled en Rail y Pestañas
- **Given**: Las pestañas de navegación y los destinos del Navigation Rail montados en pantalla.
- **When**: Un elemento no está seleccionado (`isSelected == false`).
- **Then**: Debe renderizar su icono con variante `_outlined`.
- **When**: El usuario selecciona el elemento (`isSelected == true`).
- **Then**: El icono debe conmutar inmediatamente a su versión `filled` / sólida.

### CASO-UI-02: Navegación Continua en Rail con Ajustes al Fondo
- **Given**: El cursor posicionado en el destino Calendario (índice 1).
- **When**: El usuario presiona `ArrowDown`.
- **Then**: El foco debe saltar directamente sobre el `Spacer()` y situarse en Ajustes (índice 2) sin perderse en el árbol de renderizado.
- **When**: Presiona `ArrowUp` desde Ajustes.
- **Then**: El foco debe regresar directamente a Calendario (índice 1).

### CASO-UI-03: Modal PIN Continuo sin Parpadeos (Zero-Flash)
- **Given**: El usuario configurando o cambiando un PIN de control parental en modo `create` o `change`.
- **When**: Completa los 4 dígitos del primer paso.
- **Then**: La pantalla transiciona al siguiente paso mediante `AnimatedSwitcher` sin cerrar la ruta modal ni provocar parpadeo (*pantallazo*).
- **When**: Los dígitos de confirmación no coinciden.
- **Then**: Los casilleros ejecutan una animación de sacudida (*shake*), se limpian y el usuario permanece dentro del modal para reintentar.

### CASO-UI-04: Área y Pestaña de Búsqueda Dedicada
- **Given**: El usuario navegando en la pestaña `Buscar`.
- **When**: Se renderiza `SearchPanel`.
- **Then**: El contenedor debe aplicar un padding horizontal simétrico de 12 dp a la izquierda y 12 dp a la derecha.
- **When**: El usuario presiona `ArrowLeft`.
- **Then**: El foco debe transferirse de forma limpia al Navigation Rail.

---

## 6. Módulo: Agenda Deportiva y Sintonización Directa (SPEC-35)

### CASO-CAL-01: Interacción No-Op en Eventos Finalizados
- **Given**: Un evento deportivo en estado `CalendarEventStatus.finished`.
- **When**: El usuario presiona `OK` / `Enter` o hace clic sobre la tarjeta del evento.
- **Then**: La acción no debe abrir ningún diálogo ni disparar sintonización (No-op), consumiendo el evento del teclado sin errores.

### CASO-CAL-02: Modal Adaptativo de Dos Columnas y Sintonización
- **Given**: Un evento deportivo en vivo cuyo emisor o ID coincide con canales instalados en `ChannelProvider`.
- **When**: El usuario presiona `OK` sobre el evento en `CalendarEventsPanel`.
- **Then**: El diálogo modal se expande a dos columnas, mostrando los datos a la izquierda y los canales coincidentes a la derecha.
- **When**: El usuario selecciona uno de los canales sugeridos con `OK`.
- **Then**: El modal se cierra de inmediato y el canal seleccionado se sintoniza en el reproductor.

### CASO-CAL-03: Cero Emojis en Títulos y Competiciones
- **Given**: Un feed de eventos deportivos remoto que contiene emojis (⚽, 🏁, etc.).
- **When**: `SportsScheduleService` o `F1CalendarService` procesa el feed.
- **Then**: Los textos resultantes en los títulos y nombres de competición deben quedar completamente limpios de caracteres emoji, representándose únicamente con iconos vectoriales de Material.

---

## 7. Módulo: Estilo de Foco en Tarjetas TV (SPEC-33)

### CASO-CARD-01: Foco con Borde Primario sin Lavado de Fondo
- **Given**: Una tarjeta de canal en la grilla (`ChannelGridTile`) o en la barra de favoritos (`ViewerFavoriteTile`).
- **When**: El elemento recibe el foco del D-Pad (`isFocused == true`).
- **Then**: Debe renderizar un borde perimetral de 2 dp con el color primario del tema (`Border.all(color: scheme.primary, width: 2)`) y preservar su fondo base, sin teñir la tarjeta con un fondo primario sólido opaco.

---

## 8. Módulo: Ciclo de Vida y Liberación Segura (SPEC-32)

### CASO-DISP-01: Descarte Seguro de Notificaciones en SafeChangeNotifier
- **Given**: Una instancia que hereda de `SafeChangeNotifier` (como `CalendarProvider`) que ha sido desmontada (`dispose()`).
- **When**: Llega un callback asíncrono tardío que invoca `notifyListeners()`.
- **Then**: La invocación no debe lanzar ninguna excepción `FlutterError` ni assertion failure, descartándose de forma segura.

### CASO-DISP-02: Cierre Defensivo de E/S en Actualizaciones
- **Given**: Una descarga de actualización en `UpdateService` interrumpida por error de red.
- **When**: Se captura la excepción de socket o timeout.
- **Then**: El bloque `finally` debe asegurar el cierre sincrónico de `IOSink` y la liberación del `HttpClient` sin dejar descriptores de archivo abiertos.

---

## 9. Módulo: Gestión de Favoritos y Botones en Cabecera (SPEC-33)

### CASO-FAV-01: Pureza del Carrusel y Botones Condicionales en Cabecera
- **Given**: Una lista de favoritos con $N$ canales instalados.
- **When**: Se renderiza `ViewerFavoritesBar`.
- **Then**: El carrusel horizontal debe contener estrictamente $N$ elementos (canales puros sin `CreateGroupTile` ni `ClearFavoritesTile`), y los botones de acción (`CreateGroupButton` y `ClearFavoritesButton`) deben renderizarse en la cabecera en forma de píldora de 44×24 dp sin bordes.
- **Given**: Una lista de favoritos vacía ($N = 0$).
- **When**: Se renderiza `ViewerFavoritesBar`.
- **Then**: `CreateGroupButton` y `ClearFavoritesButton` no deben renderizarse en el árbol de widgets.

### CASO-FAV-02: Prioridad de Foco en Botón de Corazón al Subir
- **Given**: El cursor posicionado sobre cualquier canal en el carrusel de favoritos.
- **When**: El usuario presiona la tecla `ArrowUp` en el control remoto.
- **Then**: El foco debe transferirse de forma prioritaria al botón de favorito (corazón), y desde allí permitir navegación lateral hacia el tacho de basura y el botón `+`.

---

## 10. Módulo: Fondo Ambiental y Barra de Estado TV (SPEC-33)

### CASO-BG-01: Cobertura con Degradé Diagonal y Transparencia del Rail
- **Given**: La pantalla principal de la aplicación (`HomeScreen`).
- **When**: Se construye la vista principal.
- **Then**: El fondo global debe ser un `LinearGradient` diagonal de dos colores (`topLeft` a `bottomRight`), y `NavigationRailSection` debe emplear fondo transparente (`railBg = Colors.transparent`) para evitar bloqueos rectangulares de color opaco en el borde izquierdo.

### CASO-CLK-01: Reloj Superior con Cifras Tabulares y Sin Captura de Foco
- **Given**: La barra superior a la derecha en `HomeTvArea`.
- **When**: Se renderiza `TvClockPill`.
- **Then**: Debe mostrar la hora en formato `HH:mm` sin contenedor ni iconos, cifras tabulares con fuente a 28 pt, dos puntos parpadeantes cada 1 segundo y estar envuelto en `ExcludeFocus` para que el D-Pad lo ignore en su recorrido.


