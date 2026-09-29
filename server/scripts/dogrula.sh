#!/usr/bin/env bash
# Sunucu uçtan uca sağlık denetimi (yalnızca okur, hiçbir şeyi değiştirmez).
# Kullanım: cd /opt/m2ydesk/server && bash scripts/dogrula.sh
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ALAN="$(grep -E '^ALAN_ADI=' .env 2>/dev/null | cut -d= -f2)"; ALAN="${ALAN:-desk.mehmetmesut.com}"
ok(){ echo -e "\e[32m✔\e[0m $*"; }; kotu(){ echo -e "\e[31m✘\e[0m $*"; }
chk(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else kotu "$1"; fi; }

for c in hbbs hbbr hbbr2 m2y-api; do
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$c"; then ok "kapsayıcı çalışıyor: $c"; else echo "· kapsayıcı yok/kapalı: $c"; fi
done
for p in 21115 21116 21117 21118 21119 21127; do
  chk "TCP $p yerelde dinliyor" "ss -ltn | grep -q ':$p '"
done
chk "UDP 21116" "ss -lun | grep -q ':21116 '"
chk "Açık anahtar var (özel anahtar HARİÇ)" "test -s data/id_ed25519.pub"
chk "Site: https://$ALAN/" "curl -fsS -m 10 -o /dev/null https://$ALAN/"
chk "Site: ayar.js" "curl -fsS -m 10 -o /dev/null https://$ALAN/ayar.js"
chk "Güncelleme: surum.json" "curl -fsS -m 10 https://$ALAN/guncelleme/surum.json | python3 -c 'import sys,json;d=json.load(sys.stdin);assert d[\"version\"]'"
chk "Engel listesi: engel.json" "curl -fsS -m 10 https://$ALAN/guncelleme/engel.json | python3 -c 'import sys,json;json.load(sys.stdin)'"
chk "API: /api/login-options" "curl -fsS -m 10 https://$ALAN/api/login-options"
chk "Güvenlik: /data/ web'den erişilemez" "! curl -fsS -m 10 -o /dev/null https://$ALAN/data/id_ed25519"
chk "Güvenlik: /indir/ dizin listesi kapalı" "! curl -fsS -m 10 https://$ALAN/indir/ | grep -qi 'index of'"
