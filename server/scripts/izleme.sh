#!/usr/bin/env bash
# M2YDesk sunucu izleme ve alarm betiği.
# systemd zamanlayıcısı (izleme-kur.sh) her 5 dakikada bir çalıştırır.
# Yalnızca durum DEĞİŞİNCE bildirim gönderir (DÜŞTÜ / DÜZELDİ).
# Test: IZLEME_TEST=1 bash izleme.sh  (sahte alarm; gerçek durum dosyasına dokunmaz)
set -euo pipefail

# ---- Ayarlar (ortam değişkeniyle geçersiz kılınabilir) ----
PROJE_DIZINI="${PROJE_DIZINI:-/opt/m2ydesk/server}"
SMTP_DOSYASI="${SMTP_DOSYASI:-$PROJE_DIZINI/.env.smtp}"
IZLEME_ENV="${IZLEME_ENV:-$PROJE_DIZINI/.env.izleme}"
DURUM_DIZINI="${DURUM_DIZINI:-/var/lib/m2y-izleme}"
DURUM_DOSYASI="$DURUM_DIZINI/durum"
LOG_DOSYASI="${LOG_DOSYASI:-/var/log/m2y-izleme.log}"
SITE_URL="${SITE_URL:-https://desk.mehmetmesut.com/}"
SSL_ALAN_ADI="${SSL_ALAN_ADI:-desk.mehmetmesut.com}"
SSL_ESIK_GUN=14
DISK_ESIK_YUZDE=85
VERI_DIZINI="${VERI_DIZINI:-$PROJE_DIZINI/data}"
SUNUCU_ADI="$(hostname 2>/dev/null || echo sunucu)"

# ---- Yardımcılar ----
log() { # sır içermeyen satırları günlüğe yazar
  local satir
  satir="$(date '+%F %T') $*"
  { printf '%s\n' "$satir" >>"$LOG_DOSYASI"; } 2>/dev/null || printf '%s\n' "$satir" >&2
}

env_oku() { # env_oku DOSYA ANAHTAR -> değer (dosya çalıştırılmaz, yalnızca ayrıştırılır)
  local dosya="$1" anahtar="$2" deger
  [ -r "$dosya" ] || return 0
  deger="$(grep -E "^${anahtar}=" "$dosya" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
  deger="${deger%$'\r'}"; deger="${deger%\"}"; deger="${deger#\"}"
  deger="${deger%\'}"; deger="${deger#\'}"
  printf '%s' "$deger"
}

IZLEME_EPOSTA="${IZLEME_EPOSTA:-$(env_oku "$IZLEME_ENV" IZLEME_EPOSTA)}"
IZLEME_EPOSTA="${IZLEME_EPOSTA:-mehmetmesut@gmail.com}"
NTFY_URL="$(env_oku "$IZLEME_ENV" NTFY_URL)"
NTFY_URL="${NTFY_URL:-https://ntfy.sh}"
NTFY_KONU="$(env_oku "$IZLEME_ENV" NTFY_KONU)"

# ---- Bildirim kanalları ----
# E-posta gönderen Python kodu (parola yalnızca burada dosyadan okunur; yazdırılmaz).
EPOSTA_PY='
import os, smtplib, ssl
from email.message import EmailMessage

ayar = {}
with open(os.environ["SMTP_DOSYASI"], encoding="utf-8") as f:
    for satir in f:
        satir = satir.strip()
        if not satir or satir.startswith("#") or "=" not in satir:
            continue
        k, v = satir.split("=", 1)
        ayar[k.strip()] = v.strip().strip("\"").strip("\x27")

host = ayar.get("SMTP_HOST", "localhost")
port = int(ayar.get("SMTP_PORT", "587"))
kullanici = ayar.get("SMTP_USER", "")
parola = ayar.get("SMTP_PASS", "")
gonderen = ayar.get("SMTP_FROM") or kullanici or "izleme@localhost"

msg = EmailMessage()
msg["From"] = gonderen
msg["To"] = os.environ["EPOSTA_ALICI"]
msg["Subject"] = os.environ["EPOSTA_KONU"]
msg.set_content(os.environ["EPOSTA_GOVDE"])

# localhost a bağlanıldığı için sertifika doğrulaması kapalı (ana makine adı uyuşmaz).
baglam = ssl.create_default_context()
if host in ("localhost", "127.0.0.1", "::1"):
    baglam.check_hostname = False
    baglam.verify_mode = ssl.CERT_NONE

try:
    with smtplib.SMTP(host, port, timeout=30) as s:
        s.ehlo()
        s.starttls(context=baglam)
        s.ehlo()
        if kullanici and parola:
            s.login(kullanici, parola)
        s.send_message(msg)
except Exception as e:  # parolayı içermeyen yalnızca hata türü yazılır
    print(type(e).__name__)
    raise SystemExit(1)
'

