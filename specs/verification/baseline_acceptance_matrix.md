# SPEC-40: Matriz de Criterios de Aceptación (Baseline v3.0.11)

> **Estado**: Congelado (Baseline v3.0.11)  
> **Área**: Calidad y Verificación / Matriz de Pruebas

---

## 1. Módulo: Motor de Plugins Nativo (.dex)

### CASO-PLUG-01: Validación de Contrato al Instalar
- **Given**: Un archivo `.dex` con `minContrato = 2` y la app MoAI 3 ejecutando `CURRENT_CONTRACT = 1`.
- **When**: Se invoca el método `install` a través de `com.infomak.moai.tv/plugin`.
- **Then**: La instalación debe ser rechazada con código `CONTRACT_MISMATCH` y no agregarse al catálogo.

### CASO-PLUG-02: Sanitización de Cadenas Vacías
- **Given**: Un plugin que declara un canal con `categoria = ""` y `pais = "   "`.
- **When**: `PluginChannelCatalog` procesa la fuente para incorporarla a la app.
- **Then**: El objeto `Channel` resultante debe tener `category = "General"` y `country = "General"`, garantizando que la tarjeta visual se renderice con texto válido.

---

## 2. Módulo: Control Parental y Seguridad

### CASO-PAR-01: Estado Inicial Seguro al Iniciar la App
- **Given**: Una app con PIN parental configurado y un canal para adultos guardado como última reproducción previa.
- **When**: La aplicación se inicia desde cero (cold start).
- **Then**: `isAdultUnlocked` debe ser estrictamente `false` y el reproductor debe sintonizar el canal seguro determinado por `_findSafeFallbackChannel()`, nunca el canal adulto.

### CASO-PAR-02: Desbloqueo Efímero de Sesión
- **Given**: Una sesión bloqueada y un usuario intentando sintonizar un canal marcado con `isAdult == true`.
- **When**: Se ingresa el PIN configurado en el diálogo TV.
- **Then**: `unlockAdultForSession()` debe activarse, permitiendo reproducir el canal sin re-solicitar el PIN hasta que la app sea cerrada o se invoque `lockAdult()`.

---

## 3. Módulo: Navegación y Foco en Android TV

### CASO-NAV-01: Sin Pérdida de Foco en Desplazamiento Rápido
- **Given**: Una lista extensa de 200 canales con virtualización activa.
- **When**: El usuario mantiene presionada la flecha direccional Abajo en el control remoto para saltar 30 posiciones.
- **Then**: `FocusScrollSync.scrollToIndex` debe desplazar el viewport y garantizar mediante `requestFocusAtIndex` que el `FocusNode` del ítem 30 quede enfocado sin saltar al inicio ni caer en el limbo.

### CASO-NAV-02: Retorno a Barra de Pestañas Flotante
- **Given**: El cursor posicionado en la tarjeta de canal superior de la vista activa.
- **When**: El usuario presiona la tecla `ArrowUp`.
- **Then**: `TvKeyHandler` debe transferir el foco a la pestaña activa en la barra de pestañas flotante M3.

---

## 4. Módulo: Reproductor y Watchdog

### CASO-PLY-01: Interrupción por Watchdog ante Buffer Colgado
- **Given**: Un stream en estado `MoaiEngineState.buffering` cuya conexión TCP no envía datos.
- **When**: Transcurren 45 segundos sin emitirse `firstFrame` ni `ready`.
- **Then**: El watchdog debe forzar el paso a `MoaiEngineState.error` y permitir al orquestador solicitar reintento con `fallbackIndex = 1`.
