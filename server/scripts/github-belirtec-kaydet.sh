#!/usr/bin/env bash
# Özel depodaki release dosyalarını sunucunun indirebilmesi için salt okunur GitHub belirtecini kaydeder.
# Belirteç EKRANA YAZILMAZ (read -s), yalnızca /opt/m2ydesk/server/.env.github (600) içine yazılır.
# Kullanım (kullanıcı kendisi, Plesk SSH Terminali):  bash /opt/m2ydesk/server/scripts/github-belirtec-kaydet.sh
#
# Belirteç oluşturma (GitHub → Settings → Developer settings → Fine-grained tokens → Generate new token):
#   Repository access: Only select repositories → mehmetmesut/M2YDesk
#   Permissions → Repository → Contents: Read-only   (başka izin VERMEYİN)
#   Expiration: 1 yıl (süre dolunca bu betiği yeniden çalıştırın)
set -euo pipefail
trap 'echo "[HATA] Betik satır $LINENO noktasında durdu." >&2' ERR

DOSYA="/opt/m2ydesk/server/.env.github"
DEPO="mehmetmesut/M2YDesk"

[[ $EUID -eq 0 ]] || { echo "root olarak çalıştırın"; exit 1; }

read -r -s -p "GitHub belirtecini yapıştırın (görünmez) ve Enter'a basın: " BELIRTEC
echo
[[ -n "$BELIRTEC" ]] || { echo "[HATA] Belirteç boş."; exit 1; }

# Doğrulama: depoya ve release listesine erişebiliyor mu? (belirteç günlüğe/ekrana yazılmaz)
KOD="$(curl -s -o /dev/null -w '%{http_code}' -m 20 \
    -H "Authorization: Bearer $BELIRTEC" -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$DEPO/releases?per_page=1")"
if [[ "$KOD" != "200" ]]; then
    echo "[HATA] Belirteç $DEPO release listesine erişemedi (HTTP $KOD). İzinleri kontrol edin: Contents → Read-only."
    exit 1
fi

umask 077
printf 'GITHUB_TOKEN=%s\n' "$BELIRTEC" >"$DOSYA"
chmod 600 "$DOSYA"
unset BELIRTEC
echo "[TAMAM] Belirteç doğrulandı ve kaydedildi: $DOSYA (izin 600, gösterilmedi)."
echo "        Artık: cd /opt/m2ydesk/server && M2Y_SURUM=v1.0.1 bash scripts/istemci-hazirla.sh"
