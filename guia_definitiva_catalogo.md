# Guía definitiva: de la VPN al catálogo en vivo de Xuper

Documento de referencia que describe, con lujo de detalle, **todo** el proceso que
Moai 3 ejecuta en el arranque para obtener el catálogo real (EN VIVO) de Xuper
Hydra: desde el levantado del túnel OpenVPN hasta México, pasando por la
autenticación anónima por dispositivo, hasta la descarga y descifrado de las
columnas de películas, series y destacados.

> Estado: **flujo verificado y funcionando** en el emulador Android TV
> (`emulator-5556`, x86_64, Android 14) con VPN de México activa.
> Resultado de referencia: `userId=968525810`, `portal=masnew`,
> **270 películas / 90 destacados / 306 series** EN VIVO.

---

## 0. Resumen del flujo completo

```
Arranque (LoadingScreen)
  │
  ├── 1. Verificación de presencia (Supabase) ──► puede bloquear el equipo
  │
  ├── 2. LOOP DE NODOS (max 4):
  │        ├─ VPN: conectar nodo México (OpenVPN)  ──►  verifyConnection() == MX
  │        ├─ esperar 2 s (estabilizar rutas/DNS de tun0)
  │        └─ Sesión: activateDeviceSession()
  │                  ├─ v3/snToken  ──► snToken
  │                  └─ v8/active   ──► userId + userToken + portalCode
  │        └─ si la sesión falla: desconectar VPN y rotar al siguiente nodo
  │
  ├── 3. CATÁLOGO (si vpnConnected && sessionOk):
  │        ├─ getNextColumns "masnew_movies"   ──► películas
  │        ├─ getNextColumns "masnew_featured" ──► destacados
  │        └─ getNextColumns "masnew_series"   ──► series
  │
  └── 4. Fallbacks visibles si no hubo vivo:
           ├─ documento local del TV (com.xuper.netxxus)
           └─ asset empaquetado (assets/data/*.json)
```

La pantalla de loading muestra en todo momento un **banner de origen** (`EN VIVO`
/ `LOCAL` / `HARDCODEADO`) y una **bitácora** (`XuperApiService.liveLog`) para que
sea imposible confundir un catálogo real con uno de respaldo.

---

## 1. Requisitos y entorno

- **Flutter**: `export PATH="/home/apogeo/flutter/bin:$PATH"`.
- **Build**: `cd /home/apogeo/moai/moai3 && flutter build apk --debug`
  (artefacto: `build/app/outputs/flutter-apk/app-debug.apk`).
- **Instalar/probar**:
  ```bash
  adb -s emulator-5556 install -r build/app/outputs/flutter-apk/app-debug.apk
  adb -s emulator-5556 shell am force-stop com.infomak.moai
  adb -s emulator-5556 logcat -c
  adb -s emulator-5556 shell monkey -p com.infomak.moai -c android.intent.category.LAUNCHER 1
  sleep 65
  adb -s emulator-5556 logcat -d | grep -E "XUPER|VPN"
  ```
- **Dependencias relevantes**: `openvpn_flutter` (VPN), `pointycastle` (3DES/MD5),
  `http` (chequeo de IP de salida).
- **Permiso VPN de Android**: se solicita con `requestPermissionAndroid()` antes
  de conectar; el usuario debe aceptar el diálogo del sistema.

> ⚠️ El portal **rechaza con HTTP 400 (WAF regional)** cualquier POST cifrado que
> venga de una IP que no sea de México. Por eso la validación real **solo** se
> puede hacer dentro del emulador con la VPN MX arriba. Desde la máquina dev,
> un `curl` con IP no-MX devuelve `portal200001`, no sirve para validar.

---

## 2. Fase VPN (OpenVPN a México)

Implementada en `lib/services/vpn_service.dart` (`VpnService` singleton).

### 2.1 Perfiles
Cuatro perfiles empaquetados en `assets/vpn/`:

| Nodo | Archivo | IP de salida |
|------|---------|--------------|
| 1 | `mexico_01.ovpn` | 84.20.27.49 |
| 2 | `mexico_02.ovpn` | 84.20.27.45 |
| 3 | `mexico_03.ovpn` | 103.88.234.229 |
| 4 | `mexico_04.ovpn` | 149.102.224.43 |

