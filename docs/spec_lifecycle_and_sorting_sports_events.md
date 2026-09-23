# Especificación Técnica: Ciclo de Vida, Ordenamiento y Presentación de Eventos Deportivos

**Proyecto:** Moai TV (`moai3`)  
**Módulo:** Calendario y Agenda Deportiva (`CalendarProvider`, `CalendarEventsPanel`, `SportsScheduleService`, `F1CalendarService`)  
**Fecha:** 22 de Septiembre de 2026  
**Estado:** Aprobado para implementación  

---

## 1. Contexto y Objetivos

En un entorno de TV (Android TV con navegación mediante D-Pad / Control Remoto), los eventos deportivos en vivo presentan características particulares:
1. Son transmisiones temporales que caducan una vez que el evento concluye.
2. Un usuario que llega a la app no debe tener que scrollear para encontrar lo que está ocurriendo en este momento.
3. Si un evento ya finalizó, intentar abrirlo o sintonizarlo resulta en pantallas negras o fallas de reproducción.
4. Eliminar por completo los eventos pasados desorienta al usuario, vacía las columnas de la vista semanal y puede romper la navegación por índice del D-Pad.
5. La interfaz de TV debe ser limpia, sobria y profesional: **no se deben utilizar emojis**; toda iconografía debe provenir de Material Icons.

---

## 2. Requerimientos de la Especificación

### REQ-1: Ordenamiento Inteligente con Prioridad de Estado
Dentro de cada día (columna), los eventos se ordenan mediante una función de comparación compuesta:
* **Prioridad Primaria:**
  1. `CalendarEventStatus.live` (Prioridad 0): Transmisiones en curso.
  2. `CalendarEventStatus.upcoming` (Prioridad 1): Eventos futuros programados.
  3. `CalendarEventStatus.finished` (Prioridad 2): Eventos pasados/concluidos.
* **Prioridad Secundaria:**
  * Dentro del mismo grupo de estado, se ordenan cronológicamente por `startDateTime` ascendente.

### REQ-2: Tratamiento Visual de Eventos Pasados (`finished`)
* Los eventos en estado `finished` deben presentar una atenuación visual clara (opacidad al 45-50% o paleta neutra apagada `surfaceContainerLow`).
* Si el cursor/foco del D-Pad se posa sobre un evento finalizado, el indicador de selección debe ser neutro (ej. `scheme.surfaceContainerHighest` con texto atenuado), diferenciándolo del color `primary` vibrante que tienen los eventos activos.
* Exhiben un badge sobrio con el texto localizado `"calendar_status_finished"` (*FINALIZADO*) y un ícono Material (`Icons.check_circle_outline_rounded` o `Icons.history_rounded`).

### REQ-3: Interacción D-Pad (No-op en Eventos Finalizados)
* Al presionar `OK` / `Enter` / `Select` o `Tap` sobre un evento en estado `finished`:
  * **No debe realizar ninguna acción (No-op).**
  * Debe consumir el evento del teclado (`KeyEventResult.handled`), impidiendo la apertura de diálogos de detalles o intentos de sintonización.
* Los eventos `live` y `upcoming` mantienen su comportamiento normal de apertura de detalles.

### REQ-4: Iconografía Estricta sin Emojis
* **Cero Emojis:** Queda prohibida la presencia de emojis (⚽, 🏁, 📺, etc.) en los títulos de eventos, nombres de competiciones y badges de la interfaz.
* Se implementa un filtro de sanitización exhaustivo en `SportsScheduleService` y `F1CalendarService` que elimina rangos Unicode de emojis, símbolos suplementarios y variantes de presentación.
* Los estados se representan con componentes `Icon` de Material:
  * `live`: `Icons.fiber_manual_record_rounded` junto al texto `"EN VIVO"`.
  * `upcoming`: `Icons.schedule_rounded` junto a la hora programada.
  * `finished`: `Icons.check_circle_outline_rounded` junto al texto `"FINALIZADO"`.

### REQ-5: Estimación de Ciclo de Vida y Transición
* **Fórmula 1:**
  * Prácticas y Clasificación: 60 - 75 minutos.
  * Gran Premio (Carrera): 120 minutos.
* **Deportes en General:**
  * Un evento se considera `live` si `now` está entre `startDateTime` y `startDateTime + 120 minutos` (o si el origen reporta `"Live"`).
  * Se considera `finished` una vez superados los 120 minutos desde `startDateTime`.

---

## 3. Plan de Componentes Afectados

| Componente | Archivo | Modificación |
|---|---|---|
| **Modelo** | `lib/models/calendar_event.dart` | Añadir `statusPriority` y comparator estandarizado. |
| **Estado** | `lib/state/calendar_provider.dart` | Aplicar ordenamiento por estado y hora en `getEventsForDay` y `subscribedEvents`. |
| **Servicio** | `lib/services/calendar/sports_schedule_service.dart` | Sanitización estricta de emojis y asignación determinista de estado. |
| **Servicio** | `lib/services/calendar/f1_calendar_service.dart` | Garantizar títulos libres de emojis. |
| **UI** | `lib/features/calendar/widgets/calendar_events_panel.dart` | Bloqueo de acción en `finished`, diseño atenuado, badges con Material Icons. |
| **Traducción** | `assets/translations/es.json` y `en.json` | Agregar clave `calendar_status_finished`. |
