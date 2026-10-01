# SPEC-37: Overlay de Voz "Miremos Juntos" y Control de Foco en Reproductor Fullscreen

> **Estado**: Listo para Implementación (Diseño Consensuado Completo)  
> **Área**: Experiencia de Usuario / Reproductor de Video / Funcionalidad Social  
> **Archivos de Referencia**:  
> - `lib/widgets/player/tv_viewer.dart`  
> - `lib/widgets/player/tv_viewer_focus_wrapper.dart`  
> - `lib/features/home/areas/home_tv_area.dart`  
> - `lib/models/channel.dart`  
> - `lib/services/plugin_host_service.dart`  
> - `specs/features/watch_party_settings.md` (SPEC-36)  
> - `specs/features/tv_remote_voice_input.md` (SPEC-34)  
> - `specs/domain/user_control_and_presence.md` (SPEC-22)

---

## 1. Propósito y Alcance

### Propósito
Definir la arquitectura de interfaz, condiciones de visibilidad contextual, ruteo de audios según el canal sintonizado, gestión de privacidad en altavoces del hogar, captura de voz vía control remoto y reproducción secuencial de audios (**Audio Playback Queue**) durante la reproducción en pantalla completa en Android TV.

### Alcance (In Scope)
1. **Detección de Contexto Común ("Mismo Canal"):**
   - La experiencia de voz solo se activa entre amigos que están sintonizando **exactamente el mismo canal** de televisión en vivo.
   - Si un amigo está en otro canal o fuera de pantalla completa, no participa de la conversación ni es interrumpido.
2. **Trilogía Superior en Pantalla Completa:**
   - **Izquierda:** Aviso pasivo de conexión (`🟢 [Nombre] está viendo`).
   - **Centro:** Botón interactivo de micrófono / detención (**Mic / Stop Toggle**), poseedor del foco del control remoto.
   - **Derecha:** Reproductor visual pasivo de audios entrantes (`🔊 [Nombre]: [||||] 0:03`).
3. **Visibilidad Condicional Estricta:**
   - `watchPartyEnabled == true` (activado en Ajustes).
   - Reproductor en **pantalla completa** (`isFullScreen == true`).
   - Al menos un amigo en común online **sintonizando el mismo canal**.
4. **Mecánica de Foco y Salida:**
   - El botón central de micrófono retiene el foco por defecto.
   - Con el botón enfocado, la **única forma** de salir de pantalla completa es presionando **`BACK`**.
5. **Grabación de Voz (Toggle-to-Talk):**
   - Pulsar `OK`: Inicia grabación y el botón conmuta a **STOP** (rojo pulsante).
   - Pulsar `OK` nuevamente: Detiene la grabación, genera el `.m4a` amplificado y lo despacha a los amigos del canal.
6. **Recepción y Reproducción de Audios (Cola Inteligente FIFO):**
   - Reproducción automática secuencial por los altavoces de la TV con ganancia amplificada (+14 dB).
   - **Prevención de Acople:** Al pulsar Grabar, si sonaba un audio de un amigo se pausa al milisegundo para no re-grabarlo por el micrófono. Al finalizar, se reanuda.
   - **Pausa por Modales:** Si se abre cualquier menú o diálogo, el audio se pausa y se reanuda al volver a pantalla completa.

---

## 2. Reglas de Privacidad y Ruteo de Audio en el Hogar

### 2.1 Principio de Confianza de Altavoces
En un televisor de sala/living, **jamás debe sonar la voz de alguien a quien el usuario no haya agregado expresamente a su lista de amigos**.

1. **Emisión:** Un usuario solo transmite su voz a los amigos presentes en su propia lista (`device_friends`).
2. **Recepción:** El televisor receptor solo reproduce audios provenientes de personas que figuren en su propia lista de amigos. Audios de terceros no agregados se descartan silenciosamente.

### 2.2 Caso de Estudio (Matriz de 3 Personas):
- **Persona 1:** Tiene agregados a **2** y **3**.
- **Persona 2:** Tiene agregados a **1** y **3**.
- **Persona 3:** Solo tiene agregado a **1** (no tiene a 2).

**Si los 3 están viendo el MISMO canal:**
- **Habla Persona 1:** Lo escuchan la **Persona 2** y la **Persona 3** (ambos son amigos de 1 y 1 los tiene a ellos).
- **Habla Persona 2:** Solo lo escucha la **Persona 1**. La **Persona 3 NO lo escucha** (3 no tiene a 2 en su lista; el televisor de 3 protege su privacidad).
- **Habla Persona 3:** Solo lo escucha la **Persona 1**. La **Persona 2 NO lo escucha** (3 no incluyó a 2 en su lista de envío).

