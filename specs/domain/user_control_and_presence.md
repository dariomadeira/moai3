# SPEC-22: Sistema de Control de Usuarios y Presencia (Supabase)

> **Estado**: Borrador  
> **Área**: Dominio / Control de Acceso y Presencia  
> **Archivos de Referencia**: `lib/services/device_identity_service.dart`, `lib/services/supabase_presence_service.dart`, `lib/features/loading/screens/loading_screen.dart`, `lib/features/blocked/screens/blocked_screen.md`

---

## 1. Propósito y Alcance

### Propósito
Implementar un sistema de control de acceso y presencia para MoAI 3 que permita:
- Identificar de forma única cada dispositivo
- Registrar la actividad del dispositivo (último inicio, versión, estado online)
- Bloquear dispositivos inactivos o no autorizados
- Notificar en tiempo real cuándo un dispositivo está conectado o desconectado

### Alcance (In Scope)
- Registro automático de dispositivo en Supabase al iniciar la app
- Pantalla de carga inicial con verificación de estado
- Pantalla de bloqueo con mensaje y cierre de app
- Actualización de estado online/offline al entrar/salir de la app
- Creación de registro para dispositivos que actualizan desde una versión antigua

### Non-Goals (Fuera de Alcance)
- Sistema de autenticación con contraseña (el control es por dispositivo, no por usuario)
- Gestión de perfiles de usuario múltiples por dispositivo
- Panel de administración web para gestionar dispositivos
- Sistema de suscripciones o pagos
- **Desbloqueo desde la app**: El desbloqueo de un dispositivo SOLO se realiza desde el panel de administración de Supabase. La app no tiene ninguna funcionalidad para modificar `is_active` o `block_reason`.

---

## 2. Definición de Tipos y Contratos

### 2.1. Tabla `devices` en Supabase

```sql
CREATE TABLE public.devices (
    device_id       TEXT PRIMARY KEY,           -- UUID v4 único del dispositivo
    user_code       VARCHAR(10) UNIQUE,         -- Código corto para compartir (ej. "MOAI-7421")
    nickname        VARCHAR(50),                -- Nombre del usuario (ej. "Dario")
    app_version     VARCHAR(20),                -- Versión de la app en uso
    is_active       BOOLEAN DEFAULT true,       -- false = dispositivo bloqueado
    block_reason    TEXT,                       -- Motivo del bloqueo (null si no está bloqueado)
    online          BOOLEAN DEFAULT false,      -- true = app abierta ahora mismo
    last_seen       TIMESTAMPTZ,               -- Último inicio de sesión
    first_seen      TIMESTAMPTZ DEFAULT now(),  -- Cuando se registró por primera vez
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- Índices para búsquedas rápidas
CREATE INDEX idx_devices_online ON public.devices(online);
CREATE INDEX idx_devices_is_active ON public.devices(is_active);
CREATE INDEX idx_devices_last_seen ON public.devices(last_seen);

-- Habilitar Realtime para detectar cambios en tiempo real
ALTER PUBLICATION supabase_realtime ADD TABLE public.devices;
```

### 2.2. Modelo Dart: `DeviceRecord`

```dart
class DeviceRecord {
  final String deviceId;
  final String? userCode;
  final String? nickname;
  final String appVersion;
  final bool isActive;
  final String? blockReason;
  final bool online;
  final DateTime? lastSeen;
  final DateTime firstSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeviceRecord({
    required this.deviceId,
    this.userCode,
    this.nickname,
    required this.appVersion,
    required this.isActive,
    this.blockReason,
    required this.online,
    this.lastSeen,
    required this.firstSeen,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceRecord.fromJson(Map<String, dynamic> json) {
    return DeviceRecord(
      deviceId: json['device_id'] as String,
      userCode: json['user_code'] as String?,
      nickname: json['nickname'] as String?,
      appVersion: json['app_version'] as String? ?? 'unknown',
      isActive: json['is_active'] as bool? ?? true,
      blockReason: json['block_reason'] as String?,
      online: json['online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null 
          ? DateTime.parse(json['last_seen'] as String) 
          : null,
      firstSeen: DateTime.parse(json['first_seen'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'user_code': userCode,
      'nickname': nickname,
      'app_version': appVersion,
      'is_active': isActive,
      'block_reason': blockReason,
      'online': online,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}
```

