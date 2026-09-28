#!/usr/bin/env bash
# M2YDesk istemcilerini GitHub Release'den indirip indirme sayfasına koyar.
#
# İstemciler derleme zamanında sunucu adresi + anahtarla üretildiğinden (res/m2y/*.json)
# burada yeniden adlandırma/yapılandırma yapılmaz; dosyalar olduğu gibi sunulur.
#
# Kullanım:
#   sudo bash scripts/istemci-hazirla.sh                     # en son release
#   M2Y_SURUM=1.4.9 sudo bash scripts/istemci-hazirla.sh      # belirli etiket
#   SITE_DIZINI=/var/www/vhosts/mehmetmesut.com/rustdesk.mehmetmesut.com sudo bash scripts/istemci-hazirla.sh
#   GITHUB_TOKEN=ghp_... (depo ÖZEL ise zorunlu; herkese açık depoda gerekmez)
#
# Çıktı: $SITE_DIZINI/indir/  ve  $SITE_DIZINI/ayar.js

set -euo pipefail

PROJE_DIZINI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJE_DIZINI"

bilgi()  { echo -e "\e[34m[BİLGİ]\e[0m $*"; }
basari() { echo -e "\e[32m[TAMAM]\e[0m $*"; }
uyari()  { echo -e "\e[33m[UYARI]\e[0m $*"; }
hata()   { echo -e "\e[31m[HATA]\e[0m $*" >&2; exit 1; }

DEPO="${M2Y_DEPO:-mehmetmesut/RustDesk}"
API="https://api.github.com/repos/$DEPO/releases"

# 1) Sunucu ayarları ve AÇIK anahtar (mobil QR ve elle giriş için)
[[ -f .env ]] || hata ".env bulunamadı. Önce scripts/kurulum.sh çalıştırın."
# shellcheck disable=SC1091
source .env
[[ -s data/id_ed25519.pub ]] || hata "Açık anahtar yok: data/id_ed25519.pub (sunucu çalışıyor mu?)"
ANAHTAR="$(tr -d '\r\n' < data/id_ed25519.pub)"

SITE_DIZINI="${SITE_DIZINI:-$PROJE_DIZINI/site/httpdocs}"
INDIR_DIZINI="$SITE_DIZINI/indir"
mkdir -p "$INDIR_DIZINI"

# 2) GitHub API başlıkları (özel depo için token)
BASLIK=(-H "Accept: application/vnd.github+json")
[[ -n "${GITHUB_TOKEN:-}" ]] && BASLIK+=(-H "Authorization: Bearer $GITHUB_TOKEN")

# 3) Release bilgisini al
if [[ -n "${M2Y_SURUM:-}" ]]; then
    RELEASE_JSON="$(curl -fsSL -m 30 "${BASLIK[@]}" "$API/tags/$M2Y_SURUM")" || hata "Release bulunamadı: $M2Y_SURUM"
else
    # Ön sürümler (prerelease) dahil en yeni release
    RELEASE_JSON="$(curl -fsSL -m 30 "${BASLIK[@]}" "$API?per_page=1")" || hata "Release listesi alınamadı ($DEPO). Depo özelse GITHUB_TOKEN verin."
    RELEASE_JSON="$(python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d[0] if isinstance(d,list) and d else {}))' <<<"$RELEASE_JSON")"
fi
SURUM="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name",""))' <<<"$RELEASE_JSON")"
[[ -n "$SURUM" ]] || hata "Release etiketi okunamadı."
bilgi "Release: $SURUM"

# 4) Varlık listesi: ad<TAB>api_url (özel depoda browser_download_url token istemez ama API url güvenlidir)
VARLIKLAR="$(python3 -c '
import json,sys
for a in json.load(sys.stdin).get("assets",[]):
    print(a["name"]+"\t"+a["url"])' <<<"$RELEASE_JSON")"
[[ -n "$VARLIKLAR" ]] || hata "Release içinde dosya yok: $SURUM"

# platform -> dosya adı kalıbı (küçük harf, regex)
declare -A KALIPLAR=(
    [windows_qs]='^m2ydesk-qs-.*x86_64\.exe$'
    [windows]='^m2ydesk-[0-9].*x86_64\.exe$'
    [windows_install]='^m2ydesk-.*x86_64-install\.exe$'
    [windows_msi]='^m2ydesk-.*x86_64\.msi$'
    [macos_apple]='^m2ydesk-.*aarch64\.dmg$'
    [macos_intel]='^m2ydesk-.*x86_64\.dmg$'
    [linux_deb]='^m2ydesk-.*x86_64\.deb$'
    [android]='^m2ydesk-.*aarch64\.apk$'
)

# Eski dosyaları temizle
find "$INDIR_DIZINI" -maxdepth 1 -type f \( -iname 'm2ydesk*' -o -iname 'rustdesk*' \) -delete

# 5) İndir
declare -A SONUC
for platform in windows_qs windows windows_install windows_msi macos_apple macos_intel linux_deb android; do
    KALIP="${KALIPLAR[$platform]}"
    SATIR="$(while IFS=$'\t' read -r ad url; do
                 [[ "${ad,,}" =~ $KALIP ]] && { printf '%s\t%s\n' "$ad" "$url"; break; }
             done <<<"$VARLIKLAR" || true)"
    if [[ -z "$SATIR" ]]; then
        uyari "$platform: bu release'de yok."
        SONUC[$platform]=""; continue
    fi
    AD="${SATIR%%$'\t'*}"; URL="${SATIR#*$'\t'}"
    bilgi "$platform indiriliyor: $AD"
    if curl -fL -m 900 --retry 3 -# "${BASLIK[@]}" -H "Accept: application/octet-stream" -o "$INDIR_DIZINI/$AD" "$URL"; then
        SONUC[$platform]="$AD"
    else
        uyari "$platform indirilemedi."; SONUC[$platform]=""; rm -f "$INDIR_DIZINI/$AD"
    fi
done

# 6) Sayfa ayar dosyası
cat > "$SITE_DIZINI/ayar.js" <<EOF
// Bu dosya scripts/istemci-hazirla.sh tarafından üretilir, elle düzenlemeyin.
window.M2Y_AYAR = {
  sunucu: "${ALAN_ADI}",
  anahtar: "${ANAHTAR}",
  surum: "${SURUM}",
  guncelleme: "$(date '+%d.%m.%Y')",
  dosyalar: {
    windows_qs: "${SONUC[windows_qs]}",
    windows: "${SONUC[windows]}",
    windows_install: "${SONUC[windows_install]}",
    windows_msi: "${SONUC[windows_msi]}",
    macos_apple: "${SONUC[macos_apple]}",
    macos_intel: "${SONUC[macos_intel]}",
    linux_deb: "${SONUC[linux_deb]}",
    android: "${SONUC[android]}"
  }
};
EOF

chmod 755 "$INDIR_DIZINI"
chmod 644 "$INDIR_DIZINI"/* "$SITE_DIZINI/ayar.js" 2>/dev/null || true

echo
basari "İstemciler hazır: $INDIR_DIZINI"
ls -1 "$INDIR_DIZINI"
bilgi "Sayfa: https://${ALAN_ADI}/"
