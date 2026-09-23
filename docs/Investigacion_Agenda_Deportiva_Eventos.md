# Investigación: Agenda de Eventos Deportivos en Moai TV

Documento técnico de investigación sobre la obtención y sincronización de eventos deportivos en vivo (fútbol argentino, competencias internacionales, Fórmula 1 y motorsport) para Moai TV.

---

## 1. Objetivo y Alcance

Investigar fuentes de datos y APIs en tiempo real para dotar a **Moai TV** de una agenda de eventos deportivos, enfocada principalmente en:
1. **Fútbol Argentino e Internacional**: Partidos de la Liga Profesional de Fútbol (LPF), copas nacionales, torneos CONMEBOL y ligas europeas, con horarios en hora de Argentina (GMT-3) y canal de transmisión asociado.
2. **Fórmula 1 y Motorsport**: Prácticas libres, clasificaciones, carreras y categorías complementarias (MotoGP, IndyCar, etc.).
3. **Reproducción directa o sintonización inteligente**: Capacidad de abrir el stream en vivo (vía enlaces temporales de DaddyLive) o saltar al canal de TV local correspondiente (TNT Sports, ESPN Premium, TyC Sports, etc.).

---

## 2. Fuente 1: DaddyLive Live Events API

DaddyLive cuenta con un endpoint oficial en formato JSON en tiempo real con más de 300 eventos diarios catalogados.

### Especificaciones de la API
- **Endpoint principal**: `GET https://daddylive.li/api/events`
- **Mirrors de respaldo**: `daddylive.app/api/events`, `daddylive.mov/api/events`
- **Headers requeridos**: `User-Agent` de navegador estándar (Chrome/Firefox).
- **Formato**: `application/json; charset=utf-8`

### Estructura del JSON
```json
{
  "total_events": 318,
  "popular_events": [ ... ],
  "categories": {
    "Torneo LPF": [
      {
        "event": "San Lorenzo - Boca Juniors",
        "time": "17:45",
        "channels": [
          { "channel_name": "Link - 1", "url": "https://daddylive.li/player/embed.php?id=7160e&source=tv6" },
          { "channel_name": "Link - 2", "url": "https://daddylive.li/player/embed.php?id=c16ec&source=tv6" }
        ]
      }
    ],
    "Liga Argentina": [ ... ],
    "Motorsport 🏎️🏁": [
      {
        "event": "🏁 Formula 1: Singapore Grand Prix - Race",
        "time": "09:00",
        "channels": [
          { "channel_name": "Link - 1", "url": "https://daddylive.li/player/embed.php?id=53" },
          { "channel_name": "Link - 2", "url": "https://daddylive.li/player/embed.php?id=769" }
        ]
      }
    ],
    "All Soccer Events ⚽": [ ... ],
    "Tennis 🎾": [ ... ],
    "Live Events": [ ... ]
  }
}
```

### Ventajas y Consideraciones Técnicas
- **Ventaja**: Vincula el evento deportivo directamente con una señal de video en vivo (`channels`), resolviendo la transmisión sin depender de qué canal la emite.
- **Canales 24/7 vs Eventos Temporales**:
  - Si el ID es numérico (ej: `id=53`), apunta directamente a un canal 24/7 del catálogo de DaddyLive.
  - Si el ID es alfanumérico con fuente (ej: `id=7160e&source=tv6`), apunta a servidores de streaming dinámicos (`bolaloca.my`, etc.) que utilizan el mismo patrón de iframes (`PLAYERS = [...]`) y requieren ser soportados por el resolver del plugin.

---

## 3. Fuente 2: Agenda Local de TV Argentina (Promiedos)

Para una experiencia 100% orientada al televidente argentino que busca saber **"qué canal lo pasa"**:

### Especificaciones
- **Origen**: `https://www.promiedos.com.ar/`
- **Mecanismo**: La portada embebe datos estructurados en formato JSON con la programación completa del día.
- **Datos expuestos por partido**:
  - Horario local argentino: `"start_time": "20-09-2026 14:45"`
  - Equipos: `"teams": [{"name": "San Lorenzo"}, {"name": "Boca Juniors"}]`
  - Estado del partido: `"game_time_status_to_display": "En vivo" / "Finalizado" / "Previa"`
  - **Canales de televisión asignados**:
    ```json
    "tv_networks": [
      { "name": "TNT Sports Premium" },
      { "name": "ESPN Premium" }
    ]
    ```

### Integración Inteligente en Moai TV
Como Moai TV ya posee los canales de televisión locales en su catálogo (gracias al plugin de Argentina y DaddyLive), esta fuente permite una interacción fluida:
1. El usuario navega la **Agenda**.
2. Ve el partido: *Boca Juniors vs River Plate (17:00)* transmitido por *TNT Sports*.
3. Al presionar **OK**, Moai TV busca en su base de datos el canal `TNT Sports` y lo sintoniza de forma automática en el reproductor.

---

## 4. Fuente 3: Calendario Oficial de Fórmula 1 (API Abierta)

Para la cobertura precisa de Motorsport, existen APIs abiertas que ofrecen el cronograma completo de la temporada sin necesidad de scraping.

### Especificaciones de la API
- **Endpoint**: `GET https://api.jolpi.ca/ergast/f1/current.json`
- **Licencia / Acceso**: Pública, sin autenticación ni límites restrictivos.
- **Información provista**:
  - Lista completa de los 23–24 Grandes Premios de la temporada.
  - Fechas y horas en formato UTC de cada sesión:
    - **FP1, FP2, FP3** (Prácticas libres).
    - **Qualifying** (Clasificación).
    - **Sprint Shootout y Carrera Sprint** (en fines de semana Sprint).
    - **Carrera principal de domingo**.
  - Datos de circuito, país, nombre del Gran Premio y coordenadas.
- **Conversión de zona horaria**:
  - Las marcas de tiempo UTC se convierten automáticamente a la zona horaria del televisor / Argentina (`UTC - 3`).

---

## 5. Análisis de Arquitectura para una Futura Implementación

| Aspecto | Desafío Actual | Solución Recomendada para el Futuro |
|---|---|---|
| **Carga de Datos** | Peticiones HTTP repetidas pueden ralentizar la interfaz de TV. | Servicio singleton en Dart con caché en memoria de 5 a 10 minutos para la agenda de eventos. |
| **Navegación D-Pad** | Listas extensas de 300+ eventos saturan la navegación con control remoto. | Filtrado por pestañas horizontales compactas: *Fútbol Argentino*, *Fórmula 1*, *Otros Deportes*. |
| **Reproducción** | Enlaces temporales de eventos dinámicos pueden caducar o cambiar de player. | Extender el resolver del plugin para manejar parámetros de streams dinámicos o priorizar sintonización por canal de TV local si está disponible. |

---

*Documento generado el 2026-09-20 para análisis y referencia futura en Moai TV.*
