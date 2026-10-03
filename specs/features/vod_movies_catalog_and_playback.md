# SPEC-38: Catálogo de Películas VOD y Reproducción P2P (Smart TV)

> **Estado**: En Revisión / Aprobado  
> **Área**: VOD / Películas / Streaming P2P / D-Pad UX  
> **Versión de destino**: v3.1.0  

---

## 1. Propósito y Alcance

Este documento especifica la integración del módulo de **Películas y Video on Demand (VOD)** en MoAI 3, permitiendo explorar un catálogo visual optimizado para Smart TV, obtener fuentes de transmisión en español latino de forma automatizada y reproducir el contenido mediante streaming secuencial P2P (Torrent).

### Fuera de Alcance (Non-Goals)
- Descarga offline permanente a memoria de almacenamiento secundario.
- Transcodificación de video en tiempo real en la Smart TV (se utiliza reproducción directa vía ExoPlayer / MediaKit).
- Sistema de usuarios/perfiles de películas ajenos al ecosistema de presencia de MoAI.

---

## 2. Definición de Tipos y Contratos de Datos

### 2.1 Modelo `Movie`
```dart
class Movie {
  final String id;             // TMDB ID o Cinemeta ID
  final String title;          // Título en español
  final String overview;       // Sinopsis
  final String? posterPath;    // URL portada de póster
  final String? backdropPath;  // URL de imagen de fondo / banner
  final String? releaseDate;   // Fecha o año de estreno
  final double voteAverage;    // Calificación (0.0 - 10.0)
  final String? imdbId;        // IMDb ID (ej: tt1234567) para Torrentio

  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage = 0.0,
    this.imdbId,
  });
}
```

### 2.2 Modelo `TorrentStream`
```dart
class TorrentStream {
  final String name;          // Nombre del archivo / título del torrent
  final String title;         // Información de formato, resolución, audio y seeders
  final String infoHash;      // Hash único del torrent
  final String magnetUrl;     // Enlace Magnet para la descarga secuencial
  final int seeders;          // Cantidad de pares de semillas disponibles
  final int score;            // Puntuación calculada por el algoritmo Latino/Calidad

  const TorrentStream({
    required this.name,
    required this.title,
    required this.infoHash,
    required this.magnetUrl,
    required this.seeders,
    required this.score,
  });
}
```

---

## 3. Comportamiento y Reglas de Negocio

### 3.1 Catálogo de Películas: TMDB con Fallback Automático a Cinemeta
1. **Fuente Primaria (TMDB API)**:
   - Endpoint: `https://api.themoviedb.org/3/movie/popular?language=es-MX&page=1`
   - Si la petición es exitosa y contiene `imdb_id` (vía `/movie/{id}/external_ids`), se utiliza este conjunto de metadatos.
2. **Fuente Secundaria (Fallback Cinemeta)**:
   - Si TMDB falla (timeout, sin red, error HTTP 401 por falta de API Key):
   - Endpoint público: `https://v3-cinemeta.strem.io/catalog/movie/top.json`
   - Devuelve automáticamente `poster`, `name`, `description` e `imdb_id`.

### 3.2 Indexación de Torrents y Algoritmo de Scoring Audio Latino
- Consulta a Torrentio API: `https://torrentio.strem.fun/stream/movie/{imdb_id}.json`
- **Fórmula de Scoring**:
  - `+10,000` ptos: Si el título contiene la etiqueta de audio latino (`latino`, `lat`, `dual`, `multi`).
  - `+5,000` ptos: Si contiene idioma español castellano (`castellano`, `español`).
  - `+500` ptos: Calidad 1080p / Full HD.
  - `+100` ptos: Calidad 720p / HD.
  - `+50` ptos: Calidad 4K / 2160p (prioridad moderada para prevenir saturación de buffer en Smart TVs).
  - `+ (seeders * 10)` ptos: Ponderación por semillas activas.

### 3.3 Motor de Streaming Secuencial P2P
- La película se reproduce vía `moaiServer` (o servidor local P2P) enviando el enlace Magnet.
- El servidor responde en modo streaming continuo HTTP con soporte para cabecera `Range: bytes` (`206 Partial Content`), permitiendo adelantar/rebobinar (*seeking*) sin esperar la descarga completa.

---

## 4. Experiencia de Usuario y Navegación D-Pad en TV

1. **Integración con Menu Principal (`NavigationRail`)**:
   - Se habilita la pestaña `Películas` (índice `1` en `NavigationRail`).
2. **Navegación por Grilla / Filas Horizontal (`MoviesPanel`)**:
   - Foco direccional suave con D-Pad de control remoto TV.
   - Presionar `Izquierda` desde la primera columna de películas devuelve el foco al menú lateral.
   - Presionar `OK / Select` sobre una tarjeta abre la vista de detalle / reproductor.
   - Presionar `Atrás (Back)` dentro del reproductor detiene el streaming P2P y libera la memoria temporal.

---

## 5. Criterios de Aceptación (Gherkin)

```gherkin
Escenario: Obtención de catálogo con fallback automático
  Dado que el servicio de metadatos está inicializado
  Cuando la API de TMDB no está disponible o falla la autenticación
  Entonces el sistema consulta automáticamente la API de Cinemeta Stremio
  Y muestra el listado de películas populares con IMDb ID disponible

Escenario: Selección automática de la mejor fuente con audio latino
  Dado una película seleccionada con IMDb ID "tt1234567"
  Cuando Torrentio devuelve múltiples fuentes de video
  Entonces la fuente seleccionada automáticamente es aquella que posee audio latino ("latino" / "dual") y el mayor puntaje combinado de calidad y semillas

Escenario: Control de foco D-Pad en la grilla de películas
  Dado que el usuario navega en la grilla de películas
  Cuando presiona la tecla IZQUIERDA del control remoto estando en el primer elemento de la fila
  Entonces el foco regresa de forma fluida a la barra de navegación lateral (NavigationRail)
```
