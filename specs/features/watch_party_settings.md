# SPEC-36: Panel "Miremos Juntos" en Ajustes

> **Estado**: Listo para Implementación  
> **Área**: Experiencia de Usuario / Ajustes / Funcionalidad Social  
> **Archivos de Referencia**: `lib/features/settings/widgets/settings_tv_panel.dart`, `lib/widgets/dialogs/tv_voice_test_dialog.dart`, `specs/domain/user_control_and_presence.md`

---

## 1. Propósito y Alcance

### Propósito
Implementar un nuevo panel dentro de la sección de Ajustes de MoAI 3 llamado **"Miremos Juntos"** que permita al usuario:
- Activar o desactivar la funcionalidad social de ver contenido con amigos.
- Consultar su identificador único de usuario (código `MOAI-XXXX` para compartir).
- Gestionar su lista de amigos (agregar mediante código de 4 caracteres y eliminar).
- Acceder a la prueba de micrófono del control remoto mediante el diálogo existente.

### Alcance (In Scope)
- Panel de configuración "Miremos Juntos" con switch principal (por defecto `OFF`).
- Visualización destacada del código de usuario (`user_code`) en TV **únicamente cuando el switch esté en `ON`**.
- Pantalla de gestión de amigos (lista en tiempo real con indicador 🟢/⚪ + agregar + eliminar).
- Diálogo de agregar amigo con prefijo `MOAI-` fijo para simplificar la entrada con D-Pad en TV.
- Acceso directo a la prueba de audio conectada con `TvVoiceTestDialog`.
- Estructura de base de datos en Supabase para relaciones de amistad unidireccionales.
- Navegación 100% optimizada para control remoto (D-Pad).

### Non-Goals (Fuera de Alcance)
- **Sistema de invitaciones o notificaciones push**: No se implementa en esta spec; se definirá en la spec de sincronización de salas.
- **Chat de texto**: Solo se gestiona la lista de amigos y su estado online/offline.
- **Sincronización de reproducción de video (Watch Party Core)**: La sincronización de canales o streams se especificará en una spec posterior.
- **Mostrar canal actual del amigo**: Por privacidad, solo se muestra si el amigo está conectado o desconectado.
- **Copiar código al portapapeles**: En Android TV no existe portapapeles compartido; el código se visualiza en tamaño grande para ser leído o dictado.

---

## 2. Definición de Tipos y Contratos

### 2.1. Tabla `device_friends` en Supabase

```sql
CREATE TABLE IF NOT EXISTS public.device_friends (
    device_id         TEXT NOT NULL REFERENCES public.devices(device_id) ON DELETE CASCADE,
    friend_device_id  TEXT NOT NULL REFERENCES public.devices(device_id) ON DELETE CASCADE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (device_id, friend_device_id),
    CONSTRAINT chk_no_self_friend CHECK (device_id <> friend_device_id)
);

-- Índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_device_friends_device ON public.device_friends(device_id);
CREATE INDEX IF NOT EXISTS idx_device_friends_friend ON public.device_friends(friend_device_id);

-- Habilitar Realtime para detectar cambios en tiempo real
ALTER PUBLICATION supabase_realtime ADD TABLE public.device_friends;

-- Políticas RLS compatibles con MoAI 3 (acceso anónimo por device_id)
ALTER TABLE public.device_friends ENABLE ROW LEVEL SECURITY;

-- Política SELECT: Permitir lectura de relaciones de amistad
CREATE POLICY "Permitir lectura de amigos" ON public.device_friends
    FOR SELECT TO anon USING (true);

-- Política INSERT: Permitir registrar una nueva relación de amistad
CREATE POLICY "Permitir agregar amigos" ON public.device_friends
    FOR INSERT TO anon WITH CHECK (true);

-- Política DELETE: Permitir eliminar una relación de amistad existente
CREATE POLICY "Permitir eliminar amigos" ON public.device_friends
    FOR DELETE TO anon USING (true);
```

### 2.2. Modelo Dart: `Friendship`

```dart
class Friendship {
  final String deviceId;
  final String friendDeviceId;
  final DateTime createdAt;

  Friendship({
    required this.deviceId,
    required this.friendDeviceId,
    required this.createdAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      deviceId: json['device_id'] as String,
      friendDeviceId: json['friend_device_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'friend_device_id': friendDeviceId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
```

