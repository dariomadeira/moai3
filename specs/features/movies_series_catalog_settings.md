# SPEC-39: Catálogo Películas/Series (Moiamov) y Ajustes de Actualización

> **Estado**: Vigente (rama `xumovies`, v3.0.36+)  
> **Área**: Features / Catálogo VOD + Arranque  
> **Archivos de Referencia**:  
> - `lib/features/settings/widgets/settings_movies_series_panel.dart`  
> - `lib/features/settings/widgets/settings_catalog_frequency_row.dart`  
> - `lib/features/settings/widgets/tv_option_selector.dart`  
> - `lib/focus/settings_panel_layout.dart`  
> - `lib/state/tv_settings_provider.dart`  
> - `lib/features/loading/screens/loading_screen.dart`  
> - `lib/services/moiamov_api_service.dart`  
> - `lib/services/vpn_service.dart`  
> - `android/app/src/main/kotlin/com/infomak/moai/MainActivity.kt` (`onActivityResult` VPN)  
> - `android/app/build.gradle.kts` (`jniLibs.useLegacyPackaging`)  
> - `assets/vpn/mexico_0{1..4}.ovpn`  

---

## 1. Propósito y Alcance

Formalizar:

1. Panel de ajustes **Películas y series** (índice 1 del acordeón de 6 paneles).  
2. Preferencias `skipCatalogUpdate` y `catalogUpdateFrequency`.  
3. Flujo de arranque en `LoadingScreen`: VPN México → sesión Moiamov → sync / cancel / fallback.  
4. Reglas de permiso VPN Android (sin crash al aceptar el aviso del SO).  

### Non-Goals
- Sustituir el motor de plugins de TV en vivo.  
- Documentar credenciales Moiamov/VPN (solo `.env`).  
- UI de browser de películas (fuera de este spec; consume el catálogo ya sync).

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

Las filas de actualización/frecuencia de catálogo **no** viven en Generales; solo en el panel 1.

---

## 3. Preferencias

| Clave prefs | Tipo | Default | API provider |
| :--- | :--- | :--- | :--- |
| `skip_catalog_update_v2` | `bool` | `false` | `TvSettingsProvider.skipCatalogUpdate` |
| `catalog_update_frequency` | `String` enum | `always` | `TvSettingsProvider.catalogUpdateFrequency` |

> La clave v1 `skip_catalog_update` (default histórico `true`) se ignora a propósito para no dejar instalaciones trabadas sin sync.

### Semántica UI vs prefs
- UI: switch positivo **«Actualizar catálogo al arrancar»**.  
  - ON → `skipCatalogUpdate = false` (sí sincronizar).  
  - OFF → `skipCatalogUpdate = true` (solo assets).  
- Con update **OFF**, la fila de frecuencia **no se muestra**.  
- Con update **ON**, se muestra `SettingsCatalogFrequencyRow` (chips Siempre / Semanal / Mensual).

### `CatalogUpdateFrequency`
| Valor | Comportamiento al arrancar (si update ON) |
| :--- | :--- |
| `always` | Intentar sync en cada arranque. |
| `weekly` | Sync solo si `lastSavedCatalogAt` es `null` o tiene ≥ 7 días. **Default.** |
| `monthly` | Sync solo si `lastSavedCatalogAt` es `null` o tiene ≥ 30 días. |

**Caso inicial:** sin archivo guardado (`savedAt == null`) → `shouldAttemptCatalogUpdate` es `true` aunque la frecuencia sea weekly/monthly (primera sincronización).

---

## 4. Flujo de arranque (LoadingScreen)

```text
Presencia OK (dispositivo activo)
    │
    ├─ skip (update OFF)
    │     → loadFallbackCatalog ×3 (solo assets/data/*.json)
    │
    ├─ update ON && frecuencia no vencida
    │     → loadSavedOrBundled ×3 (última descarga → si no hay, assets)
    │
    └─ update ON && sync requerido
           │
           ├─ beginCatalogSync + resetConnectCancellation
           ├─ Botón cancelar visible (fecha del último catálogo o sin fecha)
           ├─ connectMexico nodos 1..4
           │     · permiso SO dentro de connect (no requestPermissionAndroid aparte)
           │     · verifyConnection exige salida MX
           │     · ensureSession (guest Moiamov)
           ├─ syncCatalog movies + featured + series (cancelable)
           ├─ disconnect VPN
           │
           └─ si falla VPN/sesión/permiso denegado
                 → loadSavedOrBundled ×3
    │
    └─ → /overlap | /nickname_setup | /home
```

