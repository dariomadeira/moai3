# SPEC-33: Componentes de Interfaz de Usuario TV, Pestañas, Rail y Diálogos

> **Estado**: Vigente (MoAI 3)  
> **Área**: Experiencia de Usuario / Interfaz Android TV (M3 Expressive)  
> **Archivos de Referencia**:  
> - `lib/features/home/widgets/navigation_rail_section.dart`  
> - `lib/features/home/widgets/tv_tab_bar.dart`  
> - `lib/features/search/widgets/search_panel.dart`  
> - `lib/widgets/lists/tv_windowed_list.dart`  
> - `lib/widgets/dialogs/tv_pin_dialog.dart`  
> - `lib/layout/tv_panel_layout.dart`  

---

## 1. Principios de Diseño Visual M3 Expressive para TV

1. **Colores 100% Sólidos**:
   - En Android TV, el uso de alphas y opacidades dinámicas provoca artefactos de compresión y reduce el contraste en paneles OLED y LCD.
   - Todos los contenedores, botones, píldoras y badges deben emplear tokens de color completamente opacos extraídos de `ColorScheme` (`surface`, `surfaceContainerHigh`, `primary`, `onPrimary`, `tertiaryContainer`, `outlineVariant`, etc.).
2. **Iconografía Outlined vs. Filled por Estado**:
   - En estado de reposo / inactivo, todos los iconos deben ser de tipo `_outlined`.
   - Cuando un elemento está seleccionado o marcado (`isSelected == true`), conmuta al icono relleno (`filled` / `full`).
3. **Determinismo D-Pad en Pantallas Grandes**:
   - La disposición espacial de los elementos no puede depender del motor de búsqueda heurística de foco de Flutter cuando hay separaciones grandes o saltos de layout (como `Spacer()`). La navegación debe ser guiada por manejadores de eventos direccionales programáticos.

---

## 2. Barra Lateral de Navegación (`NavigationRailSection`)

### 2.1. Estructura y Distribución Vertical
- La barra lateral se ubica a la izquierda de la pantalla en un ancho constante de 72 dp.
- Contiene tres destinos principales:
  1. **TV (Índice 0)**: `Icons.tv_outlined` (inactivo) / `Icons.tv` (seleccionado).
  2. **Calendario (Índice 1)**: `Icons.calendar_month_outlined` (inactivo) / `Icons.calendar_month` (seleccionado). Incluye badge de eventos en vivo o de hoy (`tertiaryContainer`).
  3. **Ajustes (Índice 2)**: `Icons.settings_outlined` (inactivo) / `Icons.settings` (seleccionado).
- **Anclaje Inferior de Ajustes**:
  - Los destinos 0 y 1 se agrupan en la parte superior.
  - Se intercala un widget `Spacer()` flexible que empuja el destino 2 ("Ajustes") hacia la parte inferior de la pantalla.
  - Para evitar que el D-Pad de Android TV pierda el foco al intentar saltar el `Spacer()`, la navegación vertical se intercepta en `onKeyEvent`:
    - `ArrowDown`: `0 -> 1 -> 2` (salto directo a Ajustes).
    - `ArrowUp`: `2 -> 1 -> 0` (salto directo a Calendario).
  - Al pulsar `ArrowRight` desde el rail, el foco se transfiere directamente al contenido activo del área seleccionada.

---

## 3. Pestañas de Navegación en el Área TV (`TvTabBar`)

### 3.1. Trilogía de Pestañas Flotantes
El área principal de TV organiza sus flujos en tres pestañas horizontales continuas:
1. **Explorar (`explore`)**:
   - Icono inactivo: `Icons.explore_outlined`.
   - Icono marcado: `Icons.explore`.
2. **Buscar (`search`)**:
   - Icono inactivo: `Icons.search_outlined`.
   - Icono marcado: `Icons.search`.
3. **Marcadores (`groups`)**:
   - Icono inactivo: `Icons.bookmarks_outlined`.
   - Icono marcado: `Icons.bookmarks`.

### 3.2. Navegación D-Pad entre Pestañas
- **Movimiento Lateral Horizontal**:
  - `Explorar`: `←` sale al Navigation Rail; `→` pasa a Buscar.
  - `Buscar`: `←` regresa a Explorar; `→` pasa a Marcadores.
  - `Marcadores`: `←` regresa a Buscar; `→` salta al Visor/Player.
