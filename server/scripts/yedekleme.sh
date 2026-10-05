#!/usr/bin/env bash
# RustDesk sunucu yedekleme betiği
# Anahtar çifti (id_ed25519*) ve SQLite veritabanını (db_v2.sqlite3) sıkıştırıp yedekler.
#
# Kullanım:
#   sudo bash scripts/yedekleme.sh                 # Varsayılan: /opt/rustdesk/yedekler
#   sudo bash scripts/yedekleme.sh /mnt/yedek      # Farklı hedef klasör
#
# Cron (her gece 03:15, 30 gün sakla):
#   15 3 * * * /opt/rustdesk/scripts/yedekleme.sh >> /var/log/rustdesk-yedek.log 2>&1

set -euo pipefail

PROJE_DIZINI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERI_DIZINI="$PROJE_DIZINI/data"
HEDEF_DIZINI="${1:-$PROJE_DIZINI/yedekler}"
SAKLAMA_GUNU="${SAKLAMA_GUNU:-30}"   # Ortam değişkeniyle değiştirilebilir

bilgi()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BİLGİ] $*"; }
hata()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HATA] $*" >&2; exit 1; }

# Yedeklenecek dosyalar mevcut mu?
[[ -f "$VERI_DIZINI/id_ed25519" ]] || hata "Özel anahtar bulunamadı: $VERI_DIZINI/id_ed25519"

# Hedef klasörü yalnızca root okuyabilsin (özel anahtar içerir)
mkdir -p "$HEDEF_DIZINI"
chmod 700 "$HEDEF_DIZINI"

ZAMAN="$(date '+%Y%m%d-%H%M%S')"
DOSYA="$HEDEF_DIZINI/rustdesk-yedek-$ZAMAN.tar.gz"

# SQLite dosyası yazılırken kopyalamamak için hbbs kısa süre durdurulur
# (Kesinti birkaç saniyedir; aktif bağlantılar relay üzerinden devam eder)
COMPOSE=""
if docker compose version >/dev/null 2>&1; then COMPOSE="docker compose"; fi
if [[ -n "$COMPOSE" ]] && (cd "$PROJE_DIZINI" && $COMPOSE ps --status running 2>/dev/null | grep -q hbbs); then
    bilgi "hbbs geçici olarak durduruluyor..."
    (cd "$PROJE_DIZINI" && $COMPOSE stop hbbs >/dev/null)
    # Betik hata ile bitse bile hbbs'i yeniden başlat
    trap '(cd "$PROJE_DIZINI" && $COMPOSE start hbbs >/dev/null) && bilgi "hbbs yeniden başlatıldı."' EXIT
fi

# Anahtarlar + veritabanı (varsa) sıkıştırılır
# Hesap API'si (kullanıcılar, adres defteri, günlükler; SQLite) tutarlı kopya için kısa süre durdurulur
if [[ -n "$COMPOSE" ]] && docker ps --format '{{.Names}}' | grep -qx m2y-api; then
    bilgi "m2y-api geçici olarak durduruluyor..."
    docker stop m2y-api >/dev/null
    trap '(cd "$PROJE_DIZINI" && $COMPOSE start hbbs >/dev/null 2>&1); docker start m2y-api >/dev/null 2>&1; bilgi "Hizmetler yeniden başlatıldı."' EXIT
fi

# data/ (anahtarlar, hbbs ve API veritabanları) + yapılandırma dosyaları (.env*, compose). Sırlar içerir → 600.
tar -czf "$DOSYA" -C "$PROJE_DIZINI" \
    $(cd "$PROJE_DIZINI" && ls -d data/id_ed25519 data/id_ed25519.pub data/db_v2.sqlite3 data/db_v2.sqlite3-wal \
        data/db_v2.sqlite3-shm data/api .env .env.smtp .env.izleme .env.github .env.m2yapi docker-compose.yml 2>/dev/null)
chmod 600 "$DOSYA"
bilgi "Yedek oluşturuldu: $DOSYA ($(du -h "$DOSYA" | cut -f1))"

# Eski yedekleri temizle
SILINEN=$(find "$HEDEF_DIZINI" -name 'rustdesk-yedek-*.tar.gz' -mtime +"$SAKLAMA_GUNU" -print -delete | wc -l)
[[ "$SILINEN" -gt 0 ]] && bilgi "$SILINEN eski yedek silindi (> $SAKLAMA_GUNU gün)."

exit 0
