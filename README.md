# MoAI 3 — Aplicación de TV para Android con Arquitectura de Plugins

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Android TV](https://img.shields.io/badge/Platform-Android%20TV-3DDC84?logo=android)](https://developer.android.com/tv)
[![Architecture](https://img.shields.io/badge/Model-SSD%20(Spec--Driven)-blueviolet)](#documentación-y-especificaciones)
[![Version](https://img.shields.io/badge/Version-3.0.14-success)](#)

**MoAI 3** es una aplicación moderna y de alto rendimiento diseñada específicamente para **Android TV**, construida con Flutter en la capa de presentación y Kotlin en el host nativo. Emplea el modelo de desarrollo **SSD (Spec-Driven Development)** y un motor modular de **plugins dinámicos (.dex)** cargados en tiempo de ejecución.

---

## Características Principales

### 📺 Experiencia de Usuario y Navegación TV (M3 Expressive)
- **Control Remoto y D-Pad First**: Navegación determinista con trampas de foco, sincronización de scroll y captura direccional en grandes pantallas.
- **Navigation Rail Lateral**: Acceso rápido a TV, Calendario Deportivo y Ajustes en el pie de página mediante saltos direccionales.
- **Trilogía de Pestañas Flotantes**: *Explorar*, *Buscar* (con panel simétrico de 12 dp y salto alfabético) y *Marcadores*.
- **Estética de Foco con Borde Primario (Anti-Washout)**: Tanto en la grilla de canales (`ChannelGridTile`) como en la barra de favoritos (`ViewerFavoriteTile`), el foco resalta con un borde de 2 dp `scheme.primary` preservando el fondo base y la nitidez de los logotipos.

### ⚽ Agenda Deportiva de Eventos en Vivo
- **Grilla Semanal de 7 Días**: Visualización completa de eventos programados, transmisiones en vivo y eventos finalizados.
- **Ciclo de Vida Determinista**: Eventos en vivo prioritarios (`live`), próximos (`upcoming`) y finalizados atenuados (`finished` no-op) libres de caracteres emoji.
- **Modal de Sintonización Directa**: Al seleccionar un partido, detecta automáticamente mediante `CalendarChannelMatcher` los canales activos instalados capaces de transmitirlo y permite sintonizarlos al instante en dos columnas.
- **Notificaciones Flotantes**: Snackbars persistentes configurables al comenzar eventos suscritos.

### 🔌 Motor Modular de Plugins (.dex)
- **Carga Dinámica en Runtime**: Soporte para fuentes externas compiladas en DexClassLoader sin necesidad de recompilar la aplicación principal.
- **Validación de Manifiesto y Contratos**: Control de versiones SemVer (`CURRENT_CONTRACT = 1`) y cálculo de SHA-256.
- **Resiliencia de Red**: Soporte nativo para seguimiento de redirecciones HTTP `301..308` (hasta 5 saltos) en descargas de plugins.
- **Actualizaciones OTA Silenciosas y Asistidas**: Comprobación secuencial de nuevas versiones con diálogo de actualización TV.

### ⚡ Reproductor de Video de Alto Rendimiento
- **Renderizado Directo por SurfaceTexture**: Reproducción mediante ExoPlayer directamente en textura gráfica sin la sobrecarga ni los problemas de tearing de `PlatformViews`.
- **Watchdog Anti-Spinner**: Timeout de 45 segundos para recuperación automática ante enlaces colgados.
- **Liberación Segura de Recursos**: Métodos `dispose()` sincrónicos y protección reactiva con `SafeChangeNotifier` para prevenir caídas de ciclo de vida.

### 🔒 Seguridad y Control Parental
- **PIN Efímero de Sesión**: Protección de canales para adultos con reseteo seguro al reiniciar la app.
- **Diálogo TV Continuo (Zero-Flash)**: Máquina de estados interna multi-paso sin parpadeos de pantalla ni cierres de ruta modal.

---

## Arquitectura del Proyecto

```
moai3/
├── android/               # Host nativo Android (Kotlin, ExoPlayer, PluginLoader)
├── assets/                # Traducciones i18n (es.json) y recursos gráficos
├── docs/                  # Documentos técnicos, guías y propuestas de diseño
├── lib/
│   ├── engine/            # MoaiEnginePlayer y vista de textura de video
│   ├── features/
│   │   ├── calendar/      # Grilla semanal y suscripciones de la agenda deportiva
│   │   ├── channels/      # Paneles de canales, categorías y países
│   │   ├── home/          # HomeScreen, áreas principales (TV, Calendario, Ajustes)
│   │   ├── search/        # Panel y componentes de búsqueda
│   │   └── settings/      # Ajustes de TV, fuentes, PIN y agenda
│   ├── focus/             # Controladores de foco D-Pad y constantes de layout TV
│   ├── models/            # Entidades canónicas (Channel, CalendarEvent, etc.)
│   ├── services/          # Actualizaciones, emparejador de canales y servicios HTTP
│   ├── state/             # Providers de estado (Channel, Calendar, TV Settings)
│   └── widgets/           # Componentes M3, diálogos TV, tarjetas y tiles
├── specs/                 # Especificaciones formales SSD (Fuente de verdad)
└── test/                  # Suite completa de pruebas unitarias y de widgets
```

---

## Documentación y Especificaciones (SSD)

MoAI 3 se rige bajo la metodología **Spec-Driven Development**. Toda decisión arquitectónica está documentada en la carpeta [`specs/`](specs/README.md):

- [SPEC-00: Arquitectura General de MoAI 3](specs/00_architecture_overview.md)
- [SPEC-10: Contrato de Plugins v1 (.dex)](specs/contracts/plugin_contract_v1.md)
- [SPEC-11: Especificación de MethodChannels](specs/contracts/method_channels.md)
- [SPEC-20: Dominio de Canales, Grupos y Categorías](specs/domain/channels_and_categories.md)
- [SPEC-21: Preferencias, Temas y Seguridad Parental](specs/domain/preferences_and_security.md)
- [SPEC-30: Motor de Navegación y Foco para Android TV](specs/features/tv_navigation_and_focus.md)
- [SPEC-31: Ciclo de Vida y Actualizaciones de Plugins](specs/features/plugin_runtime_and_updates.md)
- [SPEC-32: Motor de Reproducción y Ciclo de Vida del Stream](specs/features/player_engine.md)
- [SPEC-33: Componentes de Interfaz de Usuario TV, Pestañas y Diálogos](specs/features/tv_ui_components_and_layout.md)
- [SPEC-34: Diagnóstico y Captura de Voz del Control Remoto](specs/features/tv_remote_voice_input.md)
- [SPEC-35: Agenda Deportiva de Eventos en Vivo y Notificaciones](specs/features/sports_calendar_and_events.md)
- [SPEC-40: Matriz de Criterios de Aceptación (Baseline v3.0.14)](specs/verification/baseline_acceptance_matrix.md)

---

## Verificación y Calidad

Para ejecutar el análisis estático y la suite completa de pruebas:

```bash
# Análisis estático de código Dart
dart analyze

# Ejecutar los 136 tests automatizados
flutter test
```