Configuración: `dev tun`, `proto udp`, `AES-256-GCM`, `tun-mtu 1400`,
`mssfix 1200`. Credenciales `auth-user-pass` embebidas en los perfiles y
reinyectadas en runtime (bloque `<auth-user-pass>` reemplazado por la directiva
estándar + `username`/`password`).

### 2.2 Conexión (`connectMexico`)
1. `initialize()` → crea el motor `OpenVPN` y escucha `onVpnStageChanged`.
2. `requestPermissionAndroid()` → pide el permiso de VPN al sistema.
3. Carga el `.ovpn` del nodo pedido (`nodeIndex`).
4. Se suscribe a `stageStream` **antes** de conectar y completa un `Completer`
   cuando llega `VPNStage.connected` (o falla/expira el timeout de 14 s).
5. Invoca `_engine.connect(config, name, username, password, certIsRequired: true)`.
6. Al conectar, llama a `verifyConnection()`.

### 2.3 Verificación de salida (`verifyConnection`)
- Consulta `http://ip-api.com/json`; si `countryCode == "MX"` → **OK**.
- Guarda `lastExitIp` / `lastExitCountry` para mostrarlos en pantalla.
- Fallbacks: `generate_204` de Google y `cdn-cgi/trace` de Cloudflare.
- Si la salida no es MX, `connectMexico` devuelve `false` y el loop rota de nodo.

### 2.4 Rotación de nodos
En `loading_screen.dart` (`_startVerification`) se itera `node = 0..maxNodes-1`
(max 4). Por cada nodo: conectar VPN → verificar MX → esperar 2 s → intentar
`ensureSession()`. Si la sesión falla, `VpnService.instance.disconnect()` y se
pasa al siguiente nodo. Solo si `vpnConnected && sessionOk` se descarga catálogo.

---

## 3. Fase de sesión (autenticación anónima por dispositivo)

Implementada en `lib/services/xuper_api_service.dart`
(`XuperApiService.activateDeviceSession`). Es un **flujo guest** (equipo sin
número de serie de fábrica, sin credenciales), réplica de la app original.

### 3.1 Huella del dispositivo
Se obtiene con el canal nativo `com.infomak.moai.tv/device` →
`getDeviceFingerprint` (implementado en `MainActivity.kt`): `androidId`
(`Settings.Secure.ANDROID_ID`), `wifiMac`, `etheMac`, `serialNumber`, `diskInfo`,
`ramSize`, `romSize`, `gatewayMac`, `cpuId`, `display`, `brand`, `verId`,
`cpuAbi`, `hardware`, `manufacturer`, `fingerprint`, `host`, `device`, `board`,
`tags`. Si el canal falla, se usa `_fallbackFingerprint`.

El `MAC` efectivo (`_deviceMac`) prioriza `wifiMac`; si viene vacío o es
`02:00:00:00:00:00` se usa `etheMac`.

### 3.2 Paso 1 — `POST /api/portalCore/v3/snToken`
Réplica del `SnTokenBean`. Payload (cifrado, ver §5):

```json
{ "loginType":"2", "androidId":"…", "wifiMac":"…", "etheMac":"…",
  "serialNumber":"…", "diskInfo":"…", "ramSize":"…", "romSize":"…",
  "gatewayMac":"…", "cpuId":"…", "display":"…", "brand":"…", "verId":"…",
  "cpuAbi":"…", "hardware":"…", "manufacturer":"…", "fingerprint":"…",
  "host":"…", "device":"…", "board":"…", "tags":"…" }
```

Respuesta (ejemplo real):
```json
{"returnCode":"0","errorMessage":"成功","data":"<hex 3DES cifrado>"}
```
El campo **`data` viene CIFRADO** (hex de 3DES-base64) y hay que descifrarlo con
`portalKey` para obtener:
```json
{"snToken":"da5100d2-…", "isNew":"…", "userId":"…", "sn":"…"}
```
`_fetchSnToken()` envuelve esto: descifra `data`, y devuelve el mapa con
`_token = snToken` (o `sn` si no hay `snToken`).

### 3.3 Cálculo del campo `sn` (CLAVE del arreglo)
El envelope de todas las peticiones exige el campo `sn`, que en el APK es
`KEY_SP_SN` y lo escribe el handler de `v3/snToken` inmediatamente después:

```
sn = MD5( snToken + "ntFT65w6itH!lHCPw7D=@qnsFC5adD28" ).toLowerCase()
```

