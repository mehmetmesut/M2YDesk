#!/usr/bin/env bash
# RustDesk yedeğini geri yükler (sunucu taşıma veya felaket kurtarma)
# Kullanım: sudo bash scripts/geri-yukleme.sh yedekler/rustdesk-yedek-20260928-031500.tar.gz

set -euo pipefail

PROJE_DIZINI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERI_DIZINI="$PROJE_DIZINI/data"
YEDEK="${1:-}"

hata() { echo "[HATA] $*" >&2; exit 1; }

[[ -n "$YEDEK" && -f "$YEDEK" ]] || hata "Kullanım: $0 <yedek.tar.gz>"
[[ $EUID -eq 0 ]] || hata "Root olarak çalıştırın."

# Mevcut anahtarın üzerine yazmadan önce onay iste
if [[ -f "$VERI_DIZINI/id_ed25519" ]]; then
    read -r -p "Mevcut anahtar ve veritabanı silinecek. Devam? [e/H] " CEVAP
    [[ "$CEVAP" =~ ^[eE]$ ]] || { echo "İptal edildi."; exit 0; }
fi

cd "$PROJE_DIZINI"
docker compose down >/dev/null 2>&1 || true

mkdir -p "$VERI_DIZINI"
tar -xzf "$YEDEK" -C "$VERI_DIZINI"
chmod 700 "$VERI_DIZINI"
chmod 600 "$VERI_DIZINI/id_ed25519"

docker compose up -d
echo "[TAMAM] Geri yükleme tamamlandı. Anahtar: $(cat "$VERI_DIZINI/id_ed25519.pub")"
