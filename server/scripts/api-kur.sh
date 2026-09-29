#!/usr/bin/env bash
# Hesap API'sini (lejianwen/rustdesk-api) başlatır ve durumunu denetler. Tekrar çalıştırılabilir (idempotent).
# Kullanım (sunucuda, SSH):  cd /opt/m2ydesk/server && sudo bash scripts/api-kur.sh
#
# ⚠️ Bu betik admin parolasını EKRANA YAZMAZ. İlk parolayı kendiniz okuyun (sohbete/depoya yapıştırmayın):
#    sudo docker logs m2y-api 2>&1 | grep -i -m3 "password"
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

bilgi()  { echo -e "\e[34m[BİLGİ]\e[0m $*"; }
basari() { echo -e "\e[32m[TAMAM]\e[0m $*"; }
hata()   { echo -e "\e[31m[HATA]\e[0m $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || hata "root gerekli (sudo)."
[[ "$PWD" == *httpdocs* ]] && hata "Bu klasör web dizini içinde olmamalı."
[[ -f .env ]] || hata ".env yok. Önce scripts/kurulum.sh çalıştırın."
[[ -s data/id_ed25519.pub ]] || hata "data/id_ed25519.pub yok (hbbs çalışıyor mu?)."
command -v docker >/dev/null || hata "Docker kurulu değil."

mkdir -p data/api
bilgi "API kapsayıcısı başlatılıyor…"
docker compose --profile api up -d api
sleep 5
docker ps --format '{{.Names}}\t{{.Status}}' | grep -q '^m2y-api' || { docker logs m2y-api 2>&1 | tail -20; hata "m2y-api çalışmıyor."; }
basari "m2y-api çalışıyor."

# Yerel sağlık denetimi (Plesk nginx ayarı henüz yapılmamış olabilir)
if curl -fsS -m 10 http://127.0.0.1:21114/api/login-options >/dev/null 2>&1; then
    basari "Yerel API yanıt veriyor: /api/login-options"
else
    echo -e "\e[33m[UYARI]\e[0m /api/login-options yerelde yanıt vermedi; 'docker logs m2y-api' inceleyin (değişken adları doğrulanmadı)."
fi

# Dışarıdan (nginx ters vekili kurulduysa)
ALAN="$(grep -E '^ALAN_ADI=' .env | cut -d= -f2)"
if curl -fsS -m 10 "https://${ALAN}/api/login-options" 2>/dev/null; then
    echo; basari "Dışarıdan erişilebilir: https://${ALAN}/api/login-options"
else
    echo -e "\e[33m[UYARI]\e[0m https://${ALAN}/api/ henüz yönlenmiyor → Plesk 'Ek nginx yönergeleri' (server/plesk-nginx.conf.example) ekleyin."
fi
echo
bilgi "Sonraki: yönetim paneli https://${ALAN}/_admin/ → admin parolasını değiştirin → Google OIDC (docs/hesap-ve-google-girisi.md)"
