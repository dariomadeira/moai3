# SPEC-41: Estilos de Foco TV y Audio D-Pad (SoundPool)

> **Estado**: Aprobado (rama `xumovies`, v3.0.36+)  
> **Área**: Features / UX TV  
> **Archivos de Referencia**:  
> - `lib/widgets/cards/tv_list_card_style.dart`  
> - `lib/widgets/cards/channel_grid_tile.dart`  
> - `lib/features/settings/widgets/tv_tile.dart`  
> - `lib/widgets/cards/tv_icon_list_card.dart`  
> - `lib/state/tv_settings_provider.dart`  
> - `android/app/src/main/kotlin/com/infomak/moai/UiDpadSounds.kt`  
> - `android/app/src/main/kotlin/com/infomak/moai/MainActivity.kt`  

---

## 1. Propósito

Unificar reglas visuales de foco/selección en listas TV y el feedback sonoro del D-Pad sin saturar el audio del sistema.

### Non-Goals
- Cambiar el motor de navegación D-Pad (SPEC-30).  
- Sonidos dentro del emulador arcade (otro pipeline).

---

## 2. Estilos de foco (`TvListCardStyle`)

### 2.1. Regla general (listas / ajustes / icon cards)
| Estado | Fondo | Borde |
| :--- | :--- | :--- |
| Reposo | `surfaceContainerHigh` suave | `outlineVariant` débil |
| Seleccionado | `primaryContainer` | igual reposo/suave |
| **Foco** | **`scheme.primary` (relleno)** | `primary` |

Aplica a: `TvTile`, `TvIconListCard`, filas de ajustes, etc.

### 2.2. Excepción: grilla de canales (`ChannelGridTile`)
- Foco = **solo borde** `primary` width **2**, **sin** relleno amarillo/primary.  
- Motivo: preservar legibilidad de logos sobre fondo oscuro.  
- Implementación: resolver estilo base con `focused: false` y, si hay foco, overlay de `Border.all(primary, 2)`.

### 2.3. Rebuild
- Tiles de canal deben observar `showChannelLabels` con `select` / `selectOptional`, no `watch` completo de `TvSettingsProvider`.

---

## 3. Audio UI D-Pad (SoundPool)

### 3.1. Comportamiento
- Clicks cortos al mover foco (assets WAV de opción/enter).  
- Implementación nativa `UiDpadSounds` con **SoundPool** (`MAX_STREAMS` bajo, throttle ~45 ms).  
- Filtrar eventos de gamepad físico arcade para no spamear en partida.  
- Preferencia usuario: `ui_sounds_disabled` → MethodChannel `setUiDpadSoundsEnabled` en `com.infomak.moai.tv/device`.

### 3.2. Por qué SoundPool
`MediaPlayer` por tecla generaba solapamiento y spam; SoundPool precarga y limita streams concurrentes.

---

## 4. Criterios de aceptación

```gherkin
Given la grilla de canales
When un tile recibe foco
Then se muestra borde primary de 2 dp
And el fondo del tile no se rellena con primary

Given un TvTile de ajustes
When recibe foco
Then el fondo es primary y el texto onPrimary

Given ui_sounds_disabled = false
When el usuario mueve el D-Pad en la UI
Then suena un click breve sin saturar el audio

Given ui_sounds_disabled = true
When el usuario mueve el D-Pad
Then no se reproducen clicks UI
```