### Cancelación
- Flag `_catalogCancelRequested` + **`_catalogRunId`** para invalidar awaits en vuelo.  
- Al cancelar: `cancelActiveRequests`, `cancelConnect`, `disconnect`, `loadSavedOrBundled`, continuar navegación.  
- Completados stale **no** deben `setState` ni sobrescribir UI.

### VPN (OpenVPN México)
- Dependencia: `openvpn_flutter` rama git `android_16kb` (ELF 16 KB).  
- Empaquetado: `android.packaging.jniLibs.useLegacyPackaging = true` (AGP; no poner `extractNativeLibs` en el manifest).  
- Perfiles: `assets/vpn/mexico_01.ovpn` … `mexico_04.ovpn`.  
- Usuario OpenVPN: se fuerza sufijo Proton **`+b:0`** (`VpnService._ensureMexicoExitUsername`) para salida México; sin eso `verifyConnection` falla.  
- Credenciales: `TUNNEL_USER` / `TUNNEL_PASS` (dotenv), con fallback al bloque inline del `.ovpn`.  
- `certIsRequired: false` (perfiles con `setenv CLIENT_CERT 0`).  
- `data-ciphers` se inyecta si falta (compat android_16kb).  

#### Permiso Android (crítico)
1. **No** usar `requestPermissionAndroid()` como gate: el plugin, al mostrar el diálogo, responde `false` al instante (no espera al usuario).  
2. El permiso se obtiene en `OpenVPN.connect`: guarda config estática → `VpnService.prepare` → diálogo SO.  
3. `MainActivity.onActivityResult(24)`:  
   - OK → `connectWhileGranted(true)` **solo si** la config estática del plugin no está vacía (evita crash/`startVPN` nulo).  
   - Deny → `MethodChannel('com.infomak.moai.tv/vpn_permission').invokeMethod('denied')`; Flutter marca permiso denegado para la sesión y aborta nodos.  
4. Timeouts: hasta **120 s** esperando permiso/inicio; **14 s** de handshake tras el primer stage de conexión.  

### Persistencia de catálogo
- Directorio app: `…/catalog/{masnew_movies,masnew_featured,masnew_series}.json`.  
- `lastSavedCatalogAt()`: mtime más reciente de esos archivos.  
- Assets empaquetados: `assets/data/*.json` (respaldo hardcodeado).

---

## 5. Componentes UI

- `SettingsMoviesSeriesPanel`: switch positivo + fila frecuencia condicional.  
- `TvOptionSelector<T>`: chips D-pad (frecuencia; reutilizado en agenda).  
- Textos: `settings_general_skip_catalog*`, `settings_general_catalog_freq*` en `es.json`.  
- Loading: botón cancelar con `loading_catalog_cancel` / `loading_catalog_cancel_no_date`.

---

## 6. Criterios de aceptación

```gherkin
Given skipCatalogUpdate = true
When la app arranca
Then no se inicia VPN ni sync Moiamov
And se carga catálogo de assets
And el panel Películas no muestra la fila de frecuencia

Given skipCatalogUpdate = false and frequency = weekly
And el último sync fue hace menos de 7 días
When la app arranca
Then se omite el sync en vivo
And se carga la última descarga (o assets si no hay)

Given skipCatalogUpdate = false and no hay catálogo guardado
When la app arranca
Then se intenta sync aunque frequency sea weekly o monthly

Given sync requerido y el SO pide permiso VPN
When el usuario acepta el aviso
Then no se llama startVPN con config vacía
And connectMexico continúa el handshake

Given sync requerido y el usuario deniega el permiso VPN
When vuelve a la app
Then se usa loadSavedOrBundled y no se reabre el diálogo en cada nodo

Given sync en curso
When el usuario cancela
Then se invalida el runId
And se desconecta VPN
And se navega a home/overlap sin pantalla colgada

Given el acordeón de ajustes
When el usuario abre el índice 1 con update ON
Then ve el panel Películas y series con switch y frecuencia
And Generales no muestra esas filas
```
