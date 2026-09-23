# Especificación Técnica: Modal de Detalle de Evento con Sintonización Directa de Canales

**Proyecto:** Moai TV (`moai3`)  
**Módulo:** Calendario Deportivo (`CalendarEventsPanel`, `TvDialog`, `NewChannelCard`, `ChannelProvider`)  
**Fecha:** 23 de Septiembre de 2026  
**Estado:** Propuesto para implementación  

---

## 1. Contexto y Objetivos

Actualmente, cuando un usuario selecciona un evento en la grilla semanal del Calendario Deportivo, Moai TV despliega un diálogo (`TvDialog`) de una sola columna que muestra datos informativos (horario, deporte y emisor sugerido) y un botón para cerrar.

El objetivo de esta especificación es transformar ese diálogo en un **puente directo de sintonización para TV**:
1. Si el usuario cuenta con plugins instalados (ej. `moaiplug_ar`) que transmiten el evento, el modal se expande a **dos columnas**:
   * **Columna 1 (Izquierda):** Datos del evento y acciones de control.
   * **Columna 2 (Derecha):** Lista interactiva de canales de televisión disponibles para sintonizar el partido o evento.
2. Cada canal se representa con el componente nativo de TV [`NewChannelCard`](file:///home/apogeo/moai/moai3/lib/widgets/cards/new_channel_card.dart), mostrando su logo, nombre y el pill distintivo del plugin (ej. `AR`).
3. Al presionar `OK` con el control remoto sobre un canal, el diálogo se cierra y el reproductor de Moai TV sintoniza la señal en vivo al instante.
4. **Condición de ausencia (Graceful Degradation):** Si el usuario no tiene plugins instalados, o si los plugins activos no transmiten el evento, la segunda columna no se renderiza y el modal conserva su diseño compacto de una sola columna.

---

## 2. Requerimientos de la Especificación

### REQ-1: Motor de Correlación de Canales (Matcher de Evento a Canal)
* Se implementa un servicio utilitario determinista [`CalendarChannelMatcher`](file:///home/apogeo/moai/moai3/lib/services/calendar/calendar_channel_matcher.dart) para correlacionar un `CalendarEvent` contra la lista de canales activos en `ChannelProvider` (`context.read<ChannelProvider>().channels`).
* **Criterios de Coincidencia (Orden de Prioridad):**
  0. **Por Identificadores Directos (`channelHints` / DaddyLive):** Si el evento reporta enlaces directos de canales (ej. `id=1027` en la API de DaddyLive), busca coincidencia exacta con canales cuyo `pluginChannelId` o `id` sea igual al hint. Permite correlación 1-a-1 sin ambigüedad cuando `moaiplug_daddylive` está instalado.
  1. **Por Emisor (`broadcaster` / `moaiplug_ar` y otros):** Mapeo de términos canónicos hacia nombres o IDs de canales (soporta múltiples emisores separados por barra, ej. `"TNT Sports / ESPN Premium"`):
     * `"TNT Sports"` / `"TNT Sports Premium"` ➔ Coincide con canales cuyo nombre o ID contenga `tnt sports` o `tnt_sports`.
     * `"ESPN Premium"` ➔ Coincide con `espn premium` o `espn_premium`.
     * `"ESPN"` ➔ Coincide con canales de la familia ESPN (`espn`, `espn 2`, `espn 3`, etc.).
     * `"TyC Sports"` ➔ Coincide con `tyc sports`.
     * `"Fox Sports"` ➔ Coincide con `fox sports`.
     * `"DSports"` ➔ Coincide con canales `dsports`.
     * `"Telefe"` ➔ Coincide con `telefe`.
     * `"TV Pública"` ➔ Coincide con `tv publica` o `television publica`.
  2. **Por Torneo / Competición (Fallback inteligente):** Si el emisor es ambiguo o nulo, pero la competición es `"Liga Profesional"`, prioriza canales del Pack Fútbol (`ESPN Premium`, `TNT Sports Premium`). Si es `"Fórmula 1"`, prioriza `Fox Sports`, `ESPN`, o feeds de F1.
* **Resultado:** Lista filtrada de objetos `Channel` ordenados por relevancia (máximo 4-5 canales sugeridos para mantener la lista legible en TV sin necesidad de scroll infinito).

### REQ-2: Layout Condicional de Dos Columnas en `TvDialog`
* El contenido del diálogo `_CalendarEventDialogContent` evalúa la lista de canales coincidentes:
  * **Si `matchingChannels.isNotEmpty`:**
    * El diálogo adopta un layout horizontal (`Row`) con dos secciones separadas por un divisor sutil o padding holgado (24px).
    * Ancho adaptable para TV (ej. `maxWidth: 720` o ancho porcentual del viewport).
    * **Columna Izquierda:** Título del evento, badge `EN VIVO` (si aplica), hora, competición, tipo de sesión y botón `Cerrar`.
    * **Columna Derecha:** Encabezado de sección `"Canales disponibles"` / `"En vivo en"` y lista vertical de tarjetas de canal.
  * **Si `matchingChannels.isEmpty`:**
    * El diálogo conserva su ancho compacto actual (ej. `maxWidth: 440`) y estructura de una sola columna sin espacio muerto a la derecha.

### REQ-3: Presentación Visual del Ítem de Canal
* Cada canal se renderiza utilizando [`NewChannelCard`](file:///home/apogeo/moai/moai3/lib/widgets/cards/new_channel_card.dart):
  * **Logo:** Logo oficial del canal obtenido desde `channel.logoUrl`.
  * **Nombre:** Nombre legible (`channel.name`).
  * **Plugin Pill:** Etiqueta con el tag del plugin en mayúsculas (ej. `AR`) obtenida de `channel.pluginTag`.
  * **Estilo de TV:** Foco de control remoto resaltado con borde y fondo suave de la paleta Moai.

### REQ-4: Navegación Fluida con D-Pad (Control Remoto)
* El foco inicial se sitúa en el botón principal (o en el primer canal si el evento está en vivo).
* **Navegación bidireccional:**
  * Desde el botón `Cerrar` (columna izquierda), presionar `Flecha Derecha` transfiere el foco al primer canal de la columna derecha.
  * Desde la lista de canales (columna derecha), presionar `Flecha Izquierda` regresa el foco al botón `Cerrar`.
  * Dentro de la columna derecha, `Flecha Arriba` y `Flecha Abajo` navegan entre los canales disponibles.

### REQ-5: Acción de Sintonización Inmediata
* Al presionar `OK` / `Enter` sobre un canal:
  1. Cierra el diálogo modal (`Navigator.of(context).pop()`).
  2. Ejecuta la sintonización del canal en el estado global:
     ```dart
     context.read<ChannelProvider>().selectChannel(channel);
     ```
  3. Moai TV conmuta automáticamente a la reproducción a pantalla completa de dicho canal.

---

## 3. Componentes Involucrados

| Componente | Archivo | Responsabilidad |
|---|---|---|
| **Matcher de Canales** | `lib/services/calendar/calendar_channel_matcher.dart` (Nuevo) | Algoritmo determinista de correlación entre evento y lista de canales activos. |
| **Diálogo de Evento** | `lib/features/calendar/widgets/calendar_events_panel.dart` | Refactorización de `_CalendarEventDialogContent` para soportar 1 o 2 columnas según canales. |
| **Tarjeta de Canal** | `lib/widgets/cards/new_channel_card.dart` | Reutilización directa para mostrar logo, nombre y pill de plugin. |
| **Estado Global** | `lib/state/channel_provider.dart` | Proveer la lista de canales activos instalados y ejecutar `selectChannel`. |
| **Localización** | `assets/translations/es.json` y `en.json` | Claves para títulos y encabezados de la columna de canales. |
