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