bildir_eposta() { # bildir_eposta KONU GOVDE
  command -v python3 >/dev/null 2>&1 || { log "e-posta atlandı: python3 yok"; return 0; }
  [ -r "$SMTP_DOSYASI" ] || { log "e-posta atlandı: SMTP dosyası okunamıyor"; return 0; }
  local cikti
  if ! cikti="$(SMTP_DOSYASI="$SMTP_DOSYASI" EPOSTA_ALICI="$IZLEME_EPOSTA" \
      EPOSTA_KONU="$1" EPOSTA_GOVDE="$2" python3 -c "$EPOSTA_PY" 2>&1)"; then
    log "e-posta gönderilemedi: ${cikti:-bilinmeyen hata}"
  fi
  return 0
}

bildir_ntfy() { # bildir_ntfy BASLIK GOVDE ONCELIK
  [ -n "$NTFY_KONU" ] || return 0   # konu yoksa ntfy atlanır
  command -v curl >/dev/null 2>&1 || { log "ntfy atlandı: curl yok"; return 0; }
  local baslik_b64 kod=0
  # Türkçe karakterler için RFC 2047 kodlu başlık
  baslik_b64="=?UTF-8?B?$(printf '%s' "$1" | base64 | tr -d '\n')?="
  curl -sS -m 15 -o /dev/null --fail \
    -H "Title: $baslik_b64" -H "Priority: $3" \
    -d "$2" "${NTFY_URL%/}/$NTFY_KONU" 2>/dev/null || kod=$?
  [ "$kod" -eq 0 ] || log "ntfy gönderilemedi (curl çıkış kodu $kod)"
  return 0
}

bildir() { # bildir TUR(DUSTU|DUZELDI) KONTROL MESAJ
  local tur="$1" kontrol="$2" mesaj="$3" etiket oncelik baslik govde
  if [ "$tur" = "DUSTU" ]; then etiket="DÜŞTÜ"; oncelik="urgent"; else etiket="DÜZELDİ"; oncelik="default"; fi
  baslik="[M2YDesk] $etiket: $kontrol"
  govde="$etiket: $kontrol
$mesaj
Sunucu: $SUNUCU_ADI
Zaman: $(date '+%F %T %Z')"
  log "$etiket $kontrol - $mesaj"
  bildir_eposta "$baslik" "$govde"
  bildir_ntfy "$baslik" "$govde" "$oncelik"
}

# ---- Test kipi: sahte alarm, gerçek durum dosyasına dokunmaz ----
if [ "${IZLEME_TEST:-0}" = "1" ]; then
  echo "Test kipi: sahte DÜŞTÜ ve DÜZELDİ bildirimleri gönderiliyor..."
  bildir DUSTU "test" "Bu bir deneme alarmıdır (IZLEME_TEST=1). Gerçek bir sorun yoktur."
  bildir DUZELDI "test" "Deneme alarmı sona erdi."
  echo "Bitti. E-posta kutusunu ve ntfy uygulamasını kontrol edin; hata varsa: $LOG_DOSYASI"
  exit 0
fi

# ---- Eşzamanlı çalışmayı engelle ----
mkdir -p "$DURUM_DIZINI"
exec 9>"$DURUM_DIZINI/kilit"
flock -n 9 || { log "önceki çalışma sürüyor, atlandı"; exit 0; }

# ---- Önceki durumu yükle ----
declare -A ONCEKI=() YENI=()
if [ -r "$DURUM_DOSYASI" ]; then
  while IFS='=' read -r anahtar deger; do
    if [ -n "$anahtar" ]; then ONCEKI["$anahtar"]="$deger"; fi
  done <"$DURUM_DOSYASI"
fi
BUGUN="$(date +%F)"

# kaydet KONTROL OK|FAIL MESAJ -> durum değişimini işler
kaydet() {
  local kontrol="$1" durum="$2" mesaj="$3" onceki="${ONCEKI[$1]:-}"
  YENI["$kontrol"]="$durum"
  if [ "$durum" = "FAIL" ] && [ "$onceki" != "FAIL" ]; then
    bildir DUSTU "$kontrol" "$mesaj"
    if [ "$kontrol" = "ssl" ]; then YENI["ssl_uyari_gun"]="$BUGUN"; fi
  elif [ "$durum" = "OK" ] && [ "$onceki" = "FAIL" ]; then
    bildir DUZELDI "$kontrol" "$mesaj"
  elif [ "$kontrol" = "ssl" ] && [ "$durum" = "FAIL" ] \
       && [ "${ONCEKI[ssl_uyari_gun]:-}" != "$BUGUN" ]; then
    # SSL süresi yaklaşıyor: sürerken günde en fazla bir kez hatırlat
    bildir DUSTU "$kontrol" "$mesaj (günlük hatırlatma)"
    YENI["ssl_uyari_gun"]="$BUGUN"
  fi
  return 0
}

tcp_acik() { # tcp_acik PORT (5 sn zaman aşımı)
  timeout 5 bash -c "exec 3<>/dev/tcp/127.0.0.1/$1" 2>/dev/null
}

kapsayici_var_mi() { # kapsayici_var_mi AD -> 0 ise var
  [ -n "$(docker ps -a --filter "name=^${1}\$" --format '{{.Names}}' 2>/dev/null || true)" ]
}

