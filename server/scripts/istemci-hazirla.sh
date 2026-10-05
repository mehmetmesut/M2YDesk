#!/usr/bin/env bash
# M2YDesk istemcilerini GitHub Release'den indirip indirme sayfasına koyar.
#
# İstemciler derleme zamanında sunucu adresi + anahtarla üretildiğinden (res/m2y/*.json)
# burada yeniden adlandırma/yapılandırma yapılmaz; dosyalar olduğu gibi sunulur.
#
# Kullanım:
#   sudo bash scripts/istemci-hazirla.sh                     # en son release
#   M2Y_SURUM=1.4.9 sudo bash scripts/istemci-hazirla.sh      # belirli etiket
#   M2Y_ASGARI_SURUM=1.0.0 sudo bash scripts/istemci-hazirla.sh # zorunlu asgari sürüm (varsayılan: yayınlanan sürüm)
#   SITE_DIZINI=/var/www/vhosts/mehmetmesut.com/desk.mehmetmesut.com sudo bash scripts/istemci-hazirla.sh
#   GITHUB_TOKEN=ghp_... (depo ÖZEL ise zorunlu; herkese açık depoda gerekmez)
#
# Çıktı: $SITE_DIZINI/indir/, $SITE_DIZINI/ayar.js ve $SITE_DIZINI/guncelleme/surum.json
#         (istemcilerin güncelleme denetimi; dosya adresi + SHA-256 içerir)
#         surum.json/engel.json İMZASIZ üretilir; .sig dosyaları kullanıcı bilgisayarında
#         scripts/imzala.py ile üretilip ayrıca yüklenir (docs/guncelleme.md "İmza").

set -euo pipefail

PROJE_DIZINI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJE_DIZINI"

bilgi()  { echo -e "\e[34m[BİLGİ]\e[0m $*"; }
basari() { echo -e "\e[32m[TAMAM]\e[0m $*"; }
uyari()  { echo -e "\e[33m[UYARI]\e[0m $*"; }
hata()   { echo -e "\e[31m[HATA]\e[0m $*" >&2; exit 1; }

DEPO="${M2Y_DEPO:-mehmetmesut/M2YDesk}"
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

# 2) GitHub API başlıkları (özel depo için token). Ortamda yoksa .env.github (600) dosyasından okunur;
#    dosyayı kullanıcı scripts/github-belirtec-kaydet.sh ile kendisi oluşturur (belirteç ekrana yazılmaz).
if [[ -z "${GITHUB_TOKEN:-}" && -r .env.github ]]; then
    GITHUB_TOKEN="$(grep -E '^GITHUB_TOKEN=' .env.github | cut -d= -f2-)"
fi
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
    # Dikkat: BASLIK'taki "Accept: vnd.github+json" burada KULLANILMAZ; iki Accept olunca GitHub
    # dosya yerine JSON meta veri döndürüyordu (05.10.2026 hatası). Yalnızca octet-stream + yetki.
    INDIR_BASLIK=(-H "Accept: application/octet-stream")
    [[ -n "${GITHUB_TOKEN:-}" ]] && INDIR_BASLIK+=(-H "Authorization: Bearer $GITHUB_TOKEN")
    if curl -fL -m 900 --retry 3 -# "${INDIR_BASLIK[@]}" -o "$INDIR_DIZINI/$AD.indiriliyor" "$URL" \
        && ! head -c 1 "$INDIR_DIZINI/$AD.indiriliyor" | grep -q '{'; then
        mv -f "$INDIR_DIZINI/$AD.indiriliyor" "$INDIR_DIZINI/$AD"
        SONUC[$platform]="$AD"
    else
        rm -f "$INDIR_DIZINI/$AD.indiriliyor"
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

