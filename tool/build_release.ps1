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
