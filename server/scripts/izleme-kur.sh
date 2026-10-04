#!/usr/bin/env bash
# M2YDesk izleme zamanlayıcısını (systemd service + timer) kurar veya kaldırır.
# Kullanım:  sudo bash izleme-kur.sh          (kur)
#            sudo bash izleme-kur.sh kaldir   (kaldır)
set -euo pipefail

BETIK_DIZINI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJE_DIZINI="$(dirname "$BETIK_DIZINI")"
IZLEME_SH="$BETIK_DIZINI/izleme.sh"
ENV_DOSYASI="$PROJE_DIZINI/.env.izleme"
DURUM_DIZINI=/var/lib/m2y-izleme
SERVIS=/etc/systemd/system/m2y-izleme.service
ZAMANLAYICI=/etc/systemd/system/m2y-izleme.timer

if [ "$(id -u)" -ne 0 ]; then
  echo "Hata: root olarak çalıştırın (sudo)." >&2
  exit 1
fi

if [ "${1:-}" = "kaldir" ]; then
  systemctl disable --now m2y-izleme.timer 2>/dev/null || true
  rm -f "$SERVIS" "$ZAMANLAYICI"
  systemctl daemon-reload
  echo "İzleme zamanlayıcısı kaldırıldı."
  echo "Not: $ENV_DOSYASI ve $DURUM_DIZINI silinmedi (isterseniz elle silin)."
  exit 0
fi

if [ ! -f "$IZLEME_SH" ]; then
  echo "Hata: $IZLEME_SH bulunamadı." >&2
  exit 1
fi

mkdir -p "$DURUM_DIZINI"
chmod 700 "$DURUM_DIZINI"

cat >"$SERVIS" <<UNIT
[Unit]
Description=M2YDesk sunucu izleme kontrolü
After=docker.service network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash $IZLEME_SH
Nice=10
UNIT

cat >"$ZAMANLAYICI" <<UNIT
[Unit]
Description=M2YDesk izleme kontrolü (her 5 dakikada bir)

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=30s

[Install]
WantedBy=timers.target
UNIT

YENI_KONU=""
if [ ! -e "$ENV_DOSYASI" ]; then
  # 24 karakterlik rastgele, tahmin edilemez konu adı
  YENI_KONU="m2y-$(openssl rand -hex 12)"
  ( umask 077; printf 'NTFY_URL=https://ntfy.sh\nNTFY_KONU=%s\n' "$YENI_KONU" >"$ENV_DOSYASI" )
fi
chmod 600 "$ENV_DOSYASI"

systemctl daemon-reload
systemctl enable --now m2y-izleme.timer

echo "İzleme zamanlayıcısı kuruldu (her 5 dakikada bir; açılıştan 2 dk sonra ilk çalışma)."
echo "Durum: systemctl list-timers m2y-izleme.timer   Günlük: /var/log/m2y-izleme.log"
if [ -n "$YENI_KONU" ]; then
  echo
  echo "ntfy konu adınız (YALNIZCA BİR KEZ gösterilir; telefondaki ntfy uygulamasında abone olun):"
  echo "    $YENI_KONU"
  echo "Kaybederseniz $ENV_DOSYASI dosyasından okuyabilirsiniz."
fi
