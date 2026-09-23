# SPEC-21: Preferencias del Sistema, Temas y Seguridad Parental

> **Estado**: Congelado (Baseline v3.0.11)  
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

---

## 2. Ajustes Físicos de Pantalla para Android TV

1. **Compensación de Overscan (Calibración de Bordes)**:
   - Permite ajustar los márgenes de seguridad para televisores antiguos que recortan los bordes de la señal HDMI.
   - Claves de persistencia: `'overlap_padding_x'`, `'overlap_padding_y'`, `'has_overlap_config'`.
   - Valor predeterminado: `20.0` px en ambos ejes.
2. **Superposición de Registros en Pantalla (Debug Log TV)**:
   - Permite visualizar sobre la interfaz una consola flotante con los eventos de reproducción y ciclo de vida de plugins.
   - Clave de persistencia: `'show_tv_log'`.

---

## 3. Motor de Temas y Color Dinámico (M3 Expressive)

1. **Modo Oscuro / Claro**:
   - Clave: `'dark_mode'`. Predeterminado en `true` (Dark Mode TV).
2. **Color de Semilla (Accent Seed)**:
   - Selección de paleta M3 a partir de un índice predefinido de semillas tonales (`MoaiAccentColors`).
   - Clave: `'accent_color_index'`.
3. **Color de Acento Aleatorio al Inicio (`autoAccent`)**:
   - Clave: `'auto_accent_color'`.
   - Si está activo (`true`), en cada inicio de la aplicación se selecciona de manera pseudoaleatoria un color de semilla distinto entre los disponibles, brindando frescura visual a la interfaz.