En código: `_md5Hex('${snToken}ntFT65w6itH!lHCPw7D=@qnsFC5adD28')`.
**Enviar `sn:''` provoca `returnCode 1 请求参数异常` en `v8/active`.** Este fue el
bug que bloqueaba la activación.

### 3.4 Paso 2 — `POST /api/portalCore/v8/active`
Payload activo (verificado, el que acepta el server):

```json
{ "loginType":"2",
  "snToken":"<de v3/snToken>",
  "authVersion":"", "authCode":"", "preCode":"",
  "macAddr":"<MAC del dispositivo>",
  "reserve1":"<3DES(mac) con clave combrasiltvaslgklxckbcombrasiltv>",
  "openNum":0, "channel":"default", "matadata":"", "signdata":"",
  "sn":"<MD5(snToken+salt)>",
  "cpu":"x86_64",
  "B29":"<3DES(serial) con clave combrasiltvaslgklxckbcombrasiltv>" }
```

Detalles:
- `reserve1` = `_encryptWithKey(localMac, "combrasiltvaslgklxckbcombrasiltv")`
  (el MAC sin `:`; **no** el MAC plano).
- `B29` = `_encryptWithKey(serialNumber, "combrasiltvaslgklxckbcombrasiltv")`.
- El campo de ABI se llama `cpu` (no `abi`).
- `loginType` = `"2"` para guest; `"1"` para cajas con SN.

Respuesta:
```json
{"returnCode":"0","errorMessage":"成功","data":"<hex 3DES cifrado>"}
```
`_applyActiveResult()` descifra `data` con `portalKey` y extrae:
`userId`, `userToken`, y `portalCodeList[0].portalCode` (o `portalCode`).
Resultado real: `userId=968525810`, `portal=masnew`.

### 3.5 Geo-bloqueo
Si `v8/active` responde `portal100024` o el mensaje contiene `黑名单`
(lista negra) / `区域` (región), se registra `🚫 GEOBLOCK` y se corta: significa
que la IP de salida del nodo VPN está listada. Solución: rotar de nodo/proveedor.

---

## 4. Fase de catálogo (`getNextColumns`)

En `syncCatalog()` (prioridad 1: vivo).

`POST /api/portalCore/getNextColumns` con payload:
```json
{ "userToken":"<de active>", "userId":"<de active>", "portalCode":"<de active>",
  "pageNum":1, "pageSize":50, "columnCode":"masnew_movies", "version":"" }
```
Códigos de columna:
| Sección | `columnCode` |
|---------|--------------|
| Películas | `masnew_movies` |
| Destacados | `masnew_featured` |
| Series | `masnew_series` |

La respuesta trae `data` cifrado; al descifrarlo aparece `recommendList`
(lista de categorías → cada una con sus títulos). Se parsea con
`CategoryColumn.fromJson`. Resultado real:
`270 películas / 90 destacados / 306 series`.

### 4.1 Fallbacks (si no hay vivo)
2. **Documento local del TV** (`_loadFromLocalDeviceDocument`): lee y descifra
   `/sdcard/Android/data/com.xuper.netxxus/files/Documents/<seccion>;1` con
   `localDocumentKey`.
3. **Asset empaquetado**: `assets/data/masnew_movies.json`,
   `masnew_featured.json`, `masnew_series.json`.

El `CatalogResult.source` (`CatalogSource.liveApi | localDocument | assetBundle`)
determina el banner visible (`EN VIVO` / `LOCAL` / `HARDCODEADO`).

---

## 5. Criptografía (3DES) — referencia exacta

- **Algoritmo**: Triple DES / ECB / PKCS7 (PKCS5).
- **Formato de transporte**: `hex( base64( ciphertext ) )`.
- **Base64**: alfabeto estándar, implementación propia `_customBase64Decode`
  (ignora `\n` y `\r`).
- **Clave**: `_customBase64Decode(portalKey)` truncada a **24 bytes**.
- **`decryptDocument(hex, key)`** = descifra el body de las respuestas.
- **`encryptPayload(map)`** = fusiona el envelope + cifra el body de las requests.
- **`_encryptWithKey(plain, key)`** = 3DES genérico (usado para `reserve1`/`B29`).
- **`_md5Hex(str)`** = MD5 hex minúscula (usado para `sn`).

