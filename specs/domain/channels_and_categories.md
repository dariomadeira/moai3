# SPEC-20: Modelo de Dominio de Canales, Grupos y Categorías

> **Estado**: Congelado (Baseline v3.0.11)  
> **Área**: Dominio y Datos  
> **Archivos de Referencia**: `lib/models/channel.dart`, `lib/models/channel_group.dart`, `lib/services/plugin_host_service.dart`

---

## 1. Modelo de Datos: `Channel`

La clase `Channel` es la entidad representativa del catálogo consumido por la interfaz de usuario de MoAI 3.

```dart
class Channel {
  final String id;
  final String name;
  final String logoUrl;
  final String country;
  final String category;
  final Map<String, String>? customHeaders;
  final List<String> fallbackUrls;

  // Atributos de origen por Plugin (.dex)
  final String? pluginId;
  final String? pluginChannelId;
  final String? pluginName;
  final String? pluginTag;
}
```

### 1.1. Reglas de Identificación de Canales de Plugins
Para evitar colisiones entre canales provistos por diferentes plugins o fuentes estáticas, se aplica el siguiente esquema de asignación de ID canónico:
$$\text{channelId} = \text{"plugin:"} + \text{source.id} + \text{":"} + \text{info.id}$$

*Ejemplo*: `plugin:moai_ar:telefe` o `plugin:moai_daddylive:espn_premium`

### 1.2. Propiedades Computadas
- `isPluginChannel`: Retorna `true` si `pluginId != null && pluginChannelId != null`. Indica que el canal no cuenta con URL fija previa y debe resolverse dinámicamente mediante `IPlugin.resolve` antes de reproducirse.
- `url`: Retorna la primera URL disponible en `fallbackUrls`, o cadena vacía si no existe ninguna.
- `isAdult`: Heurística para clasificar el canal como contenido para adultos. Retorna `true` si:
  - `category.trim().toLowerCase() == 'adultos'`
  - `country.trim().toLowerCase() == 'adultos'`
  - `name.toLowerCase()` contiene `'18+'` o `'+18'`.

---

## 2. Normalización y Sanitización de Datos

A fin de evitar tarjetas visuales en blanco o inconsistencias en los filtros de la interfaz TV:

1. **Fallback de Categoría**:
   Si `category` proviene nula, vacía o con espacios en blanco, se sustituye automáticamente por `'General'`.
2. **Fallback de País**:
   Si `country` proviene nula, vacía o con espacios en blanco, se sustituye automáticamente por `'General'`.
3. **Manejo de Aspect Ratio de Logos**:
   Los logos de los canales no deben deformarse ni forzar un estiramiento desproporcionado; se presentan respetando su relación de aspecto original (`BoxFit.contain`).

---

## 3. Modelo de Datos: `ChannelGroup`

Agrupa canales para visualización en carruseles o secciones de la pantalla de inicio y explorador:

```dart
class ChannelGroup {
  final String id;
  final String title;
  final List<Channel> channels;
  final String? iconName;
}
```

Las agrupaciones pueden basarse en:
- **Categorías temáticas**: Noticias, Deportes, Variedades, Cine, Infantil, Adultos.
- **Fuentes / Plugins**: Canales aportados por cada plugin instalado (identificados con su `pluginTag` visual).
- **Favoritos / Marcadores**: Colección persistida de canales marcados por el usuario.

### 3.1. Iconografía de grupos (`GroupCard` / `MoaiIcons`)

Claves `icon` persistidas → `IconData` centralizado en `lib/theme/moai_icons.dart`:

| `icon` key | IconData |
| :--- | :--- |
| `bookmark` (grupo Marcadores) | `MoaiIcons.tvSignin` (`Symbols.tv_signin`) |
| `favorite` | `MoaiIcons.favoriteOutline` |
| `no_adults` | `MoaiIcons.explicitOutlined` |
| `sports_soccer` | `MoaiIcons.sportsSoccerOutlined` |
| `movie` | `MoaiIcons.movieOutlined` |
| `child_hat` | `MoaiIcons.childCareOutlined` |
| `newspaper` | `MoaiIcons.newspaperOutlined` |
| `tv_gen` | `MoaiIcons.tvOutlined` |
| `language` | `MoaiIcons.languageOutlined` |
| *(desconocida)* | `MoaiIcons.tvSignin` (fallback) |

### 3.2. Iconografía de países (`CountryCard`)

Todos los ítems del panel Países usan `MoaiIcons.tvDisplays` (`Symbols.tv_displays`).

### 3.3. Iconografía de categorías y grupos

Mapa canónico en `MoaiIcons.tvCategoryIcons` / constantes `tvCategory*` (Aire, Deportes, Cine, …).  
Resolución: `MoaiIcons.tvCategoryIconFor(name)`, sin importar tildes ni mayúsculas (`normalizeText`) → fallback `tvCategoryFallback`.  
Grupos: `MoaiIcons.groupIconFor(iconKey)`. Los paneles usan `TvIconListCard` directamente; ningún otro archivo mapea íconos (SPEC-50 §4).
