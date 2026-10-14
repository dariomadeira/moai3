# SPEC-38: Arcade Netplay (partida a distancia 2P)

> **Estado**: Aprobado (rama `xumovies`, v3.0.36+)  
> **Área**: Features / Arcade online  
> **Archivos de Referencia**:  
> - `lib/features/games/services/arcade_netplay_service.dart`  
> - `lib/features/games/services/arcade_webrtc_transport.dart`  
> - `lib/features/games/screens/arcade_screen.dart`  
> - `lib/features/games/widgets/tv_arcade_prep_dialog.dart`  
> - `lib/features/home/areas/home_arcade_area.dart`  
> - `android/app/src/main/cpp/arcade_runner.cpp`  
> - `android/app/src/main/kotlin/com/infomak/moai/games/ArcadeEmulatorManager.kt`  

---

## 1. Propósito y Alcance

Permitir que **dos dispositivos** (host e invitado) jueguen la **misma ROM arcade** a distancia:

1. Invitación y lobby (Supabase Realtime Broadcast).  
2. Preparación/descarga de ROM en ambos lados.  
3. Canal de inputs de baja latencia (WebRTC DataChannel + ICE/TURN).  
4. Sincronización de emulación **lockstep** en el loop nativo (delay fijo de frames).

### Non-Goals
- Rollback / GGPO.  
- Más de 2 jugadores.  
- Servidor UDP propio.  
- Sincronizar save-states o rewind.  
- Versionar secretos TURN en el repositorio (viven en `.env`).

---

## 2. Arquitectura

```text
[Invite / Accept / ROM prep]     →  Supabase Realtime Broadcast
[SDP / ICE candidatos]           →  Supabase (señalización WebRTC)
[Inputs frame+mask]              →  WebRTC DataChannel
[Aplicar inputs + retro_run]     →  arcade_runner.cpp (lockstep)
```

| Capa | Responsabilidad |
| :--- | :--- |
| `ArcadeNetplayService` | Sesión, lobby, prep ROM, orquesta WebRTC, status UI |
| `ArcadeWebRtcTransport` | `RTCPeerConnection`, DataChannel, ICE servers (STUN+TURN) |
| `ArcadeEmulatorService` | MethodChannel `netplayEnable` / `submitLocal` / `submitRemote` / `getFrame` |
| `arcade_runner.cpp` | Buffers por frame; espera ambos inputs antes de `core_retro_run` |

---

## 3. Estados de sesión (`ArcadeNetplayStatus`)

| Estado | Significado |
| :--- | :--- |
| `idle` | Sin sesión |
| `inviting` | Host esperando accept (timeout 30s) |
| `invited` | Reserva UI (invite pendiente en stream) |
| `preparingRoms` | Descarga/verificación ROM |
| `ready` | Ambos con ROM lista; negociando WebRTC |
| `inGame` | DataChannel abierto; se puede abrir `ArcadeScreen` |
| `reconnecting` | Heartbeat detectó DC caído (UX) |
| `terminated` | Cancel / reject / error / timeout ICE |

**Regla UI:** `TvArcadePrepDialog` solo invoca `onReadyToPlay` cuando `status == inGame` (no en `ready`).

---

## 4. Reglas de negocio

### 4.1. Lobby
1. Host llama `inviteFriend` con `romManager`; si `_globalChannel == null` → `false`.  
2. Al accept, **host e invitado** ejecutan `startRomPreparation`.  
3. Tras ROM lista: `setActiveRom(session.romFilename)` obligatorio.  
4. Canal de sesión: esperar `subscribed` (o timeout corto) antes de `ready_to_play`.  
5. `cancelSession` hace await del broadcast `cancel` antes de limpiar.

### 4.2. Presencia
- Dispositivo en sección **TV** o **Arcade** → `online = true` (SPEC-22).  
- Sin esto el friend picker de netplay no lista al peer.

### 4.3. WebRTC / TURN
- ICE servers: STUN públicos Google + opcional TURN desde dotenv:
  - `TURN_URL` (ej. `turn:free.expressturn.com:3478`)
  - `TURN_USER`, `TURN_PASS`
- Sin TURN: puede funcionar en LAN; **entre redes distintas no está garantizado**.  
- Timeout ICE: 20s → `terminated` con mensaje i18n (`arcade_netplay_ice_timeout` / `ice_failed`).

### 4.4. Lockstep nativo
- `nativeNetplayEnable(enabled, delayFrames=3, isHost)`.  
- Inputs etiquetados `{frame, mask, senderDeviceId}` por DataChannel.  
- El loop solo avanza un frame cuando existen inputs local y remoto para ese frame.  
- Host = P1 local / P2 remoto; Guest = P2 local / P1 remoto.  
- Timeout espera remoto: 500 ms (reintento sin avanzar frame).  
- Partida local (sin netplay): comportamiento previo sin lockstep.

### 4.5. Inputs UI
- Teclado/D-pad en `ArcadeScreen` y overlay táctil (si activo) deben:
  1. `sendInputMask` local  
  2. `netplaySubmitLocalInput(frame, mask)`  
  3. `ArcadeNetplayService.sendLocalInput(mask, frame: …)`  

---

## 5. Canales nativos (complemento SPEC-11)

Canal: `com.infomak.moai/arcade_channel`

| Método | Args | Notas |
| :--- | :--- | :--- |
| `netplayEnable` | `enabled`, `delayFrames`, `isHost` | Activa buffers lockstep |
| `netplaySubmitLocalInput` | `frame`, `mask` | |
| `netplaySubmitRemoteInput` | `frame`, `mask` | |
| `netplayGetFrame` | — | `int`/`long` frame actual |

---

## 6. Criterios de aceptación

```gherkin
Given dos dispositivos con Supabase y la misma app
And ambos en sección Arcade (online)
When el host invita a un amigo con una ROM instalada en ambos
Then ambos completan preparingRoms y negocian WebRTC
And el prep dialog solo cierra al pasar a inGame

Given TURN configurado en .env
When los peers están en redes distintas
Then la DataChannel puede abrirse vía relay TURN

Given TURN vacío y NAT simétrico hostil
When expira el timeout ICE
Then la sesión termina con mensaje de error P2P visible

Given partida inGame
When ambos envían inputs con frame
Then el emulador no ejecuta un frame sin el par local+remoto

Given partida local sin netplaySession
When el usuario juega solo
Then nativeNetplayEnable no altera el loop libre
```