# ---- (a) Docker kapsayıcıları ----
kapsayici_denetle() { # kapsayici_denetle AD ZORUNLU(1|0)
  local ad="$1" zorunlu="$2" calisiyor
  if ! command -v docker >/dev/null 2>&1; then
    kaydet "kapsayici_$ad" FAIL "docker komutu bulunamadı"; return 0
  fi
  if ! kapsayici_var_mi "$ad"; then
    # isteğe bağlı kapsayıcı yoksa denetlenmez
    if [ "$zorunlu" = "1" ]; then kaydet "kapsayici_$ad" FAIL "kapsayıcı yok"; fi
    return 0
  fi
  calisiyor="$(docker inspect -f '{{.State.Running}}' "$ad" 2>/dev/null || echo false)"
  if [ "$calisiyor" = "true" ]; then kaydet "kapsayici_$ad" OK "çalışıyor"
  else kaydet "kapsayici_$ad" FAIL "kapsayıcı çalışmıyor"; fi
}
kapsayici_denetle hbbs 1
kapsayici_denetle hbbr 1
kapsayici_denetle m2y-api 0

# ---- (b) TCP bağlantı denetimi ----
for port in 21116 21117; do
  if tcp_acik "$port"; then kaydet "tcp_$port" OK "bağlantı kabul ediyor"
  else kaydet "tcp_$port" FAIL "127.0.0.1:$port bağlantı kabul etmiyor"; fi
done
if command -v docker >/dev/null 2>&1 && kapsayici_var_mi m2y-api; then
  if tcp_acik 21114; then kaydet "tcp_21114" OK "bağlantı kabul ediyor"
  else kaydet "tcp_21114" FAIL "127.0.0.1:21114 bağlantı kabul etmiyor"; fi
fi

# ---- (c) Site HTTP 200 ----
kod="$(curl -sS -m 15 -o /dev/null -w '%{http_code}' "$SITE_URL" 2>/dev/null || true)"
if [ "$kod" = "200" ]; then kaydet "site" OK "HTTP 200"
else kaydet "site" FAIL "$SITE_URL HTTP ${kod:-000} döndü (200 bekleniyordu)"; fi

# ---- (d) SSL sertifikası bitiş tarihi ----
bitis="$( { echo | timeout 20 openssl s_client -servername "$SSL_ALAN_ADI" \
              -connect "$SSL_ALAN_ADI:443" 2>/dev/null \
            | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2; } || true)"
if [ -z "$bitis" ]; then
  kaydet "ssl" FAIL "sertifika okunamadı ($SSL_ALAN_ADI:443)"
else
  bitis_sn="$(date -d "$bitis" +%s 2>/dev/null || echo 0)"
  if [ "$bitis_sn" -eq 0 ]; then
    kaydet "ssl" FAIL "bitiş tarihi çözümlenemedi"
  else
    kalan_gun=$(( (bitis_sn - $(date +%s)) / 86400 ))
    if [ "$kalan_gun" -lt "$SSL_ESIK_GUN" ]; then
      kaydet "ssl" FAIL "SSL sertifikasının bitişine $kalan_gun gün kaldı (eşik $SSL_ESIK_GUN)"
    else
      kaydet "ssl" OK "SSL sertifikası $kalan_gun gün geçerli"
    fi
  fi
fi

# ---- (e) Disk kullanımı ----
yuzde="$( { df --output=pcent / 2>/dev/null | tail -n1 | tr -dc '0-9'; } || true)"
if [ -z "$yuzde" ]; then kaydet "disk" FAIL "disk kullanımı okunamadı"
elif [ "$yuzde" -gt "$DISK_ESIK_YUZDE" ]; then
  kaydet "disk" FAIL "/ bölümü %$yuzde dolu (eşik %$DISK_ESIK_YUZDE)"
else kaydet "disk" OK "/ bölümü %$yuzde dolu"; fi

# ---- (f) Veri dizini izinleri ----
if [ ! -d "$VERI_DIZINI" ]; then
  kaydet "veri_izin" FAIL "$VERI_DIZINI dizini yok"
else
  izin="$(stat -c %a "$VERI_DIZINI" 2>/dev/null || echo ?)"
  if [ "$izin" = "700" ]; then kaydet "veri_izin" OK "izin 700"
  else kaydet "veri_izin" FAIL "$VERI_DIZINI izni $izin (700 olmalı)"; fi
fi

# ---- Durumu atomik olarak yaz ----
gecici="$(mktemp "$DURUM_DIZINI/durum.XXXXXX")"
for anahtar in "${!YENI[@]}"; do printf '%s=%s\n' "$anahtar" "${YENI[$anahtar]}"; done | sort >"$gecici"
# Bu turda üretilmeyen ssl_uyari_gun değeri korunur
if [ -z "${YENI[ssl_uyari_gun]:-}" ] && [ -n "${ONCEKI[ssl_uyari_gun]:-}" ]; then
  printf 'ssl_uyari_gun=%s\n' "${ONCEKI[ssl_uyari_gun]}" >>"$gecici"
fi
chmod 600 "$gecici"
mv -f "$gecici" "$DURUM_DOSYASI"
