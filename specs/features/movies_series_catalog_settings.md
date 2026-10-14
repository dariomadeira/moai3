# SPEC-39: Catálogo Películas/Series (Moiamov) y Ajustes de Actualización

> **Estado**: Aprobado (rama `xumovies`, v3.0.36+)  
> **Área**: Features / Catálogo VOD + Arranque  
> **Archivos de Referencia**:  
> - `lib/features/settings/widgets/settings_movies_series_panel.dart`  
> - `lib/features/settings/widgets/settings_catalog_frequency_row.dart`  
> - `lib/features/settings/widgets/tv_option_selector.dart`  
> - `lib/layout/settings_panel_layout.dart`  
> - `lib/state/tv_settings_provider.dart`  
> - `lib/features/loading/screens/loading_screen.dart`  
> - `lib/services/moiamov_api_service.dart`  
> - `lib/services/vpn_service.dart`  

---

## 1. Propósito y Alcance

Formalizar:

1. Panel de ajustes **Películas y series** (índice 1 del acordeón de 6 paneles).  
2. Preferencias `skipCatalogUpdate` y `catalogUpdateFrequency`.  
3. Flujo de arranque en `LoadingScreen`: VPN México → sesión Moiamov → sync / cancel / fallback.  

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

Las filas de skip/frecuencia de catálogo **no** viven en Generales; solo en el panel 1.

---

## 3. Preferencias

| Clave prefs | Tipo | Default | API provider |
| :--- | :--- | :--- | :--- |
| `skip_catalog_update` | `bool` | `true` | `TvSettingsProvider.skipCatalogUpdate` |
| `catalog_update_frequency` | `String` enum | `weekly` | `TvSettingsProvider.catalogUpdateFrequency` |

### `CatalogUpdateFrequency`
- `always` — intentar sync en cada arranque (si no hay skip).  
- `weekly` — default.  
- `monthly`.  

**Regla:** Si `skipCatalogUpdate == true`, no se abre el flujo VPN/sync aunque la frecuencia diga `always`.  
Si skip es `false`, la UI muestra el selector de frecuencia (`TvOptionSelector` + `SettingsCatalogFrequencyRow`).

---

## 4. Flujo de arranque (LoadingScreen)

```text
Presencia OK
    │
    ├─ skip || frecuencia no vencida → loadFallback / saved / bundled
    │
    └─ sync requerido
           │
           ├─ ensureAndroidVpnPermission (una vez por sesión app)
           ├─ connectMexico (rotar nodos)
           ├─ ensureSession (Moiamov guest)
           ├─ syncCatalog (movies / featured / series)  ← cancelable
           └─ disconnect VPN
    │
    └─ → /overlap | /nickname_setup | /home
```

### Cancelación
- Flag `_catalogCancelRequested` + **`_catalogRunId`** para invalidar awaits en vuelo.  
- Al cancelar: `cancelActiveRequests`, `cancelConnect`, `disconnect`, cargar catálogo guardado, continuar navegación.  
- Completados stale **no** deben `setState` ni sobrescribir UI.

### VPN
- Permiso Android se pide **una sola vez** por ciclo de arranque (`ensureAndroidVpnPermission`), no en cada nodo.  
- Credenciales túnel: `TUNNEL_USER` / `TUNNEL_PASS` vía dotenv (SPEC no incluye valores).

---

## 5. Componentes UI

- `SettingsMoviesSeriesPanel`: switch skip + fila frecuencia condicional.  
- `TvOptionSelector<T>`: chips D-pad para enums (frecuencia, y reutilizado en agenda notify/duration donde aplique).  
- Textos: claves `settings_movies_series_*` y `settings_general_catalog_freq_*` en `es.json`.

---

## 6. Criterios de aceptación

```gherkin
Given skipCatalogUpdate = true
When la app arranca
Then no se inicia VPN ni sync Moiamov
And se carga catálogo de respaldo o guardado

Given skipCatalogUpdate = false and frequency = weekly
And el último sync fue hace menos de 7 días
When la app arranca
Then se omite el sync en vivo

Given sync en curso
When el usuario cancela
Then se invalida el runId
And se desconecta VPN
And se navega a home/overlap sin pantalla colgada

Given el acordeón de ajustes
When el usuario abre el índice 1
Then ve el panel Películas y series con skip y frecuencia
And Generales no muestra esas filas
```
