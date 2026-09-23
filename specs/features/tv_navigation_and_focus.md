# SPEC-30: Motor de Navegación y Foco para Android TV (D-Pad)

> **Estado**: Congelado (Baseline v3.0.11)  
> **Área**: Experiencia de Usuario / Android TV  
> **Archivos de Referencia**: `lib/focus/focus_scroll_sync.dart`, `lib/focus/tv_key_handler.dart`, `lib/focus/tv_layout_constants.dart`

---

## 1. Principios de Interacción por Control Remoto

A diferencia de los dispositivos táctiles, la experiencia en Android TV depende enteramente del árbol de foco direccionable (`FocusNode` y teclado direccional / D-Pad). Los principios rectores son:

1. **Determinismo Espacial**: Las pulsaciones en el D-Pad (`ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`) deben resolver inequívocamente al elemento contiguo más predecible.
2. **Sin Foco en el Limbo**: Cuando una lista virtualizada (`ListView.builder`) hace scroll, el elemento destino debe ser visible o montado antes de solicitar el foco para evitar que Flutter pierda el nodo activo.
3. **Restauración de Posición**: Al cambiar entre paneles laterales o pestañas flotantes, el sistema recuerda el último índice enfocado en cada lista.

---

## 2. Componentes Clave del Motor de Foco

### 2.1. `FocusScrollSync`
Gestiona la sincronización entre el estado de las colecciones de datos, los controladores de scroll y la lista de `FocusNode`s:

1. **`syncFocusNodes(targetCount, nodesList)`**:
   - Ajusta dinámicamente el tamaño de la lista de nodos al número de elementos (`targetCount`).
   - Descarta y libera (`dispose()`) los nodos sobrantes para prevenir fugas de memoria.
2. **`scrollToIndex(...)`**:
   - Calcula el desplazamiento exacto multiplicando el índice por el alto del ítem (`itemHeight`).
   - Soporta modo instantáneo (`instant: true` con `jumpTo`): esencial cuando se cambia de categoría o canal por teclado rápido, pues `animateTo` tardaría ~250ms durante los cuales el widget destino aún no existe en el árbol de renderizado.
3. **`requestFocusAtIndex(nodes, index, ...)`**:
   - Intenta hacer `requestFocus()` sobre el nodo solicitado. Si el widget aún no está montado en el viewport, ejecuta un mecanismo de reintento (`SchedulerBinding.instance.addPostFrameCallback`) hasta que el contexto esté disponible.

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

---

## 3. Navegación en Pestañas Flotantes M3 Expressive

La navegación principal utiliza una barra de pestañas flotante con atajos direccionales:
- **Flecha Arriba desde la cabecera del contenido**: Salta directamente a la pestaña activa en la barra flotante.
- **Flecha Abajo desde una pestaña**: Desciende al primer elemento activo del cuerpo de la pantalla actual.
- **Flechas Izquierda / Derecha dentro de la barra**: Conmutan entre pestañas de navegación (`Canales`, `Favoritos`, `Explorar`, `Ajustes`).
