# SPEC-39: Catálogo Películas/Series (Moiamov) y Ajustes de Actualización

> **Estado**: Vigente (rama `performance`)  
> **Área**: Features / Catálogo VOD + Arranque  
> **Archivos de Referencia**:  
> - `lib/features/settings/widgets/settings_movies_series_panel.dart`  
> - `lib/features/settings/widgets/settings_catalog_frequency_row.dart`  
> - `lib/features/settings/widgets/tv_option_selector.dart`  
> - `lib/focus/settings_panel_layout.dart`  
> - `lib/state/tv_settings_provider.dart`  
> - `lib/state/featured_movies_provider.dart`  
> - `lib/features/home/widgets/tv_vertical_nav_rail.dart`  
> - `lib/features/loading/screens/loading_screen.dart`  
> - `lib/services/moiamov_api_service.dart`  
> - `lib/services/vpn_service.dart`  
> - `android/app/src/main/kotlin/com/infomak/moai/MainActivity.kt` (permiso VPN)  
> - `android/app/build.gradle.kts` (`jniLibs.useLegacyPackaging`)  
> - `assets/vpn/mexico_0{1..4}.ovpn`  

---

## 1. Propósito y Alcance

Formalizar:

1. Panel de ajustes **Películas y series** (índice 1 del acordeón de 6 paneles).  
2. Preferencia `catalogUpdateFrequency` y la fecha del catálogo.  
3. Flujo de arranque en `LoadingScreen`: VPN México + login en todo arranque → descarga del catálogo si toca.  
4. Visibilidad de Destacados, Películas y Series en el rail.  
5. Reglas de permiso VPN Android.  

### Non-Goals
- Sustituir el motor de plugins de TV en vivo.  
- Documentar credenciales Moiamov/VPN (solo `.env`).  
- Elegir el mejor nodo VPN según la ubicación (pendiente).

---

## 2. Layout de paneles de Ajustes

`SettingsPanelLayout.panelCount = 6`:

| Índice | Panel |
| :---: | :--- |
| 0 | Configuración TV |
| 1 | **Películas y series** |
| 2 | Agenda |
| 3 | Miremos Juntos |
| 4 | Generales |
| 5 | Acerca de |

El panel 1 tiene una sola fila: **Frecuencia de actualización** (con la fecha del catálogo en el título).

---

## 3. Preferencias y datos guardados

| Clave | Tipo | Default | API |
| :--- | :--- | :--- | :--- |
| `catalog_update_frequency` | `String` enum | `weekly` | `TvSettingsProvider.catalogUpdateFrequency` |
| `moiamov_catalog_date` | ISO-8601 | — | `MoiamovApiService.lastSavedCatalogAt` / `saveCatalogDate` |
| `moiamov_user_id`, `moiamov_user_token`, `moiamov_portal_code`, `moiamov_user_identity`, `moiamov_device_mac`, `moiamov_sn_field`, `moiamov_b29` | `String` | — | se guardan en cada login (`_applyActiveResult`) |

> `skip_catalog_update_v2` («Actualizar catálogo al arrancar») **ya no existe**: solo queda la frecuencia.

### `CatalogUpdateFrequency`
| Valor | Descarga del catálogo al arrancar |
| :--- | :--- |
| `always` | En cada arranque. |
| `weekly` | Si la fecha del catálogo es `null` o tiene ≥ 7 días. |
| `monthly` | Si la fecha del catálogo es `null` o tiene ≥ 30 días. |

Sin catálogo guardado de ninguna sección, la descarga es obligatoria.

### Fecha del catálogo
- Una sola fecha para las 3 secciones, guardada explícitamente.  
- Se actualiza **solo cuando bajan las 3 secciones**. Si la descarga es parcial, se guardan las secciones que bajaron pero la fecha no cambia, así el próximo arranque vuelve a intentar.

---

## 4. Flujo de arranque (LoadingScreen)

```text
Verificación del dispositivo en Supabase
    │   falla / timeout → pantalla de error con "Reintentar"
    │   bloqueado      → /blocked
    │
    ├─ actualizar = sin catálogo || frecuencia vencida
    │
    ├─ Hasta 3 intentos, uno por nodo (mexico_01..03):
    │     1. connectMexico (permiso del SO sin límite de tiempo)
    │        · permiso rechazado → cortar intentos
    │        · salida no MX o túnel caído → siguiente nodo
    │     2. ensureSession (v3/snToken → v8/active); guarda datos de sesión
    │        · rechazado → siguiente nodo
    │     3. si no hay que actualizar → listo
    │     4. bajar secciones faltantes: Películas, luego Destacados + Series
    │        · botón "OK: usar el catálogo del <fecha>" (solo si ya hay catálogo)
    │        · faltan secciones → siguiente nodo (nuevo login)
    │
    ├─ disconnect VPN
    ├─ 3 secciones bajadas → guardar fecha del catálogo
    ├─ secciones visibles = login OK ? secciones guardadas en disco : ninguna
    │
    └─ → /overlap | /nickname_setup | /home
```

