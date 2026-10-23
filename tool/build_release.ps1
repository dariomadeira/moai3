# Arma los APK de release para publicar en GitHub Releases (SPEC-50 §6.4).
#
# Deja en dist/:
#   app-armeabi-v7a-release.apk  (Chromecast y TVs de 32 bits)  ~27 MB
#   app-arm64-v8a-release.apk    (TVs de 64 bits)               ~31 MB
#   app-x86_64-release.apk       (emuladores)                   ~29 MB
#   app-release.apk              (universal, respaldo)          ~79 MB
#
# UpdateService elige el APK por arquitectura (busca "armeabi"/"arm64"/"x86_64"
# en el nombre) y, si no reconoce el aparato, usa app-release.apk.
# Subí los cuatro archivos al release.
#
# OJO: --split-per-abi suma 1000 x ABI al versionCode (armeabi-v7a 31 -> 1031).
# Si instalás uno de estos APK en un aparato de pruebas, después `flutter run`
# (versionCode 31) falla por "downgrade" y DESINSTALA la app, borrando sus
# datos (extensiones, ROMs, ajustes). Para volver a desarrollar en ese
# aparato, instalá antes con `adb install -r -d` o no uses estos APK ahí.
# Por la misma razón, un aparato que ya tiene un APK por ABI no puede bajar al
# universal (versionCode menor): publicá siempre los de ABI.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$out = 'build/app/outputs/flutter-apk'
$dist = 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Falló el build universal' }
Copy-Item "$out/app-release.apk" "$dist/app-release.apk" -Force

flutter build apk --release --split-per-abi
if ($LASTEXITCODE -ne 0) { throw 'Falló el build por ABI' }
foreach ($abi in 'armeabi-v7a', 'arm64-v8a', 'x86_64') {
  Copy-Item "$out/app-$abi-release.apk" "$dist/app-$abi-release.apk" -Force
}

Get-ChildItem $dist -Filter *.apk |
  Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } |
  Format-Table -AutoSize
