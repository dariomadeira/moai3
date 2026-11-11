# SPEC-39: Catálogo Películas/Series (Moiamov) y Ajustes de Actualización

> **Estado**: Vigente (rama `cristal`)  
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
> - `lib/services/vpn_nodes.dart` (nodos y ranking)  
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
- Medir latencia para elegir nodo en el primer arranque (pendiente; hoy se usa el orden por defecto).

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

El panel 1 tiene estas filas (2026-11-11):

| Fila | Qué hace |
| :--- | :--- |
| Idioma del audio | Audio preferido de películas y series (SPEC-44 §2.2) |
| Subtítulos | Apagados o idioma |
| Tamaño de subtítulos | |
| Adelantos en el Inicio | Muestra u oculta la tarjeta (SPEC-42 §3.5) |
| **Frecuencia de actualización** | Con la fecha del catálogo en la descripción |
| **Borrar películas vistas** (escoba, `HugeIcons.clean`) | Confirma (Cancelar / Borrar, rojo) y borra lo visto y por dónde iba cada película; Marcadas no cambia (SPEC-44 §2.4) |
| **Borrar series vistas** (jabón, `HugeIcons.bodySoap`) | Confirma y borra capítulos vistos, puntos de retomar y "Seguir series"; Marcadas no cambia (SPEC-46 §8) |

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
    ├─ Hasta 4 intentos, cada uno con un endpoint (nodo + puerto) del ranking (§4.1)
    │     1. VpnService.connect(endpoint) (permiso del SO sin límite de tiempo)
    │        · permiso rechazado → cortar intentos
    │        · túnel caído → siguiente endpoint (los del mismo servidor, al final)
    │     2. ensureSession (v3/snToken → v8/active); guarda datos de sesión
    │        · la red no contesta → un reintento con el mismo endpoint
    │        · región rechazada (portal100024) → se descarta el servidor
    │        · otro rechazo → siguiente endpoint
    │     3. si no hay que actualizar → listo
    │     4. bajar secciones faltantes: Películas, luego Destacados + Series
    │        · botón "OK: usar el catálogo del <fecha>" (solo si ya hay catálogo)
    │        · faltan secciones → siguiente endpoint (nuevo login)
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

### 4.1 Ranking de endpoints

`kVpnNodes` (`vpn_nodes.dart`) lista los perfiles con su proveedor, país de salida, servidor (`host`) y puertos (`ports`, protocolo + puerto en orden de preferencia): `mx_01..04` (Proton, MX: UDP 1194/80/51820/4569/5060 y TCP 443/8443) y `jp_01..02` (VPN Gate, JP: TCP 443). El servicio de catálogo acepta ambas salidas.

Cada intento es un **endpoint** (`VpnEndpoint`: nodo + protocolo + puerto). `VpnService.configFor` arma la config con un solo `remote` y su `proto`, sin `remote-random` (en TCP saca `explicit-exit-notify`). Antes, con 5 `remote` UDP y `remote-random`, OpenVPN tomaba un puerto al azar y, si no contestaba, tardaba más que el límite del intento en pasar al siguiente: el mismo nodo andaba o no según el puerto.

`VpnNodeRanking` guarda por endpoint, en preferencias (`vpn_endpoint_ranking_v3`; el `v2` por nodo se borra), éxitos e intentos con olvido (vida media 14 días), el tiempo promedio hasta la sesión, el último uso, el último éxito y las fallas seguidas.

- **Tasa:** `(éxitos + 1) / (intentos + 2)`; sin historial, 0,5.
- **Orden:** primero el **último que anduvo**, salvo que lleve 2 fallas seguidas; después por tasa (diferencia < 0,05 → el más rápido). Sin historial, el orden de fábrica: una vuelta por servidor, cada servidor de un proveedor arrancando por otro puerto, y los japoneses intercalados.
- **Dentro del arranque:** tras una falla, los endpoints del mismo servidor pasan al final; si el portal rechazó la región, se descartan.
- **Sirvió (`success`):** túnel arriba y sesión obtenida. Si después falla el catálogo, no se le cuenta (es del servidor del portal).
- **Falló (`failure`):** el túnel no subió, o el portal rechazó la sesión.
- **Sin conclusión (`transient`):** la red no contestó al pedir la sesión (ni con el reintento). Solo actualiza la fecha.
- **No se anota:** si ningún túnel conectó (probablemente sin internet), si el usuario rechazó el permiso, o el endpoint cuya descarga cortó el botón "OK".
- **Salida:** `checkExit` (Cloudflare / ip-api) corre en paralelo con la sesión, solo para el log; ya no frena el arranque.
- **Portal:** cada pedido de sesión tiene un timeout total de 8 s (antes, por etapa); se dejan de probar servidores del portal a los 20 s. El servidor que dio la sesión se recuerda (`moiamov_session_host`) y se prueba primero; la descarga del catálogo también lo usa. La descarga corta si dejan de llegar datos durante 12 s (tope de 90 s por sección).

### Cancelación
- El botón aparece solo durante la descarga y solo si ya hay catálogo guardado (nunca en el primer arranque).  
- Corta solo la descarga (`cancelActiveRequests`); el login ya terminó y no se puede cortar.  
- Se sigue con el catálogo guardado.

### VPN (OpenVPN México)
- Dependencia: `openvpn_flutter` rama git `android_16kb` (ELF 16 KB).  
- Empaquetado: `android.packaging.jniLibs.useLegacyPackaging = true` (AGP; no poner `extractNativeLibs` en el manifest).  
- Perfiles: `assets/vpn/mexico_01..04.ovpn` (Proton) y `japan_01..02.ovpn` (VPN Gate, TCP 443, autentican con el certificado del archivo: `certIsRequired: true`, sin usuario). Los `remote` del archivo se reemplazan por el del endpoint; el `host` de cada nodo debe coincidir con el del `.ovpn` (lo verifica `test/vpn_node_ranking_test.dart`).  
- Usuario OpenVPN (solo Proton): se fuerza sufijo **`+b:0`** (`VpnService._ensureMexicoExitUsername`) para salida México; sin eso `verifyConnection` falla.  
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
- Descifrado, parseo y guardado corren en otro isolate (`MoiamovCatalogStore.processDownload` / `load`, ver SPEC-44 §3); la clave se pasa como argumento porque el isolate no ve `.env`.

### Arranque rápido en debug
`_kStartupLoginInDebug` (`lib/config/constants.dart`): en `false`, un build debug salta VPN, sesión y descarga y usa el catálogo guardado (las películas pueden no reproducirse). Un release **siempre** hace el login (`kStartupLoginEnabled = kReleaseMode || _kStartupLoginInDebug`).

---

## 5. Componentes UI

- `SettingsMoviesSeriesPanel`: fila de frecuencia con la fecha del catálogo.  
- `TvOptionSelector<T>`: chips D-pad (frecuencia; reutilizado en agenda).  
- Textos: `settings_general_catalog_freq*`, `loading_catalog_*`, `loading_session_failed` en `es.json`.  
- Loading: mismo fondo que el home (`MoaiAmbientBackground`) y un recuadro de vidrio esmerilado (`MoaiGlass(frosted: true)`) con el ícono de la etapa (`MoaiIcons.boot*`), el estado, una línea de detalle (`loading_attempt`, `loading_catalog_progress`) y la barra de progreso en el acento. El botón `loading_catalog_cancel` / `loading_catalog_cancel_no_date` es un `TvDialogButton` (acento con foco). El error usa el mismo vidrio con "Reintentar".

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
