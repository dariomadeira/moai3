# Especificaciones Canónicas de MoAI 3 (Modelo SSD)

Bienvenido al repositorio de especificaciones canónicas de **MoAI 3**, estructurado bajo el modelo **SSD (Spec-Driven Development)**.

Todas las decisiones de diseño, contratos de plugins, modelos de datos y flujos de usuario están formalizados aquí como la **única fuente de verdad** del proyecto.

---

## Índice General de Especificaciones

### 1. Sistema y Metodología
- [SPEC-00: Arquitectura General de MoAI 3](00_architecture_overview.md)  
  *Stack tecnológico, diagrama de capas Flutter <-> Android nativo y principios de diseño.*
- [SPEC-01: Guía Operativa del Modelo SSD](01_ssd_workflow_guide.md)  
  *Procedimiento para crear, modificar y verificar especificaciones antes de codificar.*

### 2. Contratos e Interoperabilidad
- [SPEC-10: Contrato de Plugins v1 (.dex)](contracts/plugin_contract_v1.md)  
  *Definición formal e inmutable de IPlugin, PluginManifest, ResolveRequest y ResolveResult.*
- [SPEC-11: Especificación de Canales de Plataforma (MethodChannels)](contracts/method_channels.md)  
  *Comandos, payloads y eventos entre Flutter y el Host Android nativo (Player, Plugins, Device).*

### 3. Modelos de Dominio y Datos
- [SPEC-20: Dominio de Canales, Grupos y Categorías](domain/channels_and_categories.md)  
  *Estructura de entidades, IDs canónicos de plugins y normalización de textos/categorías.*
- [SPEC-21: Preferencias del Sistema, Temas y Seguridad Parental](domain/preferences_and_security.md)  
  *Control parental con PIN de sesión efímero, calibración de overscan TV y temas M3 Expressive.*

### 4. Funcionalidades y Experiencia de Usuario
- [SPEC-30: Motor de Navegación y Foco para Android TV (D-Pad)](features/tv_navigation_and_focus.md)  
  *Determinismo de foco, sincronización de listas virtuales, traps y captura de teclas.*
- [SPEC-31: Ciclo de Vida y Actualizaciones de Plugins](features/plugin_runtime_and_updates.md)  
  *Verificación secuencial de actualizaciones, deducción de manifiestos y hot-update.*
- [SPEC-32: Motor de Reproducción de Video y Ciclo de Vida del Stream](features/player_engine.md)  
  *Renderizado a SurfaceTexture sin PlatformViews, máquina de estados y watchdog de 45 segundos.*

### 5. Verificación y Calidad
- [SPEC-40: Matriz de Criterios de Aceptación (Baseline v3.0.11)](verification/baseline_acceptance_matrix.md)  
  *Casos de prueba Given-When-Then verificables para validar el comportamiento del sistema.*