### 2.3. Modelo Dart: `DeviceIdentity`

```dart
class DeviceIdentity {
  final String deviceId;
  final String appVersion;
  final DateTime firstLaunch;

  DeviceIdentity({
    required this.deviceId,
    required this.appVersion,
    required this.firstLaunch,
  });
}
```

---

## 3. Comportamiento y Reglas de Negocio

### 3.1. Flujo de Arranque (Cold Start)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ARRANQUE DE LA APP                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  PASO 1: Obtener o Generar Device ID                                   │
│  • Leer UUID de SharedPreferences                                       │
│  • Si no existe → generar UUID v4 y guardar                            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  PASO 2: Mostrar Pantalla de Carga (LoadingScreen)                     │
│  • UI: Spinner + texto "Conectando..."                                 │
│  • Mientras tanto, ejecutar verificación en segundo plano              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  PASO 3: Consultar Supabase                                            │
│  • SELECT * FROM devices WHERE device_id = {deviceId}                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
          ┌─────────────────┐             ┌─────────────────┐
          │  REGISTRO EXISTE │             │ NO EXISTE REGISTRO│
          └────────┬────────┘             └────────┬────────┘
                   │                               │
                   ▼                               ▼
          ┌─────────────────┐             ┌─────────────────┐
          │ Actualizar:      │             │ Crear registro:  │
          │ • last_seen = now│             │ • device_id      │
          │ • app_version    │             │ • app_version    │
          │ • online = true  │             │ • is_active = true│
          └────────┬────────┘             │ • online = true  │
                   │                      └────────┬────────┘
                   │                               │
                   └───────────────┬───────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────┐
                    │  VERIFICAR is_active         │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                             │
                    ▼                             ▼
          ┌─────────────────┐          ┌─────────────────┐
          │ is_active = true │          │ is_active = false│
          └────────┬────────┘          └────────┬────────┘
                   │                             │
                   ▼                             ▼
          ┌─────────────────┐          ┌─────────────────┐
          │  IR AL HOME      │          │  PANTALLA DE    │
          │  (HomeScreen)    │          │  BLOQUEO        │
          └─────────────────┘          │  (BlockedScreen) │
                                       └─────────────────┘
```

### 3.2. Flujo de Salida de la App

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SALIDA DE LA APP                                │
│  (AppLifecycleState.paused / detached)                                 │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Actualizar Supabase:                                                   │
│  • UPDATE devices SET online = false, updated_at = now()               │
│  • WHERE device_id = {deviceId}                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.3. Reglas de Negocio

| Regla | Descripción |
|---|---|
| **RB-01** | El `device_id` es inmutable y único por instalación. Se genera una sola vez y se persiste en `SharedPreferences`. |
| **RB-02** | Si el registro no existe en Supabase, se crea automáticamente con `is_active = true`. |
| **RB-03** | El campo `online` debe ser `true` mientras la app esté en primer plano y `false` cuando esté en segundo plano o cerrada. Se implementa con ciclo de vida inmediato + Heartbeat de 45 segundos en primer plano + tarea programada en Supabase (`pg_cron`) que pasa a `online = false` a dispositivos con `last_seen` mayor a 2 minutos. |
| **RB-04** | Si `is_active = false`, el dispositivo no puede acceder al home. La app muestra la pantalla de bloqueo y se cierra al presionar "Aceptar". |
| **RB-05** | La versión de la app se registra en cada arranque para trazabilidad. |
| **RB-06** | La pantalla de carga debe tener un timeout máximo de 10 segundos. Si Supabase no responde, mostrar error de conexión con opción de reintentar. |
| **RB-07** | El `device_id` se obtiene de `SharedPreferences` con la clave `'device_id'`. Si no existe, se genera con `UUID v4`. |
| **RB-08** | El `user_code` se genera automáticamente al crear el registro (formato: `MOAI-XXXX` donde XXXX son 4 caracteres alfanuméricos). Es único y no puede repetirse. |
| **RB-09** | El `nickname` es opcional. Inicialmente es `null` y puede ser configurado por el usuario en el futuro (spec de `moai_voice`). |
| **RB-10** | El `block_reason` solo se establece desde el panel de administración de Supabase. La app nunca lo modifica, solo lo lee. |

### 3.4. Uso del Timeout de Conexión

El timeout de 10 segundos se usa en la **Pantalla de Carga (`LoadingScreen`)** durante el proceso de verificación con Supabase:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    LOADING SCREEN - FLUJO DE TIMEOUT                    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Iniciar temporizador de 10 segundos                                    │
│  (Future.delayed(Duration(seconds: 10)))                                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
                    ▼                               ▼
          ┌─────────────────┐             ┌─────────────────┐
          │ Supabase responde│             │ Timeout (10s)   │
          │ antes de 10s     │             │ sin respuesta   │
          └────────┬────────┘             └────────┬────────┘
                   │                               │
                   ▼                               ▼
          ┌─────────────────┐             ┌─────────────────┐
          │ Cancelar timer   │             │ Cancelar petición│
          │ Continuar flujo  │             │ Mostrar error:   │
          │ (Home/Bloqueo)   │             │ "No se pudo       │
          └─────────────────┘             │  conectar..."    │
                                          │ + botón Reintentar│
                                          └─────────────────┘
```