- **Descenso al Contenido**:
  - Al presionar `ArrowDown` desde cualquier pestaña, se liberan los nodos de las pestañas (`unfocus()`) y se transfiere el foco al punto de entrada natural del contenido activo (`_focusActiveContent()`):
    - En *Explorar*: al panel activo del acordeón (Países o Canal).
    - En *Buscar*: al campo de entrada o resultados de búsqueda.
    - En *Marcadores*: a la lista de grupos o canales guardados.

---

## 4. Descongestión del Acordeón y Área de Búsqueda Dedicada

### 4.1. Acordeón de Explorar (`TvAccordionRow` & `TvPanelLayout`)
- El panel de búsqueda fue extraído del acordeón horizontal de *Explorar*, reduciendo su número de paneles de 4 a 3 canónicos:
  - **Índice 0**: `Países` (`CountryListPanel`) [o `Log` si debug está activo].
  - **Índice 1**: `Categorías` (`CategoryListPanel`).
  - **Índice 2**: `Canales` (`ChannelListPanel`).
- Al pulsar `ArrowLeft` en el primer panel de Explorar (`Países`), el foco sale directamente al Navigation Rail (`widget.onExitLeft()`).

### 4.2. Área de Búsqueda Dedicada (`SearchPanel`)
- Al activar la pestaña `Buscar`, el área interactiva izquierda monta a ancho completo el `SearchPanel`.
- **Simetría Visual de Padding**:
  - El contenedor principal de búsqueda aplica un padding horizontal estrictamente simétrico de **12 dp a la izquierda y 12 dp a la derecha** (`padding: EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 8)`), eliminando asimetrías con el teclado virtual y las tarjetas de canal.
- **Atajos y Retorno D-Pad**:
  - `ArrowUp` desde el campo de texto o el primer resultado: enfoca la pestaña "Buscar" en `TvTabBar`.
  - `ArrowLeft`: sale al Navigation Rail.
  - `ArrowRight`: enfoca el visor / reproductor a la derecha.
  - Pulsación larga o atajo alfabético: despliega el panel de salto rápido (`AlphabetJumpPanel`), retornando con la tecla `Back` al listado filtrado.

---

## 5. Indicadores de Scroll y Listas Virtualizadas (`TvWindowedList`)

- **Respiración y Separación de Dots**:
  - En listas con `showScrollDots = true`, la separación horizontal entre el viewport de tarjetas y la columna de puntos de desplazamiento es de **10 dp** (`SizedBox(width: 10)`), con padding derecho de 4 dp.
  - Los puntos inactivos utilizan el color plano de alto contraste `scheme.outlineVariant` (sin transparencias alpha), y el punto activo utiliza `scheme.primary`.

---

## 6. Diálogo de PIN Parental Continuo (`TvPinDialog`)

### 6.1. Flujo Multi-Paso sin Parpadeos (Zero-Flash Modal)
- Anteriormente, las secuencias de verificación o creación de PIN abrían y cerraban rutas modales (`showGeneralDialog`), causando parpadeos de la pantalla y pérdida momentánea de foco en TV.
- El nuevo `TvPinDialog` opera como una **máquina de estados interna continua**:
  - Modos soportados: `verify` (1 paso), `create` (2 pasos: crear y confirmar), `change` (3 pasos: verificar actual, crear nuevo y confirmar).
  - La transición entre pasos se ejecuta mediante un `AnimatedSwitcher` interno sin cerrar el diálogo ni destruir la barrera modal oscura.
- **Animación de Error (Shake)**:
  - Si el PIN ingresado no coincide o es inválido, los casilleros del PIN ejecutan una sacudida horizontal de 5 oscilaciones (`_PinShakeCurve`), limpian el búfer y reubican el foco en el teclado sin abortar el flujo.
- **Teclado Numérico Determinista 4x3**:
  - Disposición en matriz fija para control remoto:
    - Fila 0: `1`, `2`, `3`
    - Fila 1: `4`, `5`, `6`
    - Fila 2: `7`, `8`, `9`
    - Fila 3: `⌫` (Borrar), `0`, `✕` (Cancelar)
  - La navegación direccional está programada en `_moveFocus(row, col, dRow, dCol)` garantizando que el D-Pad nunca pierda la posición entre botones con iconos o números.
- **Badge de Paso**:
  - En flujos multi-paso, el indicador "Paso X de Y" se presenta en una píldora con fondo sólido `scheme.tertiaryContainer`, texto `scheme.onTertiaryContainer` y estrictamente sin bordes.

