#!/bin/bash
# M2YDesk — macOS kurulum betiği (Apple Silicon).
# Kullanım (Terminal):  curl -fsSL https://desk.mehmetmesut.com/mac-kur.sh | bash
#
# Ne yapar: imzalı surum.json'daki macOS dosyasını indirir, SHA-256'sını doğrular, uygulamayı
# /Applications'a kopyalar ve Gatekeeper karantinasını kaldırır ("Yine de aç" adımı gerekmez).
# Ne YAPMAZ: Ekran Kaydı ve Erişilebilirlik izinlerini vermez. macOS bu izinleri yalnızca
# kullanıcının kendisinin vermesine izin verir; uygulama açılınca adım adım yönlendirir.
set -euo pipefail

ALAN="desk.mehmetmesut.com"
UYGULAMA="M2YDesk.app"
HEDEF="/Applications/$UYGULAMA"

bilgi() { printf '\033[1;34m•\033[0m %s\n' "$1"; }
hata()  { printf '\033[1;31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || hata "Bu betik yalnızca macOS içindir."
[ "$(uname -m)" = "arm64" ] || hata "Bu sürüm Apple Silicon (M1 ve üzeri) içindir; Intel Mac henüz desteklenmiyor."

GECICI="$(mktemp -d)"
trap 'hdiutil detach "$GECICI/mnt" -quiet 2>/dev/null || true; rm -rf "$GECICI"' EXIT

bilgi "Sürüm bilgisi alınıyor…"
curl -fsSL "https://$ALAN/guncelleme/surum.json" -o "$GECICI/surum.json" || hata "Sunucuya ulaşılamadı."

# JSON'u macOS'ta her zaman bulunan JavaScript (osascript) ile oku
OKU='function run(a){var j=JSON.parse($.NSString.stringWithContentsOfFileEncodingError(a[0],4,null).js);var d=(j.dosyalar||{}).macos_apple;return d?(d.url+"\n"+d.sha256+"\n"+j.version):""}'
BILGI="$(osascript -l JavaScript -e "ObjC.import('Foundation');$OKU" "$GECICI/surum.json")"
[ -n "$BILGI" ] || hata "Bu sürümde macOS dosyası henüz yayımlanmamış."
URL="$(printf '%s\n' "$BILGI" | sed -n 1p)"
OZET="$(printf '%s\n' "$BILGI" | sed -n 2p | tr 'A-F' 'a-f')"
SURUM="$(printf '%s\n' "$BILGI" | sed -n 3p)"
case "$URL" in "https://$ALAN/"*) ;; *) hata "Beklenmeyen indirme adresi: $URL" ;; esac

bilgi "M2YDesk $SURUM indiriliyor…"
curl -fL --progress-bar "$URL" -o "$GECICI/M2YDesk.dmg" || hata "İndirme başarısız."

bilgi "Dosya doğrulanıyor (SHA-256)…"
GERCEK="$(shasum -a 256 "$GECICI/M2YDesk.dmg" | awk '{print $1}')"
[ "$GERCEK" = "$OZET" ] || hata "Doğrulama başarısız: dosya bozuk ya da değiştirilmiş. Kurulum yapılmadı."

bilgi "Kuruluyor…"
mkdir -p "$GECICI/mnt"
hdiutil attach "$GECICI/M2YDesk.dmg" -nobrowse -readonly -mountpoint "$GECICI/mnt" -quiet
[ -d "$GECICI/mnt/$UYGULAMA" ] || hata "Disk görüntüsünde $UYGULAMA bulunamadı."
pkill -x M2YDesk 2>/dev/null || true
if [ -w /Applications ]; then
    rm -rf "$HEDEF"; ditto "$GECICI/mnt/$UYGULAMA" "$HEDEF"
else
    bilgi "/Applications için yönetici parolanız istenecek."
    sudo rm -rf "$HEDEF"; sudo ditto "$GECICI/mnt/$UYGULAMA" "$HEDEF"
fi
xattr -dr com.apple.quarantine "$HEDEF" 2>/dev/null || sudo xattr -dr com.apple.quarantine "$HEDEF" 2>/dev/null || true

bilgi "M2YDesk açılıyor. Uygulama, Ekran Kaydı ve Erişilebilirlik izinlerini nasıl vereceğinizi adım adım gösterecek."
open "$HEDEF"
printf '\033[1;32m✓ Kurulum tamamlandı: %s\033[0m\n' "$HEDEF"
