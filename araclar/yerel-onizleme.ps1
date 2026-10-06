# M2YDesk yerel ön izleme: Flutter arayüzünü KAYNAK KODDAN açar (çalışan pencerede `r` = hot reload,
# `R` = hot restart, `q` = çık). Rust çekirdeği GitHub derlemesinden hazır alınır.
#
# Ön koşul (bir kez): Visual Studio Build Tools (C++ iş yükü), Flutter 3.24.5 ve
#   yerel-onizleme\rust-cekirdek\librustdesk.dll     (tam sürüm; paket exe'sinden yerel-onizleme\paket-ac.py)
#   yerel-onizleme\rust-cekirdek-qs\librustdesk.dll  (Hızlı Destek; -Hizli için)
#   flutter\lib\generated_bridge.dart               (derlemenin "bridge-artifact" çıktısından)
#
# Kullanım:  pwsh -ExecutionPolicy Bypass -File araclar\yerel-onizleme.ps1 [-Hizli] [-Giris]
#   -Hizli: Hızlı Destek (yalnız gelen bağlantı) çekirdeğiyle açar.
#   -Giris: oturumu silmeden giriş ekranını gösterir (yalnız debug; M2Y_GIRIS_ONIZLEME=1).
# Sınır: Rust'a gömülü şeyler (varsayılan ayar dosyası, servis başlatma) çekirdek yeniden derlenmeden değişmez.
param([switch]$Hizli, [switch]$Giris)
$ErrorActionPreference = 'Stop'
$kok = Split-Path $PSScriptRoot -Parent
# Flutter'ın gölge (shader) derleyicisi ASCII olmayan yollarda ("Yazılım…" gibi) dosya yazamaz; proje yolunda
# ASCII dışı karakter varsa aynı klasör R: sanal sürücüsü olarak bağlanır (kalıcı değil, oturum başına bir kez).
if ($kok -match '[^\x00-\x7F]') {
    if (-not (Test-Path 'R:\')) { subst R: $kok }
    $kok = 'R:\'
}
$flutter = Join-Path $kok 'flutter'
$cekirdek = Join-Path $kok ($(if ($Hizli) { 'yerel-onizleme\rust-cekirdek-qs' } else { 'yerel-onizleme\rust-cekirdek' }))
$ad = if ($Hizli) { 'M2YDeskQS' } else { 'M2YDesk' }

if (-not (Test-Path (Join-Path $cekirdek 'librustdesk.dll'))) {
    throw "librustdesk.dll yok: $cekirdek. Son derlemenin paket exe'sini yerel-onizleme\paket-ac.py ile açın."
}
$kopru = Join-Path $flutter 'lib\generated_bridge.dart'
if (-not (Test-Path $kopru)) {
    $kaynak = Get-ChildItem (Join-Path $kok 'yerel-onizleme') -Recurse -Filter 'generated_bridge.dart' | Select-Object -First 1
    if (-not $kaynak) { throw "generated_bridge.dart yok; derlemenin bridge-artifact çıktısını yerel-onizleme klasörüne açın." }
    Copy-Item $kaynak.FullName $kopru
    Copy-Item (Join-Path $kaynak.DirectoryName 'generated_bridge.freezed.dart') (Join-Path $flutter 'lib') -Force
}

# Aynı adlı pencere açıksa kapat (aksi hâlde exe kilitli kalır, derleme yazamaz).
Get-Process -Name $ad -ErrorAction SilentlyContinue | Stop-Process -Force

# CMake kurulum adımı çekirdeği depo kökündeki target\debug\librustdesk.dll yolundan alır (CI'da Rust derlemesi oraya yazar).
$env:M2Y_BINARY_NAME = $ad
$hedef = Join-Path $kok 'target\debug'
New-Item -ItemType Directory -Force $hedef | Out-Null
Copy-Item (Join-Path $cekirdek 'librustdesk.dll') (Join-Path $hedef 'librustdesk.dll') -Force

if ($Giris) { $env:M2Y_GIRIS_ONIZLEME = '1' } else { Remove-Item Env:M2Y_GIRIS_ONIZLEME -ErrorAction SilentlyContinue }

Set-Location $flutter
# Üretilen CMake dosyaları ikili (hedef) adını içerir; sürüm değişince (M2YDesk ↔ M2YDeskQS) derleme klasörü silinir.
$isaret = 'build\windows\m2y-ikili-adi.txt'
$onceki = if (Test-Path $isaret) { (Get-Content $isaret -Raw).Trim() } else { '' }
if ($onceki -ne $ad -and (Test-Path 'build\windows\x64')) { Remove-Item 'build\windows\x64' -Recurse -Force }
New-Item -ItemType Directory -Force 'build\windows' | Out-Null
Set-Content $isaret $ad
# `flutter run` varsayılan olarak rustdesk.exe arar; ikili adı farklı olduğu için önce derlenir, sonra o exe bağlanır.
flutter build windows --debug
if ($LASTEXITCODE -ne 0) { throw "flutter build windows başarısız ($LASTEXITCODE)" }
flutter run -d windows --use-application-binary "build\windows\x64\runner\Debug\$ad.exe"
