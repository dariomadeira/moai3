# SPEC-30: Motor de Navegación y Foco para Android TV (D-Pad)

> **Estado**: Congelado (Baseline v3.0.11), con agregados del 2026-11-11 (§2.1.2, §2.3)  
> **Área**: Experiencia de Usuario / Android TV  
> **Archivos de Referencia**: `lib/focus/focus_scroll_sync.dart`, `lib/focus/tv_key_handler.dart`, `lib/focus/tv_layout_constants.dart`, `lib/focus/opening_focus_guard.dart`

---

## 1. Principios de Interacción por Control Remoto

A diferencia de los dispositivos táctiles, la experiencia en Android TV depende enteramente del árbol de foco direccionable (`FocusNode` y teclado direccional / D-Pad). Los principios rectores son:

1. **Determinismo Espacial**: Las pulsaciones en el D-Pad (`ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`) deben resolver inequívocamente al elemento contiguo más predecible.
2. **Sin Foco en el Limbo**: Cuando una lista virtualizada (`ListView.builder`) hace scroll, el elemento destino debe ser visible o montado antes de solicitar el foco para evitar que Flutter pierda el nodo activo.
3. **Restauración de Posición**: Al cambiar entre paneles laterales o pestañas flotantes, el sistema recuerda el último índice enfocado en cada lista.

---

## 2. Componentes Clave del Motor de Foco

### 2.1. Listas virtuales y `FocusScrollSync`
Las listas de países, categorías, canales y grupos usan `TvWindowedList` / `TvWindowedGrid`, que crean y descartan sus propios `FocusNode` solo para los ítems visibles. Los controllers (`ChannelBrowserController`, `GroupsBrowserController`) guardan únicamente datos y selección: no tienen un nodo por canal ni `ScrollController` (SPEC-50 §1.2). Con `itemKey`, `TvWindowedList` identifica cada ítem por su identidad y no por su lugar: al aparecer o irse un ítem, los demás conservan su estado y su `FocusNode` (lo usa el Inicio, SPEC-42 §3.0.1).

`FocusScrollSync` queda para listas chicas de tamaño variable (alfabeto, favoritos del visor, resultados de búsqueda):

1. **`syncFocusNodes(targetCount, nodesList)`**: ajusta la lista de nodos al número de elementos y libera (`dispose()`) los sobrantes.
2. **`requestFocusAtIndex(nodes, index, ...)`**: hace `requestFocus()` sobre el nodo; si el widget aún no está montado, reintenta en los frames siguientes (`addPostFrameCallback`) hasta que haya contexto.
3. **`focusHorizontalItem(...)`** / **`scrollToHorizontalIndex(...)`**: barra de favoritos del visor.

### 2.1.1. `TvPressDetector`
Foco y teclas de los ítems de lista (`TvIconListCard`, `ChannelGridTile`, `NewChannelCard`):
- OK: tap al soltar; con `onLongPress`, mantener `TvTiming.longPress` (800 ms) dispara la pulsación larga y no el tap.
- ←/→: las repeticiones se bloquean; el callback devuelve si consumió la tecla.
- ↑/↓: se consumen solo si hay callback, incluidas las repeticiones.
- Al perder el foco con OK apretado se cancela la pulsación pendiente.
- El detalle de series repite estas reglas a mano en sus filas (temporadas y capítulos): OK corto al soltar, mantener 800 ms para marcar como visto, y un KeyUp sin su KeyDown (el del OK que abrió la pantalla) se ignora (SPEC-46 §3.1).

### 2.1.2. `OpeningFocusGuard` (2026-11-11)
`lib/focus/opening_focus_guard.dart`. Al abrir una pantalla deja el foco en un nodo (`target`) **hasta la primera tecla apretada**. En el TV la pantalla no deja enfocar nada adentro mientras se abre y, al terminar, le da el foco a su grupo (`FocusScope`) o a lo primero que encuentra: en los detalles quedaba en Atrás y la primera tecla se iba ahí. La guardia escucha los cambios de foco (`FocusManager`) y devuelve el foco a `target` en el cuadro siguiente; con la primera tecla apretada (`HardwareKeyboard`, sólo KeyDown y con la pantalla adelante) se apaga. Tope de 240 reintentos seguidos. La usan el detalle de películas (botón principal) y el de series (capítulos). El primer intento (reintentar durante la animación y cortar si el foco caía en Atrás) fallaba porque tomaba el foco que movía el sistema como si fuera de la persona.

### 2.2. `TvKeyHandler`
Normaliza la captura de eventos de hardware procedentes de controles remotos IR/Bluetooth y gamepads:

```dart
abstract final class TvKeyHandler {
  static KeyEventResult handleDirectional({
    required LogicalKeyboardKey key,
    VoidCallback? onLeft,
    VoidCallback? onRight,
    VoidCallback? onUp,
    VoidCallback? onDown,
  });

  static bool isActionKey(LogicalKeyboardKey key);
}
```

Teclas de acción reconocidas:
- `LogicalKeyboardKey.enter`
- `LogicalKeyboardKey.numpadEnter`
- `LogicalKeyboardKey.select` (código estándar de Android TV Remote DPad Center)
- `LogicalKeyboardKey.gameButtonA`
- `LogicalKeyboardKey.space`

### 2.3. Atrás del control y pop del sistema
En el TV, si la app **no** atiende la tecla "atrás" (`LogicalKeyboardKey.goBack`), al soltarla Android manda el pop del sistema (`popRoute` → `Navigator.maybePop`). Si una pantalla se cierra al **apretar** la tecla, el pop que llega al soltarla cierra también la de abajo. Regla: no cerrar pantallas desde la tecla `goBack`; dejar que llegue el pop y manejarlo con `PopScope(canPop: false, onPopInvokedWithResult: …)` cuando la pantalla tiene que decidir (cerrar un menú antes de salir, guardar progreso). Lo aplican el reproductor de películas y series (SPEC-44 §2.3) y la hoja de texto (`tv_text_input_sheet.dart`).

---

## 3. Navegación en Pestañas Flotantes M3 Expressive (`TvTabBar`)

La navegación en el área principal de TV organiza sus vistas mediante tres pestañas horizontales continuas:
- **Pestañas disponibles**: `Explorar` (`Icons.explore_outlined` / `Icons.explore`), `Buscar` (`Icons.search_outlined` / `Icons.search`) y `Marcadores` (`Icons.bookmarks_outlined` / `Icons.bookmarks`).
- **Flecha Arriba desde el contenido o buscador**: Salta directamente a enfocar la pestaña activa en la barra flotante.
- **Flecha Abajo desde una pestaña**: Desciende al elemento de entrada del contenido activo (`_focusActiveContent()`):
  - *Explorar*: enfoca el panel activo del acordeón (Países o Canales).
  - *Buscar*: enfoca el campo de búsqueda (`TvTextField`) o resultados.
  - *Marcadores*: enfoca el panel de grupos o canales guardados.
- **Flechas Izquierda / Derecha dentro de la barra**:
  - `Explorar`: `←` sale al Navigation Rail; `→` pasa a Buscar.
  - `Buscar`: `←` regresa a Explorar; `→` pasa a Marcadores.
  - `Marcadores`: `←` regresa a Buscar; `→` salta al Visor/Player.

*(Para especificaciones detalladas de los componentes visuales, el Navigation Rail y el diálogo continuo de PIN, consultar [SPEC-33: Componentes de Interfaz de Usuario TV](tv_ui_components_and_layout.md)).*