---

## 7. Estilizado de Foco en Tarjetas de Canales y Favoritos (`ChannelGridTile` y `ViewerFavoriteTile`)

### 7.1. Principio de Foco con Borde Primario (Anti-Washout)
- En versiones anteriores, al enfocar una tarjeta de canal en Android TV, el fondo conmutaba a un color sólido `scheme.primary`. Esto provocaba un efecto agresivo de bloque opaco (*washout*) que ocultaba el contraste de los logotipos transparentes y los textos secundarios.
- La solución canónica implementada preserva el fondo base del elemento (`baseStyle.backgroundColor`) y aplica un borde perimetral de **2 dp con el color primario del tema** (`Border.all(color: scheme.primary, width: 2)`):
  ```dart
  final isFocused = _isFocused || (widget.focusNode?.hasFocus ?? false);
  final baseStyle = TvListCardStyle.resolve(
    scheme: scheme,
    focused: false,
    selected: widget.isSelected,
  );
  final itemStyle = isFocused
      ? TvListCardStyle(
          backgroundColor: baseStyle.backgroundColor,
          foregroundColor: baseStyle.foregroundColor,
          iconColor: baseStyle.iconColor,
          fontWeight: FontWeight.w700,
          border: Border.all(color: scheme.primary, width: 2),
        )
      : baseStyle;
  ```

### 7.2. Paridad Visual entre Grilla y Barra de Favoritos
- **Canales en Grilla 2 Columnas (`ChannelGridTile`)**:
  - Borde `scheme.primary` de 2 dp al enfocar.
  - Radio de curvatura `BorderRadius.circular(12)`.
  - Contenedor de logo con fondo transparente (`TvListCardLeadingLogo`) evitando recuadros anidados artificiales.
  - Duración de animación de 120 ms para respuesta ultra-rápida ante el D-pad.
- **Canales en Barra de Favoritos (`ViewerFavoriteTile`)**:
  - Aplica exactamente la misma lógica de `baseStyle` y `itemStyle` con borde `scheme.primary` al enfocar.
  - Radio de curvatura `BorderRadius.circular(10)`.
  - Animación acoplada a 120 ms garantizando respuesta visual sincrónica con el resto de la interfaz.

---

## 8. Barra de Favoritos y Botones de Gestión en Cabecera (`ViewerFavoritesBar`)

### 8.1. Desacoplamiento de Acciones y Pureza del Carrusel
- El carrusel horizontal de favoritos (`ViewerFavoritesBar`) representa exclusivamente entidades de reproducción (canales).
- Se eliminaron del listado horizontal las tarjetas de utilidad utilitaria (`CreateGroupTile` y `ClearFavoritesTile`), evitando tener elementos no reproducibles intercalados al navegar con el control remoto.
- `itemCount` del listado horizontal es estrictamente igual a `favoriteChannels.length`.

### 8.2. Botones de Acción en Cabecera
Las acciones de gestión se agrupan en la fila superior del panel, a la derecha de la etiqueta "Favoritos":
1. **Crear Grupo (`CreateGroupButton`)**:
   - Icono `Icons.add_rounded`.
   - **Renderizado condicional**: Visible únicamente cuando `favoriteChannels.isNotEmpty`.
   - Dispara el diálogo modal `TvDialog` para nombrar y persistir un nuevo grupo con los canales favoritos actuales.
2. **Vaciar Favoritos (`ClearFavoritesButton`)**:
   - Icono `Icons.delete_outline_rounded`.
   - **Renderizado condicional**: Visible únicamente cuando `favoriteChannels.isNotEmpty`.
   - Dispara diálogo de confirmación `TvDialog` destructivo (`favorites_clear_all`) para evitar borrados accidentales.
3. **Alternar Favorito (`FavoriteButton`)**:
   - Icono `Icons.favorite` (marcado) / `Icons.favorite_outline` (no marcado).
   - Siempre visible a la derecha como ancla fija para el canal actualmente en reproducción.

### 8.3. Dimensiones y Estilo Visual
- Los 3 botones comparten dimensiones estrictamente idénticas: **44 dp de ancho × 24 dp de alto**, con radio perimetral 999 dp (`BorderRadius.circular(999)`), fondo sólido sin bordes y micro-animación de escala (`scale: 1.08` al enfocar).

