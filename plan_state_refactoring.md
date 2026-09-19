# Plan de Refactorización de Estado (Multi-Provider Architecture)

## 📌 Objetivo
Dividir la clase monolítica `AppState` (que actualmente agrupa configuraciones de tema, catálogo de canales, favoritos y ajustes de sobrepantalla/logs) en **Providers independientes y desacoplados**. Esto eliminará reconstrucciones cruzadas entre componentes y mejorará la mantenibilidad y testabilidad de la aplicación en dispositivos Android TV.

---

## 🏗️ Nueva Estructura de Providers

### 1. `ThemeProvider` (`lib/state/theme_provider.dart`)
* **Responsabilidad**: Control de la apariencia visual y personalización de la interfaz.
* **Propiedades y Métodos**:
  - `bool darkMode`
  - `int accentColorIndex`
  - `ThemeMode get themeMode`
  - `Color get accentSeed`
  - `Future<void> setDarkMode(bool value)`
  - `Future<void> setAccentColorIndex(int index)`

### 2. `ChannelProvider` (`lib/state/channel_provider.dart`)
* **Responsabilidad**: Gestión del catálogo de canales, grupos y el canal en reproducción.
* **Propiedades y Métodos**:
  - `List<Channel> get allChannels`
  - `List<ChannelGroup> get groups`
  - `Channel? get selectedChannel`
  - `bool get isLoadingChannels`
  - `String? get channelLoadError`
  - `void selectChannel(Channel channel)`
  - `Future<void> createGroup(String name, [List<String> channelIds])`
  - `Future<void> deleteGroup(String id)`

### 3. `FavoritesProvider` (`lib/state/favorites_provider.dart`)
* **Responsabilidad**: Lista de favoritos del usuario y persistencia local.
* **Propiedades y Métodos**:
  - `List<String> get favoriteChannelIds`
  - `bool isFavorite(Channel channel)`
  - `void toggleFavorite(Channel channel)`
  - `void clearAllFavorites()`

### 4. `TvSettingsProvider` (`lib/state/tv_settings_provider.dart`)
* **Responsabilidad**: Ajustes físicos del televisor (overscan/calibración y depuración).
* **Propiedades y Métodos**:
  - `bool showTvLog`
  - `double overlapPaddingX`
  - `double overlapPaddingY`
  - `bool hasOverlapConfig`
  - `Future<void> setOverlapConfig({required double x, required double y})`
  - `Future<void> setShowTvLog(bool value)`

---

## ⚡ Beneficios Principales

1. **Cero Acoplamiento Innecesario**: 
   Cambiar un favorito o alternar el canal seleccionado **jamás** notificará a los componentes que escuchan cambios de tema o configuraciones de pantalla.
2. **Mayor Fluidez en Android TV**:
   Al aislar cada dominio de estado, las llamadas a `notifyListeners()` ejecutan reconstrucciones quirúrgicas únicamente en los widgets interesados.
3. **Pruebas Unitarias Aisladas**:
   Permite probar de forma unitaria la lógica de favoritos o temas sin necesidad de inicializar todo el repositorio de canales o plugins.

---

## 🚀 Plan de Ejecución Paso a Paso (Para Mañana)

### Fase 1: Creación de Nuevos Providers (`lib/state/`)
- [ ] Crear `lib/state/theme_provider.dart`.
- [ ] Crear `lib/state/favorites_provider.dart`.
- [ ] Crear `lib/state/tv_settings_provider.dart`.
- [ ] Refactorizar `lib/state/app_state.dart` a `lib/state/channel_provider.dart`.

### Fase 2: Registro en `main.dart`
- [ ] Actualizar el `MultiProvider` en `lib/main.dart` para inyectar todos los nuevos providers:
  ```dart
  MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: themeProvider),
      ChangeNotifierProvider.value(value: channelProvider),
      ChangeNotifierProvider.value(value: favoritesProvider),
      ChangeNotifierProvider.value(value: tvSettingsProvider),
      ChangeNotifierProvider.value(value: playbackStats),
      ChangeNotifierProvider.value(value: debugLog),
      ChangeNotifierProvider.value(value: pluginHost),
    ],
    child: MyApp(router: router),
  )
  ```

### Fase 3: Migración de Consumidores en UI
- [ ] `lib/main.dart`: Usar `ThemeProvider`.
- [ ] `lib/features/home/screens/home_screen.dart`: Usar `TvSettingsProvider`.
- [ ] `lib/features/home/areas/home_tv_area.dart`: Escuchar `ChannelProvider`, `FavoritesProvider` y `TvSettingsProvider` por separado.
- [ ] `lib/features/settings/widgets/`: Actualizar paneles de ajustes general, TV y acerca de.

### Fase 4: Validación y Pruebas
- [ ] Actualizar suite de tests en `test/` para reflejar la división de providers.
- [ ] Ejecutar `flutter test` y confirmar paso limpio de todas las pruebas.
- [ ] Compilar APK de depuración y validar en Android TV.