### Reglas
- **Login en todo arranque**, aunque no toque actualizar el catálogo.  
- **Sin respaldos**: no hay catálogo empaquetado en assets ni se lee el caché de la app oficial. Si una sección nunca bajó, no existe.  
- **Rail**: Destacados, Películas y Series se muestran solo si el login de este arranque salió bien **y** hay catálogo guardado de esa sección (`FeaturedMoviesProvider.setAvailableSections`). Si no, se ocultan y la app entra igual al home (TV). Las fallas de VPN, login o catálogo nunca muestran pantalla de error.  
- **Falla de descarga con login OK**: se sigue con el catálogo viejo; estado «No se actualizó el catálogo».  
- **Sin login**: estado «Películas y series no disponibles».

### Cancelación
- El botón aparece solo durante la descarga y solo si ya hay catálogo guardado (nunca en el primer arranque).  
- Corta solo la descarga (`cancelActiveRequests`); el login ya terminó y no se puede cortar.  
- Se sigue con el catálogo guardado.

### VPN (OpenVPN México)
- Dependencia: `openvpn_flutter` rama git `android_16kb` (ELF 16 KB).  
- Empaquetado: `android.packaging.jniLibs.useLegacyPackaging = true` (AGP; no poner `extractNativeLibs` en el manifest).  
- Perfiles: `assets/vpn/mexico_01.ovpn` … `mexico_04.ovpn`.  
- Usuario OpenVPN: se fuerza sufijo Proton **`+b:0`** (`VpnService._ensureMexicoExitUsername`) para salida México; sin eso `verifyConnection` falla.  
- Credenciales: `TUNNEL_USER` / `TUNNEL_PASS` (dotenv), con fallback al bloque inline del `.ovpn`.  
- `data-ciphers` se inyecta si falta (compat android_16kb).  
- `disconnect()` espera 600 ms después de `disconnected`: el proceso de OpenVPN tarda ~150 ms en cerrarse y un `connect` anterior se pierde sin emitir etapas.

#### Permiso Android (crítico)
1. **No** usar `requestPermissionAndroid()` como gate: el plugin, al mostrar el diálogo, responde `false` al instante (no espera al usuario).  
2. Antes de conectar, Flutter pregunta `isGranted` por `com.infomak.moai.tv/vpn_permission` (`VpnService.prepare(this) == null`).  
3. El permiso se obtiene en `OpenVPN.connect`: guarda config estática → `VpnService.prepare` → diálogo SO.  
4. `MainActivity.onActivityResult(24)`:  
   - OK → `connectWhileGranted(true)` **solo si** la config estática del plugin no está vacía.  
   - Deny → `invokeMethod('denied')`; Flutter marca el permiso como rechazado para este arranque.  
5. Esperas: **sin límite** mientras el diálogo del SO espera al usuario; con el permiso ya concedido, **14 s** para que el túnel arranque y **14 s** de handshake.

### Persistencia de catálogo
- Directorio app: `…/catalog/{masnew_movies,masnew_featured,masnew_series}.json`.  
- Solo se escribe con descargas en vivo.

---

## 5. Componentes UI

- `SettingsMoviesSeriesPanel`: fila de frecuencia con la fecha del catálogo.  
- `TvOptionSelector<T>`: chips D-pad (frecuencia; reutilizado en agenda).  
- Textos: `settings_general_catalog_freq*`, `loading_catalog_*`, `loading_session_failed` en `es.json`.  
- Loading: botón con `loading_catalog_cancel` / `loading_catalog_cancel_no_date`.

---

## 6. Criterios de aceptación

```gherkin
Given primer arranque sin catálogo guardado
When la app arranca
Then pide el permiso VPN y espera al usuario sin límite
And hace login y baja las 3 secciones con hasta 3 nodos
And no muestra el botón de cancelar

Given primer arranque y fallan los 3 intentos
When la app arranca
Then entra al home en TV sin Destacados, Películas ni Series en el rail

Given hay catálogo y frequency = weekly con fecha de hace menos de 7 días
When la app arranca
Then hace VPN + login igual
And no descarga el catálogo
And el rail muestra las secciones guardadas

Given hay catálogo y toca actualizar
When baja solo Películas
Then se guarda Películas, la fecha no cambia y se ven las 3 secciones (las otras con la versión vieja)

Given hay catálogo y el login falla en los 3 nodos
When la app arranca
Then el rail oculta Destacados, Películas y Series

Given el usuario rechaza el permiso VPN
When la app arranca
Then no se reintenta con otros nodos
And entra al home sin las 3 secciones

Given descarga en curso con catálogo guardado
When el usuario toca "OK: usar el catálogo del <fecha>"
Then se corta la descarga, se desconecta la VPN y se sigue con el catálogo guardado
```
