# M2YDesk — Windows PowerShell kurulum betiği.
# Kurulum (kalıcı, yönetici onayı ister):
#   irm https://desk.mehmetmesut.com/win-kur.ps1 | iex
# Hızlı Destek (kurulumsuz, hemen açılır):
#   $env:M2Y_HIZLI='1'; irm https://desk.mehmetmesut.com/win-kur.ps1 | iex
#
# Ne yapar: imzalı surum.json'daki dosyayı indirir, SHA-256'sını doğrular; doğrulanmayan dosyayı
# asla çalıştırmaz. Dosya PowerShell ile indirildiği için "Windows bilgisayarınızı korudu"
# (SmartScreen) uyarısı çıkmaz.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Alan = 'desk.mehmetmesut.com'
$Hizli = $env:M2Y_HIZLI -eq '1'
Remove-Item Env:\M2Y_HIZLI -ErrorAction SilentlyContinue

function Bilgi($m) { Write-Host "• $m" -ForegroundColor Cyan }
function Hata($m) { Write-Host "✗ $m" -ForegroundColor Red; throw $m }

if ([Environment]::OSVersion.Platform -ne 'Win32NT') { Hata 'Bu betik yalnızca Windows içindir.' }
if (-not [Environment]::Is64BitOperatingSystem) { Hata 'M2YDesk 64 bit Windows gerektirir.' }

Bilgi 'Sürüm bilgisi alınıyor…'
$Surum = Invoke-RestMethod -UseBasicParsing "https://$Alan/guncelleme/surum.json"
$Anahtar = if ($Hizli) { 'windows_qs' } else { 'windows_msi' }
$Dosya = $Surum.dosyalar.$Anahtar
if (-not $Dosya) { Hata "Bu sürümde $Anahtar dosyası yayımlanmamış." }
if (-not $Dosya.url.StartsWith("https://$Alan/")) { Hata "Beklenmeyen indirme adresi: $($Dosya.url)" }

$Ad = Split-Path $Dosya.url -Leaf
$Klasor = Join-Path $env:TEMP 'M2YDesk-kurulum'
New-Item -ItemType Directory -Force -Path $Klasor | Out-Null
$Yol = Join-Path $Klasor $Ad

Bilgi "M2YDesk $($Surum.version) indiriliyor ($Ad)…"
Invoke-WebRequest -UseBasicParsing -Uri $Dosya.url -OutFile $Yol

Bilgi 'Dosya doğrulanıyor (SHA-256)…'
$Gercek = (Get-FileHash -Algorithm SHA256 -Path $Yol).Hash.ToLowerInvariant()
if ($Gercek -ne $Dosya.sha256.ToLowerInvariant()) {
    Remove-Item $Yol -Force -ErrorAction SilentlyContinue
    Hata 'Doğrulama başarısız: dosya bozuk ya da değiştirilmiş. Hiçbir şey çalıştırılmadı.'
}

if ($Hizli) {
    Bilgi 'Hızlı Destek açılıyor…'
    Start-Process -FilePath $Yol
    Write-Host '✓ Hızlı Destek açıldı. Danışmanınıza ekrandaki kimliği ve parolayı iletin.' -ForegroundColor Green
} else {
    Bilgi 'Kuruluyor (yönetici onayı istenecek)…'
    $P = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$Yol`"", '/passive', '/norestart') -Verb RunAs -Wait -PassThru
    if ($P.ExitCode -ne 0 -and $P.ExitCode -ne 3010) { Hata "Kurulum tamamlanamadı (kod $($P.ExitCode))." }
    Write-Host '✓ M2YDesk kuruldu. Başlat menüsünden açabilirsiniz.' -ForegroundColor Green
}
