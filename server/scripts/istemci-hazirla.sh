#!/usr/bin/env bash
# Önceden yapılandırılmış RustDesk istemcilerini hazırlar ve indirme sayfasına koyar.
#
# RustDesk istemcisi, dosya adında "rustdesk-host=<sunucu>,key=<anahtar>" görürse
# sunucu ve anahtarı açılışta otomatik alır. Böylece danışanlar hiçbir ayar girmez.
#
# Kullanım:
#   sudo bash scripts/istemci-hazirla.sh                       # sürüm: GitHub'daki son sürüm
#   RUSTDESK_ISTEMCI_SURUM=1.4.2 sudo bash scripts/istemci-hazirla.sh
#   SITE_DIZINI=/var/www/vhosts/mehmetmesut.com/rustdesk.mehmetmesut.com sudo bash scripts/istemci-hazirla.sh
#
# Çıktı: $SITE_DIZINI/indir/  (istemci dosyaları)  ve  $SITE_DIZINI/ayar.js (sayfa ayarı)

set -euo pipefail

PROJE_DIZINI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJE_DIZINI"

bilgi()  { echo -e "\e[34m[BİLGİ]\e[0m $*"; }
basari() { echo -e "\e[32m[TAMAM]\e[0m $*"; }
uyari()  { echo -e "\e[33m[UYARI]\e[0m $*"; }
hata()   { echo -e "\e[31m[HATA]\e[0m $*" >&2; exit 1; }

# 1) Sunucu ayarları ve AÇIK anahtar (özel anahtar hiçbir zaman kopyalanmaz)
[[ -f .env ]] || hata ".env bulunamadı. Önce scripts/kurulum.sh çalıştırın."
# shellcheck disable=SC1091
source .env
[[ -s data/id_ed25519.pub ]] || hata "Açık anahtar yok: data/id_ed25519.pub (sunucu çalışıyor mu?)"
ANAHTAR="$(tr -d '\r\n' < data/id_ed25519.pub)"

# Dosya adında kullanılamayacak karakter kontrolü (base64 anahtar zaten güvenlidir)
[[ "$ANAHTAR" =~ ^[A-Za-z0-9+/=]+$ ]] || hata "Anahtar beklenmeyen karakter içeriyor."

# Varsayılan site dizini: depo içindeki site/httpdocs (Plesk'te alt alan adının httpdocs yolu verilir)
SITE_DIZINI="${SITE_DIZINI:-$PROJE_DIZINI/site/httpdocs}"
INDIR_DIZINI="$SITE_DIZINI/indir"
mkdir -p "$INDIR_DIZINI"

# 2) Sürüm belirle
SURUM="${RUSTDESK_ISTEMCI_SURUM:-}"
if [[ -z "$SURUM" ]]; then
    bilgi "GitHub'dan son sürüm sorgulanıyor..."
    SURUM="$(curl -fsSL -m 30 https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
        | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')" || true
    [[ -n "$SURUM" ]] || hata "Sürüm alınamadı. RUSTDESK_ISTEMCI_SURUM=1.4.2 gibi elle verin."
fi
bilgi "İstemci sürümü: $SURUM"

# 3) Sürümün varlık listesini al; dosya adları sürümler arasında değişebildiği için
#    kalıp eşleştirme ile gerçek URL seçilir.
VARLIKLAR="$(curl -fsSL -m 30 "https://api.github.com/repos/rustdesk/rustdesk/releases/tags/$SURUM" \
    | grep '"browser_download_url"' | sed -E 's/.*"(https:[^"]+)".*/\1/')"
[[ -n "$VARLIKLAR" ]] || hata "Sürüm $SURUM için dosya listesi alınamadı."

# platform|arama kalıbı|hedef dosya adı (ön ek hariç)
# Hedef ad: rustdesk-host=<sunucu>,key=<anahtar>.<uzantı>
ONEK="rustdesk-host=${ALAN_ADI},key=${ANAHTAR}"
declare -A HEDEFLER=(
    [windows]="x86_64\.exe$|${ONEK}.exe"
    [macos_intel]="x86_64\.dmg$|${ONEK}-intel.dmg"
    [macos_apple]="aarch64\.dmg$|${ONEK}-apple-silicon.dmg"
    [linux_deb]="x86_64\.deb$|${ONEK}.deb"
    [linux_appimage]="x86_64\.AppImage$|${ONEK}.AppImage"
    [android]="universal-signed\.apk$|rustdesk-android.apk"
)

# Eski dosyaları temizle (anahtar değiştiyse eski adlı dosya kalmasın)
find "$INDIR_DIZINI" -maxdepth 1 -type f \( -name 'rustdesk-*' \) -delete

# 4) İndir ve yeniden adlandır
declare -A SONUC
for platform in "${!HEDEFLER[@]}"; do
    KALIP="${HEDEFLER[$platform]%%|*}"
    HEDEF_AD="${HEDEFLER[$platform]##*|}"
    URL="$(grep -E "$KALIP" <<<"$VARLIKLAR" | head -n1 || true)"
    if [[ -z "$URL" ]]; then
        uyari "$platform: sürüm $SURUM içinde uygun dosya yok ($KALIP)."
        SONUC[$platform]=""
        continue
    fi
    bilgi "$platform indiriliyor: $(basename "$URL")"
    if curl -fL -m 600 --retry 3 -# -o "$INDIR_DIZINI/$HEDEF_AD" "$URL"; then
        SONUC[$platform]="$HEDEF_AD"
    else
        uyari "$platform indirilemedi."
        SONUC[$platform]=""
        rm -f "$INDIR_DIZINI/$HEDEF_AD"
    fi
done

# 5) Sayfa ayar dosyası (index.html bu değişkenleri okur)
#    Mobil QR içeriği: RustDesk uygulaması "Sunucu ayarları > QR tara" ile bu JSON'u kabul eder.
cat > "$SITE_DIZINI/ayar.js" <<EOF
// Bu dosya scripts/istemci-hazirla.sh tarafından üretilir, elle düzenlemeyin.
window.RUSTDESK_AYAR = {
  sunucu: "${ALAN_ADI}",
  anahtar: "${ANAHTAR}",
  surum: "${SURUM}",
  guncelleme: "$(date '+%d.%m.%Y')",
  dosyalar: {
    windows: "${SONUC[windows]}",
    macos_intel: "${SONUC[macos_intel]}",
    macos_apple: "${SONUC[macos_apple]}",
    linux_deb: "${SONUC[linux_deb]}",
    linux_appimage: "${SONUC[linux_appimage]}",
    android: "${SONUC[android]}"
  }
};
EOF

# Web sunucusunun okuyabilmesi için izinler
chmod 755 "$INDIR_DIZINI"
chmod 644 "$INDIR_DIZINI"/* "$SITE_DIZINI/ayar.js" 2>/dev/null || true

echo
basari "İstemciler hazır: $INDIR_DIZINI"
ls -1 "$INDIR_DIZINI"
echo
bilgi "Sayfa: https://${ALAN_ADI}/"