### Claves y constantes
| Constante | Valor |
|-----------|-------|
| `portalKey` | `568e194f-d170-4369-96e8-4a457f641880` (request + decrypt de `data`) |
| `localDocumentKey` | `b700bce0-91c7-47df-a593-747ae941bf34` |
| clave `reserve1`/`B29` | `combrasiltvaslgklxckbcombrasiltv` |
| salt de `sn` | `ntFT65w6itH!lHCPw7D=@qnsFC5adD28` |
| `baseUrl` default | `https://ftmrmy.jdfey0cd.com` |

### Envelope inyectado por `encryptPayload`
`loginType, appLanguage('es'), apkVersion('43404'), sysVersion('1.1.4'),
appId('com.android.msandroid'), hardwareInfo, model, product, abi, deviceToken,
sn, drmId, sdkVer(34)`.

### Headers HTTP (todas las peticiones)
```
Content-Type: application/json;charset=utf-8
apk: com.android.msandroid
apkVer: 43404
spkgVer: 1.1.4
PORTAL_KEY: 568e194f-d170-4369-96e8-4a457f641880
ProcessResult: false
User-Agent: Mozilla/5.0 (Linux; Android 10; TV) Mobile Safari/537.36
```

---

## 6. Endpoints

| Método | Ruta | Propósito |
|--------|------|-----------|
| POST | `/api/portalCore/v3/snToken` | Emite `snToken` (equipo guest) |
| POST | `/api/portalCore/v8/active` | Activa sesión → `userId`/`userToken`/`portalCode` |
| POST | `/api/portalCore/getNextColumns` | Devuelve las columnas del catálogo |

Hosts candidatos (en orden): el configurado como `serverUrl`, luego
`https://ftmrmy.jdfey0cd.com`.

---

## 7. Diagnóstico y troubleshooting

| Síntoma | Causa | Solución |
|---------|-------|----------|
| `HTTP 400` desde la máquina dev | WAF regional (IP no-MX) | Probar **solo** dentro del emulador con VPN MX |
| `v8/active` → `returnCode 1 请求参数异常` | falta `sn` correcto o `reserve1` plano | `sn=MD5(snToken+salt)`, `reserve1=3DES(mac)` |
| `snToken sin data` | no se descifraba el `data` | descifrar `data` con `portalKey` (§5) |
| VPN no verifica MX | nodo caído / IP lista | rotar de nodo (§2.4) |
| `portal100024` / `黑名单` | IP en lista negra | cambiar nodo/proveedor VPN |
| Catálogo HARDCODEADO | nunca hubo sesión | revisar bitácora de loading; ver §2/§3 |

### Checklist de verificación (logcat esperado)
```
▶ Inicio de verificación de arranque Moai
VPN México: nodo 1/4
VPN conectada. Salida: 205.147.22.15 (MX)
Sesión: v3/snToken → https://ftmrmy.jdfey0cd.com
✅ snToken obtenido: da5100d2-… (sn=…)
Sesión: v8/active → https://ftmrmy.jdfey0cd.com
✅ Sesión activada: userId=968525810 portal=masnew
✅ Sesión de dispositivo obtenida.
✅ EN VIVO: 270 títulos en 27 categorías (Películas)
✅ EN VIVO: 90 títulos en 9 categorías (Destacados)
✅ EN VIVO: 306 títulos en 31 categorías (Series)
```

> Lección aprendida: verificar siempre que el **APK instalado sea posterior** a la
> fuente modificada (`ls -l --time-style=+%H:%M:%S`) antes de concluir que un fix
> no funcionó.

---

## 8. Mapa de archivos

| Archivo | Rol |
|---------|-----|
| `lib/services/vpn_service.dart` | OpenVPN México, perfiles, verificación de IP, rotación |
| `lib/services/xuper_api_service.dart` | Envelope + 3DES + `snToken`/`active`/`getNextColumns` + bitácora |
| `lib/features/loading/screens/loading_screen.dart` | Loop combinado VPN+sesión, descarga, banner y bitácora |
| `lib/models/movie_models.dart` | `CatalogSource`, `CatalogResult` |
| `android/app/src/main/kotlin/com/infomak/moai/MainActivity.kt` | Canal nativo `getDeviceFingerprint` |
| `assets/vpn/mexico_0{1..4}.ovpn` | Perfiles VPN México |
| `assets/data/*.json` | Catálogo de respaldo empaquetado |
| `test/xuper_api_service_test.dart` | Tests de cifrado/descifrado |
