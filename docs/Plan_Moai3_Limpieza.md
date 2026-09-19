# Auditoría y limpieza de moai3 — Fase 1

> Complementa `Plan_Implementacion_Moai3_Motor_Plugins.md` (Fase 1).
> Resultado de la limpieza inicial. No se tocó el reproductor (esa es la
> Fase 2, motor Kotlin propio).

## Método

Análisis estático del grafo de dependencias de `lib/`, partiendo de
`main.dart`, resolviendo imports y exports `package:moai3/…`, relativos y
BOM. Los archivos no alcanzables desde `main.dart` son candidatos muertos.

## Resultado de la auditoría

- Lib total: 99 archivos → **1 archivo muerto** (no alcanzable ni por
  import ni por export, y no referenciado por los tests).
- Dependencias sin uso en `pubspec.yaml` → 2.
- Assets vacíos/sin referencias → 1 carpeta.

## Lo eliminado

| Elemento | Motivo |
|---|---|
| `lib/focus/tv_locked_focus_traversal.dart` | Sin referencias inbound (ni import ni export) y sin uso en tests |
| `cupertino_icons` (pubspec) | Nunca se importa (`CupertinoIcons` no se usa) |
| `http` (pubspec) | Nunca se importa (la lógica de red vendrá del motor/plugins en Fases 2–3) |
| `assets/animations/` + entrada en pubspec | Carpeta vacía, ningún `JsonAsset`/Lottie la referenciaba |

## Lo que se conservó (a propósito)

- `video_player` / `wakelock_plus`: en uso hoy (`TvViewer`); se **reemplazan**
  en la Fase 2 por el motor Kotlin propio. No se tocan en esta fase para no
  romper reproducción a mitad de camino.
- `cached_network_image`, `google_fonts`, `flutter_svg`, `package_info_plus`,
  `material_symbols_icons`, `dynamic_color`, `easy_localization`,
  `shared_preferences`, `provider`, `flutter_dotenv`: todos con imports.
- Todo el árbol `widgets/tv_input/` (on-screen keyboard, text field): está
  vivo vía *exports* de `tv_input.dart` (aunque hoy no se navegue a él,
  forma parte del API del host).
- `features/channel_browser/`, `features/home/…`, `services/`, `state/`:
  alcanzables desde `main.dart`.

## Verificación post-limpieza

- `flutter analyze` → **0 issues**.
- `flutter test` → **46/46 OK**.
- `flutter build apk --debug` → OK.
- Cambios de dependencias tras `flutter pub get`: 2 (las removidas).

## Notas

- El grafo se vuelve a auditar en cada fase; la Fase 2 (motor Kotlin)
  eliminará `video_player`/`wakelock_plus` y el código Dart del reproductor
  (TvViewer + overlay + stats legacy), que quedan HOY porque todavía se usan.
- La Fase 3 (host de plugins) agregará la capa nueva con sus propios
  archivos; la limpieza de "muertos" seguirá siendo automática con el mismo
  método.