### 2.3. Modelo Dart: `FriendInfo`

Representa el amigo en la UI combinando los datos de la relación y el estado del dispositivo en `devices`:

```dart
class FriendInfo {
  final String deviceId;
  final String userCode;
  final String? nickname;
  final bool isOnline;
  final DateTime? lastSeen;

  FriendInfo({
    required this.deviceId,
    required this.userCode,
    this.nickname,
    required this.isOnline,
    this.lastSeen,
  });

  factory FriendInfo.fromDeviceJson(Map<String, dynamic> json) {
    return FriendInfo(
      deviceId: json['device_id'] as String,
      userCode: json['user_code'] as String? ?? 'MOAI-????',
      nickname: json['nickname'] as String?,
      isOnline: json['online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
    );
  }
}
```

### 2.4. Modelo Dart: `WatchPartySettings`

```dart
class WatchPartySettings {
  final bool enabled;
  final String userCode;
  final String? nickname;

  const WatchPartySettings({
    required this.enabled,
    required this.userCode,
    this.nickname,
  });
}
```

---

## 3. Comportamiento y Reglas de Negocio

### 3.1. Flujo de Activación y Visibilidad

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    PANEL "MIREMOS JUNTOS"                               │
│                    (dentro de Ajustes)                                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Switch Principal: "Miremos Juntos"                                     │
│  • Por defecto: OFF                                                     │
│  • Persistido en AppPreferences ('watch_party_enabled')                 │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
          ┌─────────────────┐             ┌─────────────────┐
          │  Switch OFF      │             │  Switch ON      │
          │  (Inactivo)      │             │  (Activo)       │
          └────────┬────────┘             └────────┬────────┘
                   │                               │
                   ▼                               ▼
          ┌─────────────────┐             ┌─────────────────┐
          │  Solo se muestra │             │  Se despliegan: │
          │  el switch       │             │  1. Tarjeta con │
          │  (UI limpia)     │             │     código      │
          │                  │             │     MOAI-XXXX   │
          │                  │             │  2. Gestionar   │
          │                  │             │     amigos      │
          │                  │             │  3. Prueba de   │
          │                  │             │     audio       │
          └─────────────────┘             └─────────────────┘
```

### 3.2. Reglas de Negocio

| Regla | Descripción |
|---|---|
| **RB-01** | El switch "Miremos Juntos" inicia por defecto en `OFF` y se persiste localmente en preferencias. |
| **RB-02** | Al activar el switch (`ON`), se despliegan en el panel: la tarjeta con el código de usuario propio, el botón "Gestionar Amigos" y el botón "Prueba de audio del control remoto". |
| **RB-03** | Al desactivar el switch (`OFF`), las opciones secundarias se ocultan inmediatamente, manteniendo la interfaz despejada. |
| **RB-04** | El código `user_code` es inmutable y único por dispositivo (asignado en el registro de `SPEC-22`). Es de solo lectura. |
| **RB-05** | Un usuario no puede agregarse a sí mismo como amigo. Si intenta ingresar su propio código, el sistema muestra: *"No puedes agregarte a ti mismo"*. |
| **RB-06** | La relación de amistad es **unidireccional simple**: si A agrega a B, B aparece en la lista de A con su estado online en vivo. B no tiene a A en su lista hasta que decida agregarlo con su respectivo código. |
| **RB-07** | Si el código ingresado no existe en la tabla `devices`, el sistema muestra: *"Usuario no encontrado"*. |
| **RB-08** | Si el usuario ya tenía a ese amigo registrado, el sistema muestra: *"Ya tienes a este usuario como amigo"*. |
| **RB-09** | Al eliminar a un amigo, se remueve el registro correspondiente de `device_friends` para el `device_id` local. |
| **RB-10** | El estado de presencia (online/offline) de los amigos se sincroniza en vivo utilizando el stream de Supabase sobre la tabla `devices`. |
| **RB-11** | En el diálogo "Agregar Amigo", el campo de texto tiene el prefijo `'MOAI-'` **fijo y bloqueado**. El usuario solo ingresa los 4 caracteres finales (alfanuméricos), los cuales se fuerzan automáticamente a mayúsculas. |
| **RB-12** | La opción "Prueba de audio del control remoto" abre el diálogo `TvVoiceTestDialog` disponible en la aplicación. |

---

## 4. Especificación de UI

### 4.1. Panel "Miremos Juntos" en Ajustes

| Propiedad | Valor |
|---|---|
| **Ubicación** | Sección dentro de `SettingsTvPanel` |
| **Título** | "Miremos Juntos" con icono `Icons.group_outlined` |
| **Switch** | Switch Material 3 con label "Activar Miremos Juntos" |

**UI cuando el switch está en ON:**
```
┌─────────────────────────────────────────────────────────────────────────┐
│  MIREMOS JUNTOS                                                         │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  [Switch]  Activar Miremos Juntos                                [ ON ] │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Tu código para compartir:                                      │   │
│  │                                                                 │   │
│  │              ┌─────────────────────────┐                       │   │
│  │              │    M O A I - 7 4 2 1    │                       │   │
│  │              └─────────────────────────┘                       │   │
│  │                                                                 │   │
│  │  Dile este código a tus amigos para que te agreguen.            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  [ Gestionar Amigos ] →                                                 │
│                                                                         │
│  [ Prueba de audio del control remoto ] →                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.2. Pantalla "Gestionar Amigos"