---

## 3. Detección de Canal Común e Interoperabilidad con Plugins

Los canales en MoAI 3 son provistos dinámicamente por plugins (`moaiplug_ar`, `moaiplug_daddylive`, etc.) a través de `PluginChannelCatalog`.

### 3.1 Identificador Canónico y Matching Inteligente
Cada canal posee:
- `channel.id`: Formato `plugin:<source_id>:<channel_id>` (ej. `plugin:ar:telefe`, `plugin:daddylive:1027`).
- `channel.name`: Nombre legible (ej. `"Telefe"`, `"ESPN 2"`).

Para determinar si dos dispositivos están viendo el mismo canal, se aplica la siguiente regla en orden de prioridad:
```dart
bool isSameChannel(FriendInfo friend, Channel currentChannel) {
  // 1. Coincidencia exacta por ID canónico (mismo plugin y canal)
  if (friend.currentChannelId != null &&
      friend.currentChannelId == currentChannel.id) {
    return true;
  }

  // 2. Coincidencia por nombre normalizado (distinto plugin, misma transmisión)
  if (friend.currentChannelName != null &&
      friend.currentChannelName!.trim().toLowerCase() ==
          currentChannel.name.trim().toLowerCase()) {
    return true;
  }

  return false;
}
```

### 3.2 Casos de Plugins:
- **Ambos usan el mismo plugin (95% de los casos):** El ID coincide byte por byte (ej. `plugin:ar:tyc_sports`). Detección exacta inmediata.
- **Plugins distintos (fuentes alternativas):** Coincide por nombre normalizado (ej. `"ESPN"`).
- **Plugin no instalado:** Si un amigo no tiene instalado el plugin del canal que estás viendo, jamás sintonizará ese ID/nombre; la sala permanece inactiva de forma natural.

---

## 4. Base de Datos y Supabase Realtime

Se utiliza la tabla `devices` existente que ya cuenta con publicación activa en Supabase Realtime.

### 4.1 Nuevas Columnas en `devices`
```sql
ALTER TABLE public.devices 
ADD COLUMN IF NOT EXISTS current_channel_id TEXT NULL,
ADD COLUMN IF NOT EXISTS current_channel_name TEXT NULL;

-- Índice para consultas y filtros rápidos por canal
CREATE INDEX IF NOT EXISTS idx_devices_current_channel 
ON public.devices(current_channel_id);
```

### 4.2 Mecánica Anti-Zapping (Debounce de 3 Segundos)
Para evitar sobrecargar la base de datos con peticiones `UPDATE` innecesarias mientras el usuario navega canales rápidamente:
1. Al sintonizar un canal en `TvViewer`, se inicia un temporizador de **3 segundos**.
2. Si el usuario cambia de canal antes de los 3 segundos, el temporizador previo se cancela.
3. Solo tras 3 segundos de reproducción continua se envía:
   ```dart
   await supabase.from('devices').update({
     'current_channel_id': channel.id,
     'current_channel_name': channel.name,
     'updated_at': DateTime.now().toUtc().toIso8601String(),
   }).eq('device_id', myDeviceId);
   ```
4. **Limpieza a `null`:** Al pausar, salir de pantalla completa o cerrar la app, se envía `current_channel_id = null` y `current_channel_name = null`.

---

## 5. Matriz de Visibilidad del Overlay en Reproductor

| Watch Party Habilitado | Modo Pantalla Completa | ¿Hay amigos en el MISMO canal? | Visibilidad Trilogía Superior | Comportamiento al presionar teclas |
| :---: | :---: | :---: | :---: | :--- |
| **OFF** | Sí | Indiferente | **Oculto** | `BACK` o cualquier tecla sale de pantalla completa. |
| **ON** | No (Ventana) | Indiferente | **Oculto** | Navegación estándar de MoAI 3 (Explorar, grilla, tabs). |
| **ON** | Sí | **No** (0 amigos en este canal) | **Oculto** | `BACK` o cualquier tecla sale de pantalla completa. |
| **ON** | Sí | **Sí** ($\ge 1$ amigos en este canal) | **VISIBLE** | **Micrófono enfocado por defecto.** Solo `BACK` sale de pantalla completa. |

---

