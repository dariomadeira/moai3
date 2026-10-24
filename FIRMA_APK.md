# Firma del APK: publicar actualizaciones desde Linux o Windows

## El problema

Android solo instala una actualización si el APK nuevo está firmado con **la
misma llave** que la versión ya instalada. Si la llave cambia, la rechaza
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) y el TV se queda con la versión vieja.

moai3 firma el release con la llave de **debug**
(`android/app/build.gradle.kts`: `signingConfig = signingConfigs.getByName("debug")`).
Esa llave no está en el proyecto: cada máquina tiene la suya en
`~/.android/debug.keystore`, creada al azar la primera vez que compila.

- Linux firma con su llave → es la que tienen los TV instalados.
- Windows firma con otra llave → los TV rechazan esa actualización.

**Solución:** copiar el `debug.keystore` de Linux a Windows. Desde ahí las dos
máquinas firman igual.

Huella (SHA-256) de la llave de **Windows** actual (la que NO sirve), para
comparar:

```
7E:B8:B3:E1:00:4A:A6:C8:44:70:56:81:F3:89:5C:24:E0:06:07:91:E6:52:0A:59:D3:A5:FA:D8:98:A1:DD:75
```

---

## Paso 1 — En Linux

1. Ver la huella de la llave de Linux y **anotarla**:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -storepass android | grep SHA256
   ```

   Si `keytool` no está en el PATH, usar el de Android Studio:
   `<android-studio>/jbr/bin/keytool`.

   Tiene que ser **distinta** de la de Windows de arriba. Si es igual, el
   problema es otro: avisar antes de seguir.

2. (Opcional, confirma que es la llave correcta) Ver con qué llave está
   firmado un APK publicado que los TV sí aceptan:

   ```bash
   $ANDROID_HOME/build-tools/<versión>/apksigner verify --print-certs ruta/al/app-release.apk | grep SHA-256
   ```

   Debe coincidir con la huella del punto 1 (sin los `:` y en minúsculas).

3. Copiar el archivo a un pendrive o a una carpeta privada (Drive, etc.):

   ```bash
   cp ~/.android/debug.keystore /media/<usuario>/<pendrive>/debug.keystore
   ```

> ⚠️ **Nunca subir `debug.keystore` a git** ni a ningún repo. Quien tenga
> esa llave puede firmar APKs que los TV aceptan como actualización de moai3.

---

## Paso 2 — En Windows (PowerShell)

1. Guardar la llave actual de Windows por las dudas:

   ```powershell
   Copy-Item "$env:USERPROFILE\.android\debug.keystore" "$env:USERPROFILE\.android\debug.keystore.windows.bak"
   ```

2. Copiar la llave de Linux en su lugar (ajustar la letra del pendrive):

   ```powershell
   Copy-Item "E:\debug.keystore" "$env:USERPROFILE\.android\debug.keystore" -Force
   ```

3. Verificar que ahora la huella es la de Linux (la anotada en el Paso 1):

   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -J-Duser.language=en -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android | Select-String SHA256
   ```

   (`-J-Duser.language=en` evita un error del keytool en español.)

4. Compilar el release como siempre y comprobar la firma del APK:

   ```powershell
   flutter build apk --release
   $bt = (Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" | Sort-Object Name)[-1].FullName
   & "$bt\apksigner.bat" verify --print-certs build\app\outputs\flutter-apk\app-release.apk | Select-String SHA-256
   ```

   Tiene que dar la huella de Linux. Recién ahí publicar.

---

## Después del cambio

- El emulador de Windows tiene moai3 firmado con la llave vieja de Windows:
  la primera vez hay que desinstalarlo (`adb -s emulator-5554 uninstall com.infomak.moai`)
  antes de instalar uno firmado con la llave nueva.
- **Hacer backup de `debug.keystore`** en un lugar seguro y privado. Si se
  pierde, ningún TV puede actualizarse sin desinstalar la app a mano.
- A futuro conviene una llave de release propia (`key.properties`, ya está
  en `.gitignore`) en lugar de la de debug; mientras tanto, esto alcanza.