| Propiedad | Valor |
|---|---|
| **Título** | "Mis Amigos" con botón de regreso (`Icons.arrow_back`) |
| **Lista** | `ListView.builder` navegable con D-Pad |
| **Item amigo** | Nombre/Nickname + Código (`MOAI-XXXX`) + Indicador de presencia (🟢 En línea / ⚪ Desconectado) + Botón "Eliminar" |
| **Acción agregar** | Botón destacado "Agregar amigo" (`Icons.person_add_alt_1`) |

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ← Mis Amigos                                       [ + Agregar Amigo ] │
│  ─────────────────────────────────────────────────────────────────────  │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  🟢  Dario (MOAI-7421)                             [ Eliminar ] │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  ⚪  Juan (MOAI-1234)                              [ Eliminar ] │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.3. Diálogo "Agregar Amigo" (Optimizado para TV)

| Propiedad | Valor |
|---|---|
| **Título** | "Agregar Amigo" |
| **Prefijo fijo** | `MOAI-` (no editable, color secundario) |
| **Input** | Campo de 4 caracteres, `maxLength: 4`, texto en mayúsculas automático |
| **Botones** | "Cancelar" y "Agregar" |

```
┌─────────────────────────────────────────┐
│         Agregar Amigo                   │
│  ─────────────────────────────────────  │
│                                         │
│  Ingresa los 4 caracteres del código:   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  MOAI- [  7 4 2 1  ]            │   │
│  └─────────────────────────────────┘   │
│                                         │
│         ┌──────────┐  ┌──────────┐     │
│         │ Cancelar │  │ Agregar  │     │
│         └──────────┘  └──────────┘     │
│                                         │
└─────────────────────────────────────────┘
```

---

## 5. Especificación de Navegación D-Pad

| Pantalla / Componente | Tecla D-Pad | Acción |
|---|---|---|
| **Panel en Ajustes** | `ArrowDown` / `ArrowUp` | Alternar entre Switch $\leftrightarrow$ Gestionar Amigos $\leftrightarrow$ Prueba de Audio |
| **Panel en Ajustes** | `Enter` / `OK` | Conmutar switch o abrir pantalla/diálogo seleccionado |
| **Pantalla Mis Amigos** | `ArrowDown` / `ArrowUp` | Navegar entre amigos o subir al botón "Agregar Amigo" |
| **Pantalla Mis Amigos** | `ArrowRight` en tarjeta | Focalizar botón "Eliminar" |
| **Pantalla Mis Amigos** | `Enter` en "Eliminar" | Abrir diálogo de confirmación de borrado |
| **Diálogo Agregar** | `ArrowDown` | Mover foco del campo de texto a los botones de acción |
| **Diálogo Agregar** | `Back` | Cerrar diálogo sin guardar |

---

## 6. Criterios de Aceptación (Gherkin)

