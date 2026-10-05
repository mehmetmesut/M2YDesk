#!/usr/bin/env bash
# m2y-api (mehmetmesut/m2y-api fork) imajını sunucuda derler ve canlı API'yi günceller.
# Kaynak: /root/m2y-api-derleme (scp ile gelir). Kullanım: bash /opt/m2ydesk/server/scripts/m2y-api-guncelle.sh
# Sırlar burada RASTGELE üretilir ve ekrana YAZILMAZ: .env.m2yapi (600).
set -euo pipefail
trap 'echo "[HATA] satır $LINENO (çıkış $?)" >&2' ERR

KAYNAK=/root/m2y-api-derleme
SUNUCU=/opt/m2ydesk/server
ENVF="$SUNUCU/.env.m2yapi"
IMAJ="m2y-api:yerel"

[[ $EUID -eq 0 ]] || { echo "root gerekli"; exit 1; }
[[ -d "$KAYNAK" ]] || { echo "Kaynak yok: $KAYNAK"; exit 1; }
cd "$KAYNAK"

echo "[1/6] Go ikilisi derleniyor (golang:1.23, statik)"
rm -rf amd64 && mkdir -p amd64/release/data amd64/release/runtime
docker run --rm -v "$PWD":/src -w /src golang:1.23 sh -c '
  go mod tidy >/dev/null 2>&1 &&
  CGO_ENABLED=1 go build -tags "netgo osusergo" -ldflags "-s -w -extldflags -static" -o amd64/release/apimain ./cmd/apimain.go' 2>&1 | grep -vE "warning: Using .getaddrinfo|getpw|getgr" || true
[[ -x amd64/release/apimain ]] || { echo "[HATA] ikili üretilemedi"; exit 1; }
cp -r resources docs conf amd64/release/

echo "[2/6] Yönetim paneli arayüzü"
PANEL=/root/m2y-panel-dist   # mehmetmesut/m2y-panel (Türkçe) derlemesi; scp ile gelir
if [[ -f "$PANEL/index.html" ]]; then
    rm -rf amd64/release/resources/admin && cp -r "$PANEL" amd64/release/resources/admin
    echo "      Türkçe panel derlemesi kullanıldı ($PANEL)"
elif docker ps --format '{{.Names}}' | grep -qx m2y-api && docker exec m2y-api test -d /app/resources/admin; then
    docker cp m2y-api:/app/resources/admin amd64/release/resources/admin
elif docker image inspect "$IMAJ" >/dev/null 2>&1; then
    CID=$(docker create "$IMAJ"); docker cp "$CID":/app/resources/admin amd64/release/resources/admin; docker rm "$CID" >/dev/null
else
    echo "[HATA] panel arayüzü bulunamadı"; exit 1
fi

echo "[3/6] İmaj derleniyor: $IMAJ"
docker build -q --build-arg BUILDARCH=amd64 -t "$IMAJ" . >/dev/null

echo "[4/6] Gizli ayarlar ($ENVF)"
if [[ ! -f "$ENVF" ]]; then
    [[ -r "$SUNUCU/.env.smtp" ]] || { echo "[HATA] $SUNUCU/.env.smtp yok"; exit 1; }
    oku() { grep -E "^$1=" "$SUNUCU/.env.smtp" | cut -d= -f2-; }
    YETKI=$(openssl genpkey -algorithm ed25519 -outform DER | tail -c 32 | base64 -w0)
    umask 077
    {
        echo "M2Y_ADMIN_EMAILS=mehmetmesut@gmail.com,mehmetmesut.yilmaz@antalya.edu.tr"
        echo "M2Y_KOD_SIRRI=$(openssl rand -hex 32)"
        echo "RUSTDESK_API_JWT_KEY=$(openssl rand -hex 32)"
        echo "M2Y_YETKI_ANAHTARI=$YETKI"
        echo "M2Y_SMTP_HOST=127.0.0.1"
        echo "M2Y_SMTP_PORT=587"
        echo "M2Y_SMTP_USER=$(oku SMTP_USER)"
        echo "M2Y_SMTP_PASS=$(oku SMTP_PASS)"
        echo "M2Y_SMTP_FROM=$(oku SMTP_FROM)"
        echo "M2Y_SMTP_INSECURE=1"
    } >"$ENVF"
    chmod 600 "$ENVF"; unset YETKI
    echo "      oluşturuldu (değerler gösterilmedi)"
else
    echo "      mevcut, korunuyor"
fi

echo "[5/6] API veritabanı yedeği ve geçiş"
mkdir -p "$SUNUCU/yedekler"
cp -p "$SUNUCU/data/api/rustdeskapi.db" "$SUNUCU/yedekler/rustdeskapi-oncesi-$(date +%Y%m%d-%H%M%S).db"
cd "$SUNUCU" && docker compose --profile api up -d api >/dev/null 2>&1
sleep 6

echo "[6/6] Sağlık denetimi"
docker ps --format '{{.Names}} {{.Image}} {{.Status}}' | grep '^m2y-api'
for u in /api/login-options /api/m2y/yetki-acik-anahtar; do
    printf '      %-28s HTTP %s\n' "$u" "$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://127.0.0.1:21114$u")"
done
docker logs --since 1m m2y-api 2>&1 | grep -iE "m2y|uyar|warn|error|hata" | grep -viE "pass|sir|key|anahtar=" | tail -8
echo "[TAMAM] m2y-api güncellendi. Geri dönüş: M2Y_API_IMAJ=lejianwen/rustdesk-api:latest docker compose --profile api up -d api"