### 8.4. Determinismo de Foco D-Pad en Cabecera
- Al pulsar **Arriba ($\uparrow$)** desde el carrusel de favoritos, el foco **siempre prioriza primero el botón del corazón** (`FavoriteButton`).
- Desde el corazón:
  - **Izquierda ($\leftarrow$)**: Se desplaza al botón de vaciar (`ClearFavoritesButton`).
  - Desde el botón de vaciar, **Izquierda ($\leftarrow$)**: Se desplaza al botón de crear grupo (`CreateGroupButton`).
  - Desde el botón de crear grupo, **Izquierda ($\leftarrow$)**: Sale hacia el panel de contenido izquierdo (acordeón de canales).
- Desde cualquiera de los botones de cabecera:
  - **Abajo ($\downarrow$)**: Desciende directamente al canal visible en el carrusel de favoritos.
  - **Arriba ($\uparrow$)**: Sube al reproductor de TV.

---

## 9. Fondo Global con Degradé Diagonal Cinemático (`HomeScreen`)

### 9.1. Transición de Fondo Plano a Degradé M3
- El fondo sólido plano de la pantalla principal (`Scaffold.backgroundColor`) fue sustituido por un contenedor con degradé diagonal suave (`LinearGradient`):
  - **Dirección**: `begin: Alignment.topLeft`, `end: Alignment.bottomRight`.
  - **Extremo Superior Izquierdo (Más claro)**: `scheme.surfaceContainerHigh` con infusión sutil del color de acento del tema (`primary` al 8% en modo oscuro) para aportar profundidad lumínica y temperatura visual.
  - **Extremo Inferior Derecho (Más oscuro)**: `scheme.surfaceContainerLow` (modo oscuro), logrando un desvanecimiento elegante sin fatiga visual.
- **Continuidad Espacial con el Navigation Rail**:
  - `NavigationRailSection` emplea fondo transparente (`railBg = Colors.transparent`), permitiendo que el degradé diagonal cubra la pantalla de extremo a extremo sin cortes rectangulares.
  - Los paneles del acordeón y el visor de favoritos conservan su fondo `scheme.surface` con bordes redondeados, destacándose limpiamente sobre el degradé ambiental.

---

## 10. Reloj Digital de TV Material Expressive (`TvClockPill`)

### 10.1. Ubicación y Simetría Superior
- El reloj de la pantalla principal se ubica en la esquina superior derecha (`y = 0` a `64 dp`), alineado horizontalmente con el visor y en perfecta simetría de altura con la barra de pestañas `TvTabBar`.

### 10.2. Tipografía y Separador Dinámico
- Diseño puramente tipográfico, sin contenedor ni iconos accesorios.
- Emplea `MoaiText.display` con tamaño **28 pt**, peso `FontWeight.w700` y cifras tabulares (`FontFeature.tabularFigures()`) para evitar saltos de ancho al cambiar los dígitos.
- El separador de dos puntos (`:`) oscila con una animación suave de opacidad (`AnimatedOpacity`, 1 segundo de intervalo) simulando un reloj de transmisión en vivo.
- Envuelto en `ExcludeFocus` para no capturar el foco del control remoto.

---

## 11. Alineación Geométrica y Distribución Vertical

1. **Centrado del Reproductor de Video**:
   - El ancla del reproductor (`TvPlayerLayoutAnchor`) se encuentra centrado verticalmente (`Center` dentro de `Expanded` en `home_tv_area.dart`), equilibrando las distancias entre las pestañas/reloj superiores y la barra de favoritos inferior.
2. **Alineación de Cabecera del Visor**:
   - La línea superior del título del canal activo ("FX", "HBO Plus", etc.) coincide exactamente con el borde superior del panel de acordeón izquierdo a **y = 64 dp**.
   - `TvPanelHeaderMetrics.viewerTopInset` se fijó en 0 dp al coexistir con la barra de estado superior de 64 dp.
3. **Consistencia de Iconografía**:
   - La píldora de país/grupo en la cabecera del visor utiliza `Icons.grid_view_outlined` para mantener armonía visual directa con el icono del acordeón de grupos.

---

## 12. Tipografía de Búsqueda en Pantallas Grandes (`SearchPanel`)

- En `SearchPanel`, el texto explicativo y de advertencia por exceso de resultados (`search_results_capped`, "Demasiados resultados · refiná la búsqueda"):
  - El tamaño de fuente fue incrementado de **10 pt a 11 pt** (`fontSize: 11`, `FontWeight.w500`), garantizando legibilidad clara desde distancias de visualización de sala de estar (2 a 3 metros).


