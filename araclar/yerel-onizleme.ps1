# M2YDesk yerel ön izleme: Flutter arayüzünü KAYNAK KODDAN açar (kod değişince ≈1 sn'de ekranda görünür:
# çalışan pencerede `r` = hot reload, `R` = hot restart, `q` = çık). Rust çekirdeği GitHub derlemesinden hazır alınır.
#
# Ön koşul (bir kez): Visual Studio Build Tools (C++ iş yükü), Flutter 3.24.5 ve
#   yerel-onizleme\rust-cekirdek\librustdesk.dll  (son derlemenin paketinden: yerel-onizleme\paket-ac.py)
#   flutter\lib\generated_bridge.dart            (derlemenin "bridge-artifact" çıktısından)
#
# Kullanım:  powershell -ExecutionPolicy Bypass -File araclar\yerel-onizleme.ps1
# Sınır: Rust'a gömülü şeyler (varsayılan ayar dosyası, servis başlatma) çekirdek yeniden derlenmeden değişmez.
$ErrorActionPreference = 'Stop'
$kok = Split-Path $PSScriptRoot -Parent
$flutter = Join-Path $kok 'flutter'
$cekirdek = Join-Path $kok 'yerel-onizleme\rust-cekirdek'

if (-not (Test-Path (Join-Path $cekirdek 'librustdesk.dll'))) {
    throw "librustdesk.dll yok: $cekirdek. Son derlemenin M2YDesk-<sürüm>-x86_64.exe dosyasını yerel-onizleme\paket-ac.py ile açın."
}
$kopru = Join-Path $flutter 'lib\generated_bridge.dart'
if (-not (Test-Path $kopru)) {
    $kaynak = Get-ChildItem (Join-Path $kok 'yerel-onizleme') -Recurse -Filter 'generated_bridge.dart' | Select-Object -First 1
    if (-not $kaynak) { throw "generated_bridge.dart yok; derlemenin bridge-artifact çıktısını yerel-onizleme klasörüne açın." }
    Copy-Item $kaynak.FullName $kopru
    Copy-Item (Join-Path $kaynak.DirectoryName 'generated_bridge.freezed.dart') (Join-Path $flutter 'lib') -Force
}

# Derleme çıktısına çekirdeği önceden koy: `flutter run` bu klasöre yazar, mevcut dosyaları silmez.
$env:M2Y_BINARY_NAME = 'M2YDesk'
$hedef = Join-Path $flutter 'build\windows\x64\runner\Debug'
New-Item -ItemType Directory -Force $hedef | Out-Null
Get-ChildItem $cekirdek -File -Filter '*.dll' |
    Where-Object { $_.Name -in @('librustdesk.dll', 'dylib_virtual_display.dll') } |
    ForEach-Object { Copy-Item $_.FullName $hedef -Force }

Set-Location $flutter
flutter run -d windows