**Comportamiento del timeout:**
- Se usa `Future.any()` para competir entre la petición a Supabase y el temporizador.
- Si Supabase responde primero → se cancela el timer y se continúa el flujo normal.
- Si el timeout llega primero → se cancela la petición a Supabase y se muestra el error.
- El botón "Reintentar" reinicia todo el proceso desde el Paso 1.

---

## 4. Especificación de UI

### 4.1. Pantalla de Carga (`LoadingScreen`)

| Propiedad | Valor |
|---|---|
| **Fondo** | `ColorScheme.surface` (sólido, sin gradientes) |
| **Spinner** | `CircularProgressIndicator` con `color: ColorScheme.primary` |
| **Texto** | "Conectando..." con `titleMedium` en `ColorScheme.onSurface` |
| **Posición** | Centrado en pantalla |
| **Timeout** | 10 segundos → mostrar error de conexión |

### 4.2. Pantalla de Bloqueo (`BlockedScreen`)

| Propiedad | Valor |
|---|---|
| **Fondo** | `ColorScheme.surface` (sólido) |
| **Icono** | `Icons.block` (filled) en `ColorScheme.error`, tamaño 64 |
| **Título** | "Dispositivo Bloqueado" en `headlineSmall` |
| **Mensaje dinámico** | Si `blockReason != null` → mostrar `blockReason` en `bodyLarge`. Si es `null` → "Este dispositivo ha sido deshabilitado. Contacta al administrador para más información." |
| **Botón** | `FilledButton` con texto "Aceptar", `ColorScheme.primary` |
| **Acción del botón** | `SystemNavigator.pop()` para cerrar la app |
| **Posición** | Centrado en pantalla |

**Ejemplo de UI con `blockReason`:**
```
┌─────────────────────────────────────────┐
│                                         │
│              🚫 (icono block)           │
│                                         │
│         Dispositivo Bloqueado           │
│                                         │
│  "Este dispositivo fue deshabilitado    │
│   por violación de los términos de      │
│   servicio."                            │
│                                         │
│         ┌─────────────────┐             │
│         │    Aceptar      │             │
│         └─────────────────┘             │
│                                         │
└─────────────────────────────────────────┘
```

---

## 5. Criterios de Aceptación (Gherkin)

### CASO-UC-01: Primer arranque con registro existente y activo

```gherkin
Given un dispositivo con device_id "abc-123" registrado en Supabase con is_active = true
When el usuario abre la app por primera vez
Then se muestra la pantalla de carga "Conectando..."
And se actualiza last_seen con la fecha actual
And se actualiza app_version con la versión actual de la app
And se establece online = true
And se navega a la pantalla Home
```

### CASO-UC-02: Arranque con registro existente pero inactivo

```gherkin
Given un dispositivo con device_id "abc-123" registrado en Supabase con is_active = false y block_reason = "Violación de términos de servicio"
When el usuario abre la app
Then se muestra la pantalla de carga "Conectando..."
And se actualiza last_seen con la fecha actual
And se establece online = true
And se muestra la pantalla de bloqueo con el mensaje "Violación de términos de servicio"
When el usuario presiona el botón "Aceptar"
Then la app se cierra
```