## 6. Especificación de UI: Trilogía Superior

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                                                                   │
│      ┌────────────────────────┐   ┌─────────┐   ┌───────────────────────────┐     │
│      │ 🟢  Juan está viendo   │   │   🎙️    │   │ 🔊 Carlos:  |||||  0:03   │     │
│      └────────────────────────┘   └─────────┘   └───────────────────────────┘     │
│         [Aviso de Conexión]        [Centro]        [Reproduciendo Audio]          │
│            (Sin foco, izq)        (Mic con foco)      (Sin foco, der)             │
│                                                                                   │
│                                                                                   │
│                              REPRODUCCIÓN DE VIDEO                                │
│                               (PANTALLA COMPLETA)                                 │
│                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────┘
```

* **Ubicación:** `Alignment.topCenter`, con margen superior de `32dp` (zona segura de overscan).
* **1. Izquierda – Aviso de Conexión:**
  * Chip redondeado (`r: 22dp`) con punto verde 🟢 + `"Juan está viendo"` (o `"Juan y 1 más están viendo"`).
  * `Focusable: false`.
* **2. Centro – Botón de Voz (Mic / Stop Toggle):**
  * Dimensiones: `56 x 56 dp`.
  * **Standby:** Icono `Symbols.mic`, borde con `colorScheme.primary` (3dp).
  * **Grabando:** Icono `Icons.stop`, fondo `colorScheme.error`, halo pulsante rojo.
  * `Focusable: true` (retiene el foco del control remoto).
* **3. Derecha – Audio Entrante:**
  * Chip redondeado (`r: 22dp`) con icono de altavoz animado 🔊 + nombre del amigo + indicador de progreso.
  * Solo visible mientras se reproduce un audio de la cola.

---

## 7. Grabación, Antiacople y Cola de Reproducción (`AudioPlaybackQueueManager`)

```mermaid
graph TD
    A[Audio Entrante de Amigo en mismo canal] --> B[AudioPlaybackQueueManager]
    B --> C[Cola FIFO de Audios]
    
    D[Usuario pulsa OK para GRABAR] -->|pause()| B
    E[Usuario pulsa STOP para ENVIAR] -->|resume()| B
    F[Modal o Diálogo Abierto] -->|pause()| B
    G[Modal Cerrado] -->|resume()| B
    
    C -->|Reproducir siguiente si no está pausado| H[Chip Derecho Visible + Reproducción con LoudnessEnhancer]
    H -->|Al completar audio| I{¿Quedan más audios?}
    I -->|Sí| C
    I -->|No| J[Ocultar Chip Derecho]
```

### Reglas Clave:
1. **Antiacople Acústico Estricto:** Si el usuario presiona Grabar mientras suena un audio o hay mensajes pendientes, la reproducción se **pausa de inmediato** para que el micrófono del control remoto no capture el audio del televisor. Al finalizar la grabación, se reanuda automáticamente.
2. **Pausa por Modales:** Cualquier diálogo o menú abierto pausa la cola y la reanuda al regresar.
3. **Reproducción Secuencial FIFO:** Los audios se reproducen uno tras otro, nunca simultáneos.

---

## 8. Plan de Ejecución Paso a Paso (Checklist para Mañana)

- [ ] **Paso 1: Migración SQL en Supabase**
  - Añadir columnas `current_channel_id` y `current_channel_name` a `devices`.
  - Crear bucket de Storage `voice_messages` (o tabla de broadcast).
- [ ] **Paso 2: Reporte de Canal en `WatchPartyService` & `WatchPartyProvider`**
  - Métodos `reportCurrentChannel(Channel? channel)` con debounce de 3 segundos.
  - Actualizar `FriendInfo` para deserializar `current_channel_id` y `current_channel_name`.
  - Getter `List<FriendInfo> get friendsWatchingCurrentChannel`.
- [ ] **Paso 3: Integración en `TvViewer`**
  - Vincular el reproductor para reportar el canal al sintonizar y limpiar al salir.
- [ ] **Paso 4: Widget `WatchPartyOverlay` en Fullscreen**
  - Implementar la barra superior con el chip izquierdo, botón central y chip derecho.
  - Manejo de foco exclusivo y tecla `BACK` para salir.
- [ ] **Paso 5: `AudioPlaybackQueueManager` y Toggle-to-Talk**
  - Manejo de estados de grabación (`RemoteVoiceManager`).
  - Envío y recepción de audios en Supabase.
  - Reproducción secuencial y antiacople.
- [ ] **Paso 6: Validación y Pruebas Unitarias**
  - Tests de matching de canales, amigos mutuos y cola FIFO.