### CASO-WP-01: Activar "Miremos Juntos"
```gherkin
Given el usuario está en Ajustes con el switch "Miremos Juntos" en OFF
When presiona OK sobre el switch
Then el switch cambia a ON
And se despliega la tarjeta con su código "MOAI-XXXX"
And se despliegan los accesos a "Gestionar Amigos" y "Prueba de audio del control remoto"
And el estado se persiste en AppPreferences
```

### CASO-WP-02: Desactivar "Miremos Juntos"
```gherkin
Given el usuario está en Ajustes con el switch en ON
When presiona OK sobre el switch
Then el switch cambia a OFF
And las opciones secundarias se ocultan inmediatamente
```

### CASO-WP-03: Agregar amigo con éxito (con prefijo MOAI- fijo)
```gherkin
Given el usuario abre el diálogo "Agregar Amigo"
When ingresa los 4 caracteres "7421" correspondientes a un dispositivo existente
And presiona "Agregar"
Then se valida la existencia del código "MOAI-7421" en Supabase
And se inserta la relación en la tabla "device_friends"
And el amigo aparece en la lista con su estado online en tiempo real
And el diálogo se cierra mostrando confirmación
```

### CASO-WP-04: Intentar agregar código inexistente
```gherkin
Given el usuario ingresa un código que no existe en Supabase
When presiona "Agregar"
Then se muestra el mensaje de error "Usuario no encontrado"
And el diálogo permanece abierto
```

### CASO-WP-05: Intentar auto-agregarse
```gherkin
Given el usuario ingresa los 4 caracteres de su propio código
When presiona "Agregar"
Then se muestra el mensaje "No puedes agregarte a ti mismo"
And no se realiza ninguna petición de inserción a Supabase
```

### CASO-WP-06: Intentar agregar amigo ya existente
```gherkin
Given el usuario ingresa el código de un amigo que ya figura en su lista
When presiona "Agregar"
Then se muestra el mensaje "Ya tienes a este usuario como amigo"
```

### CASO-WP-07: Eliminar amigo
```gherkin
Given un amigo en la lista "Mis Amigos"
When el usuario selecciona "Eliminar" y confirma en el diálogo
Then se elimina el registro de "device_friends"
And el amigo desaparece de la lista inmediatamente
```

### CASO-WP-08: Abrir prueba de audio
```gherkin
Given el switch "Miremos Juntos" está en ON
When el usuario presiona "Prueba de audio del control remoto"
Then se despliega el diálogo nativo "TvVoiceTestDialog"
```

---

## 7. Dependencias Técnicas

| Dependencia | Propósito |
|---|---|
| `supabase_flutter` | Consultas, mutaciones y suscripciones Realtime a `device_friends` y `devices` |
| `shared_preferences` | Persistencia del estado activo/inactivo del switch (`watch_party_enabled`) |

---

## 8. Tareas de Implementación

| # | Tarea | Archivo Objetivo |
|---|---|---|
| 1 | Crear migración de la tabla `device_friends` con índices y RLS | `supabase/migrations/003_create_device_friends_table.sql` |
| 2 | Modelos Dart: `Friendship` y `FriendInfo` | `lib/models/friendship.dart`, `lib/models/friend_info.dart` |
| 3 | Proveedor de estado: `WatchPartySettingsProvider` | `lib/state/watch_party_settings_provider.dart` |
| 4 | Servicio Supabase: `SupabaseFriendsService` | `lib/services/supabase_friends_service.dart` |
| 5 | Diálogo de agregar amigo optimizado para TV | `lib/features/friends/widgets/add_friend_dialog.dart` |
| 6 | Diálogo de confirmación para eliminar amigo | `lib/features/friends/widgets/delete_friend_dialog.dart` |
| 7 | Pantalla "Mis Amigos" con soporte D-Pad | `lib/features/friends/screens/friends_screen.dart` |
| 8 | Integrar panel "Miremos Juntos" en Ajustes | `lib/features/settings/widgets/settings_tv_panel.dart` |
| 9 | Enlazar botón a `TvVoiceTestDialog` | `lib/features/settings/widgets/settings_tv_panel.dart` |
| 10 | Tests unitarios para el servicio y el provider | `test/services/supabase_friends_service_test.dart` |