### CASO-UC-02b: Arranque con registro inactivo sin motivo de bloqueo

```gherkin
Given un dispositivo con device_id "abc-123" registrado en Supabase con is_active = false y block_reason = null
When el usuario abre la app
Then se muestra la pantalla de bloqueo con el mensaje por defecto "Este dispositivo ha sido deshabilitado. Contacta al administrador para más información."
```

### CASO-UC-03: Arranque sin registro (app actualizada desde versión antigua)

```gherkin
Given un dispositivo con device_id "abc-123" que NO existe en Supabase
When el usuario abre la app
Then se muestra la pantalla de carga "Conectando..."
And se crea un nuevo registro con:
  | device_id   | abc-123          |
  | user_code   | (generado)       |
  | nickname    | (vacío/null)     |
  | is_active   | true             |
  | block_reason| null             |
  | online      | true             |
  | app_version | (versión actual) |
  | first_seen  | (fecha actual)   |
  | last_seen   | (fecha actual)   |
And se navega a la pantalla Home
```

### CASO-UC-04: Salida de la app (online → false)

```gherkin
Given un dispositivo con online = true en Supabase
When el usuario minimiza la app o cambia a otra app
Then se actualiza online = false en Supabase
And se actualiza updated_at con la fecha actual
```

### CASO-UC-05: Timeout de conexión

```gherkin
Given un dispositivo intentando conectarse a Supabase
When pasan 10 segundos sin respuesta de Supabase
Then se muestra un mensaje de error "No se pudo conectar. Verifica tu conexión."
And se muestra un botón "Reintentar"
When el usuario presiona "Reintentar"
Then se reinicia el proceso de verificación
```

### CASO-UC-06: Reaparición de la app (online → true)

```gherkin
Given un dispositivo con online = false en Supabase
When el usuario vuelve a abrir la app
Then se actualiza online = true en Supabase
And se actualiza last_seen con la fecha actual
And se navega a la pantalla Home (si is_active = true)
```

---

## 6. Dependencias Técnicas

| Dependencia | Uso |
|---|---|
| `supabase_flute` | Cliente de Supabase para consultas y actualizaciones |
| `shared_preferences` | Persistencia del `device_id` local |
| `uuid` | Generación de UUID v4 para nuevos dispositivos |
| `package_info_plus` | Obtener la versión actual de la app |

---

## 7. Consideraciones de Seguridad

1. **RLS (Row Level Security)**: La tabla `devices` debe tener políticas RLS que permitan:
   - SELECT: Solo el propio dispositivo (por `device_id`)
   - INSERT: Solo para crear el propio registro
   - UPDATE: Solo para actualizar el propio registro

2. **Anon Key**: La app usa la `anon key` de Supabase. Las políticas RLS deben ser estrictas para evitar que un dispositivo modifique registros ajenos.

3. **Rate Limiting**: Supabase tiene rate limiting por defecto. En caso de muchos intentos de conexión, se debe manejar el error `429 Too Many Requests`.

---

## 8. Tareas de Implementación

| # | Tarea | Archivo |
|---|---|---|
| 1 | Crear tabla `devices` en Supabase con RLS | `supabase/migrations/001_create_devices_table.sql` |
| 2 | Crear `DeviceRecord` model | `lib/models/device_record.dart` |
| 3 | Crear `DeviceIdentityService` (generar/leer UUID + user_code) | `lib/services/device_identity_service.dart` |
| 4 | Crear `SupabasePresenceService` (consultar/actualizar registro) | `lib/services/supabase_presence_service.dart` |
| 5 | Crear `LoadingScreen` con spinner y timeout | `lib/features/loading/screens/loading_screen.dart` |
| 6 | Crear `BlockedScreen` con mensaje dinámico y botón | `lib/features/blocked/screens/blocked_screen.dart` |
| 7 | Integrar flujo de arranque en `main.dart` | `lib/main.dart` |
| 8 | Integrar actualización de online/offline con `AppLifecycleState` | `lib/main.dart` o `lib/app.dart` |
| 9 | Tests unitarios para `DeviceIdentityService` | `test/services/device_identity_service_test.dart` |
| 10 | Tests unitarios para `SupabasePresenceService` | `test/services/supabase_presence_service_test.dart` |
