# Línea base de rendimiento (SPEC-50 §0.1)

> **Dispositivo**: Chromecast con Google TV HD (`sabrina`, Android 14, 1920×1080)
> **Build**: `flutter build apk --profile`, rama `performance` @ `d46b6d1` (2026-10-23)
> **Estado**: instalación con el plugin Moai Argentina v1.7.2 (501 canales); catálogo de películas ya descargado (frecuencia semanal, no se sincroniza).

## M1 / M2 — Arranque en frío

Tres corridas (`am force-stop` + `am start -W`):

| Corrida | `Displayed` (primer cuadro de la app) | Video reproduciendo (desde `Displayed`) |
| :--- | :--- | :--- |
| 1 | 4,69 s | +5,80 s |
| 2 | 4,18 s | +5,36 s |
| 3 | 4,05 s | +5,18 s |

Desglose de una corrida (marcas de logcat):

| Tramo | Duración |
| :--- | :--- |
| Inicio de proceso → VM de Dart lista | 1,32 s |
| `main()` hasta la primera pantalla (dotenv, Supabase, preferencias, identidad) | ~1,9 s |
| Pantalla de carga → decisión de catálogo | 0,93 s |
| Carga del plugin `.dex` (`IPlugin cargado`) | +1,6 s |
| `create` del reproductor → primer cuadro de video | 2,52 s (red del stream DASH + ClearKey) |
| **Total hasta video** | **~9,1 s** |

Candidatos a optimizar con esta base: el tramo de `main()` antes de `runApp` (Supabase e identidad se esperan en serie) y la carga del `.dex`, que podría empezar antes o en paralelo con la pantalla de carga.

> Las mediciones con el build de debug no sirven como referencia: `Displayed` tarda 14-16 s por el JIT.

## Pendientes de medir

- M3 frames > 16 ms navegando la grilla (requiere DevTools conectado al build de profile).
- M4 TV → Ajustes → TV.
- M5 rebuilds por minuto con video.
- M6 memoria tras cargar canales.
- M7 tamaño del APK release: profile = 101,8 MB (incluye las tres ABIs).