# 7) İstemci güncelleme bildirimi: guncelleme/surum.json (istemciler GET ile okur, SHA-256 doğrular)
GUNCELLEME_DIZINI="$SITE_DIZINI/guncelleme"
mkdir -p "$GUNCELLEME_DIZINI"
SURUM_SAYI="${SURUM#v}"
# Zorunlu güncelleme: bu sürümden eski istemciler güncellemeden bağlanamaz (docs/guncelleme.md).
ASGARI="${M2Y_ASGARI_SURUM:-$SURUM_SAYI}"
ASGARI="${ASGARI#v}"
if [[ "$SURUM_SAYI" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    [[ "$ASGARI" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || hata "M2Y_ASGARI_SURUM x.y.z biçiminde olmalı: '$ASGARI'"
    ALAN="$ALAN_ADI" SURUM_SAYI="$SURUM_SAYI" ASGARI="$ASGARI" INDIR="$INDIR_DIZINI" \
    HEDEF="$GUNCELLEME_DIZINI/surum.json" \
    SONUC_JSON="$(for p in "${!SONUC[@]}"; do printf '%s\t%s\n' "$p" "${SONUC[$p]}"; done)" \
    python3 - <<'PY'
import hashlib, json, os, datetime
alan, indir = os.environ["ALAN"], os.environ["INDIR"]
dosyalar = {}
for satir in os.environ["SONUC_JSON"].splitlines():
    platform, _, ad = satir.partition("\t")
    yol = os.path.join(indir, ad)
    if not ad or not os.path.isfile(yol):
        continue
    h = hashlib.sha256()
    with open(yol, "rb") as f:
        for blok in iter(lambda: f.read(1 << 20), b""):
            h.update(blok)
    dosyalar[platform] = {"url": f"https://{alan}/indir/{ad}", "sha256": h.hexdigest()}
veri = {"version": os.environ["SURUM_SAYI"],
        "tarih": datetime.date.today().isoformat(),
        "asgari_surum": os.environ["ASGARI"],
        "dosyalar": dosyalar}
gecici = os.environ["HEDEF"] + ".tmp"
with open(gecici, "w", encoding="utf-8") as f:
    json.dump(veri, f, ensure_ascii=False, indent=2)
os.replace(gecici, os.environ["HEDEF"])
PY
    basari "guncelleme/surum.json yazıldı (sürüm $SURUM_SAYI, asgari $ASGARI)"
else
    uyari "Etiket '$SURUM' x.y.z biçiminde değil; surum.json güncellenmedi (istemciler eski bildirimi görür)."
fi
# Engel listesi yoksa boş oluştur (SHA-256 özetleri: id / uuid / mac)
[[ -f "$GUNCELLEME_DIZINI/engel.json" ]] || echo '{"id":[],"uuid":[],"mac":[]}' > "$GUNCELLEME_DIZINI/engel.json"
# İmza: istemciler .sig olmadan (veya eski .sig ile) dosyayı REDDEDER. İmzalama sunucuda YAPILMAZ:
# dosyayı kendi bilgisayarınıza alın, scripts/imzala.py ile imzalayıp .sig'i buraya yükleyin (docs/guncelleme.md "İmza").
for f in surum.json engel.json; do
    if [[ ! -f "$GUNCELLEME_DIZINI/$f.sig" ]]; then
        uyari "guncelleme/$f.sig yok — imzalanmadan yayınlama: istemciler reddeder (güncelleme/engel listesi çalışmaz)."
    elif [[ "$GUNCELLEME_DIZINI/$f" -nt "$GUNCELLEME_DIZINI/$f.sig" ]]; then
        uyari "guncelleme/$f.sig, $f dosyasından eski — yeniden imzalayın; aksi hâlde istemciler reddeder."
    fi
done

chmod 755 "$INDIR_DIZINI" "$GUNCELLEME_DIZINI"
chmod 644 "$INDIR_DIZINI"/* "$SITE_DIZINI/ayar.js" "$GUNCELLEME_DIZINI"/*.json "$GUNCELLEME_DIZINI"/*.sig 2>/dev/null || true
# Plesk: üretilen dosyalar sitenin diğer dosyalarıyla aynı sahipte olsun (Dosya Yöneticisi'nden düzenlenebilsin)
if [[ -f "$SITE_DIZINI/index.html" ]]; then
    chown -R --reference="$SITE_DIZINI/index.html" "$INDIR_DIZINI" "$GUNCELLEME_DIZINI" "$SITE_DIZINI/ayar.js" 2>/dev/null || true
fi

echo
basari "İstemciler hazır: $INDIR_DIZINI"
ls -1 "$INDIR_DIZINI"
bilgi "Sayfa: https://${ALAN_ADI}/"
