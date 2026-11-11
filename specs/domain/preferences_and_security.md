# SPEC-21: Preferencias del Sistema, Temas y Seguridad Parental

> **Estado**: Vigente (ampliado en `xumovies`)  
> **Área**: Dominio / Preferencias y Seguridad  
> **Archivos de Referencia**: `lib/state/tv_settings_provider.dart`, `lib/state/theme_provider.dart`, `lib/state/channel_provider.dart`

---

## 1. Sistema de Control Parental y Seguridad

MoAI 3 implementa un mecanismo de protección para canales y contenidos catalogados como adultos (`Channel.isAdult`).

### 1.1. Almacenamiento y Configuración del PIN
- Clave de persistencia: `'parental_pin'` (mediante `AppPreferences`).
- Formato: Cadena de dígitos numéricos (habitualmente 4 dígitos numéricos en TV).
- `hasParentalPin`: Retorna `true` si el PIN configurado no es nulo ni vacío.
- `verifyPin(input)`: Compara estrictamente `input.trim() == _parentalPin`.

### 1.2. Ciclo de Vida del Desbloqueo por Sesión (Session-Based Unlock)
1. **Bloqueo Inicial**: En cada arranque o reinicio en frío de la aplicación, el estado `_isAdultUnlocked` se inicializa estrictamente en `false`. El desbloqueo **NUNCA** se persiste entre sesiones de la app.
2. **Desbloqueo de Sesión**: Cuando el usuario introduce el PIN correcto en el diálogo TV, se invoca `unlockAdultForSession()`, cambiando `_isAdultUnlocked = true` y notificando a `ChannelProvider`.
3. **Bloqueo Manual**: Se puede invocar `lockAdult()` para volver a restringir los contenidos de inmediato sin necesidad de cerrar la app.
4. **Política de Canal Seleccionado al Iniciar**:
   Si el último canal seleccionado guardado en preferencias es un canal de contenido adulto (`isAdult == true`) y la sesión inicia bloqueada (`isAdultUnlocked == false`), `ChannelProvider` descarta dicha selección y recurre al método de búsqueda segura `_findSafeFallbackChannel()`, seleccionando el último canal no adulto o el primer canal seguro del catálogo.

### 1.3. Diálogo de PIN para Smart TV (`TvPinDialog`)
- **Máquina de Estados Interna**: Las secuencias de creación (2 pasos) y cambio de PIN (3 pasos) operan dentro de una única sesión modal continua mediante `AnimatedSwitcher`. Se eliminan los parpadeos (*pantallazos*) ocasionados por cierres y reaperturas sucesivas de `showGeneralDialog`.
- **Animación de Error (Shake)**: Ante discrepancias o PIN incorrecto, los casilleros ejecutan una sacudida horizontal de 5 oscilaciones (`_PinShakeCurve`) sin cerrar el diálogo.
- **Matriz Numérica 4x3 y Colores Sólidos**: Teclado determinista para control remoto D-Pad y teclado numérico físico, con diseño sin bordes y badge de paso con tokens sólidos `tertiaryContainer` y `onTertiaryContainer`. *(Ver detalle en [SPEC-33](../features/tv_ui_components_and_layout.md))*.

---

## 2. Ajustes Físicos de Pantalla para Android TV

1. **Compensación de Overscan (Calibración de Bordes)**:
   - Permite ajustar los márgenes de seguridad para televisores antiguos que recortan los bordes de la señal HDMI.
   - Claves de persistencia: `'overlap_padding_x'`, `'overlap_padding_y'`, `'has_overlap_config'`.
   - Valor predeterminado: `20.0` px en ambos ejes.
2. **Superposición de Registros en Pantalla (Debug Log TV)**:
   - Permite visualizar sobre la interfaz una consola flotante con los eventos de reproducción y ciclo de vida de plugins.
   - Clave de persistencia: `'show_tv_log'`.
3. **Sonidos UI D-Pad**:
   - Clave: `'ui_sounds_disabled'`. Si `true`, el host nativo no reproduce clicks de navegación (SPEC-41).
4. **Catálogo Películas/Series (Moiamov)**:
   - `'skip_catalog_update_v2'` (bool, default `false`): si `true`, omite VPN/sync y usa solo assets.
   - UI del switch es **positiva** («Actualizar catálogo al arrancar»: ON ⇒ `skip=false`).
   - `'catalog_update_frequency'`: `always` (**default**) | `weekly` | `monthly`.
   - La clave legacy `'skip_catalog_update'` no se lee.
   - UI y flujo: [SPEC-39](../features/movies_series_catalog_settings.md).

---

## 3. Motor de Temas y Color Dinámico (M3 Expressive)

1. **Modo Oscuro / Claro** (rediseño de cristal, 2026-11-10/11):
   - Clave: `'dark_mode_v2'`. Predeterminado en `false`: la app arranca en **claro**. La clave vieja `'dark_mode'` (que valía `true`) ya no se lee.
   - Interruptor en **Ajustes › Generales**, visible también en release.
   - Tema: `lib/theme/moai_theme.dart` (`MoaiTheme.light/dark`); los colores que cambian por modo están en `lib/theme/moai_palette.dart` (`MoaiPalette`, `ThemeExtension`; incluye `watched`, el verde de lo visto en series). Estilo oscuro: vidrio ahumado sobre fondo oscuro con color (`assets/images/background_dark.webp`). En oscuro el acento se aclara 20 %.
   - Guardas: capturas de referencia de los dos modos (`test/goldens/theme_golden_test.dart`) y el test de colores fijos (`test/hardcoded_colors_test.dart`).
2. **Color de Semilla (Accent Seed)**:
   - Selección de paleta M3 a partir de un índice predefinido de semillas tonales (`MoaiAccentColors`).
   - Clave: `'accent_color_index'`.
3. **Color de Acento Aleatorio al Inicio (`autoAccent`)**:
   - Clave: `'auto_accent_color'`.
   - Si está activo (`true`), en cada inicio de la aplicación se selecciona de manera pseudoaleatoria un color de semilla distinto entre los disponibles, brindando frescura visual a la interfaz.
