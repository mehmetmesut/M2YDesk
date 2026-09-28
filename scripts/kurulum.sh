#!/usr/bin/env bash
# RustDesk Server OSS kurulum betiği (Docker)
# Kullanım: sudo bash scripts/kurulum.sh
# Önerilen konum: /opt/rustdesk  (web kök dizini httpdocs içine KURMAYIN)

set -euo pipefail

# Betiğin bulunduğu klasörün bir üstü proje kök dizinidir
PROJE_DIZINI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJE_DIZINI"

# Renkli çıktı yardımcıları
bilgi()  { echo -e "\e[34m[BİLGİ]\e[0m $*"; }
basari() { echo -e "\e[32m[TAMAM]\e[0m $*"; }
uyari()  { echo -e "\e[33m[UYARI]\e[0m $*"; }
hata()   { echo -e "\e[31m[HATA]\e[0m $*" >&2; exit 1; }

# 1) Root yetkisi kontrolü (güvenlik duvarı ve docker için gerekli)
[[ $EUID -eq 0 ]] || hata "Bu betik root olarak çalıştırılmalı: sudo bash scripts/kurulum.sh"

# 2) httpdocs altında çalıştırılmasını engelle (özel anahtar web'den erişilebilir olur)
if [[ "$PROJE_DIZINI" == *httpdocs* || "$PROJE_DIZINI" == /var/www/* ]]; then
    hata "Proje web dizininde ($PROJE_DIZINI). Özel anahtar sızabilir! /opt/rustdesk gibi bir konuma taşıyın."
fi

# 3) Docker ve Compose kontrolü
command -v docker >/dev/null 2>&1 || hata "Docker kurulu değil. Plesk > Araçlar ve Ayarlar > Güncellemeler > Docker bileşenini kurun."
if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose)
else
    hata "Docker Compose bulunamadı. 'docker-compose-plugin' paketini kurun."
fi
basari "Docker ve Compose bulundu."

# 4) .env dosyası yoksa örnekten oluştur
if [[ ! -f .env ]]; then
    cp .env.example .env
    uyari ".env oluşturuldu. Alan adını kontrol edin: $(grep '^ALAN_ADI=' .env)"
fi
# shellcheck disable=SC1091
source .env
[[ -n "${ALAN_ADI:-}" ]] || hata ".env içinde ALAN_ADI tanımlı değil."

# 5) DNS kaydı kontrolü (uyarı amaçlı, kurulumu durdurmaz)
if command -v getent >/dev/null 2>&1; then
    if DNS_IP="$(getent ahostsv4 "$ALAN_ADI" | awk 'NR==1{print $1}')" && [[ -n "$DNS_IP" ]]; then
        bilgi "$ALAN_ADI -> $DNS_IP"
    else
        uyari "$ALAN_ADI çözümlenemedi. Plesk DNS'ine A kaydı ekleyin."
    fi
fi

# 6) Güvenlik duvarı portları
TCP_PORTLARI=(21115 21116 21117 21118 21119)
UDP_PORTLARI=(21116)

if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    bilgi "firewalld algılandı, portlar açılıyor..."
    for p in "${TCP_PORTLARI[@]}"; do firewall-cmd --permanent --add-port="${p}/tcp" >/dev/null; done
    for p in "${UDP_PORTLARI[@]}"; do firewall-cmd --permanent --add-port="${p}/udp" >/dev/null; done
    firewall-cmd --reload >/dev/null
    basari "firewalld kuralları eklendi."
elif command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    bilgi "ufw algılandı, portlar açılıyor..."
    ufw allow 21115:21119/tcp >/dev/null
    ufw allow 21116/udp >/dev/null
    basari "ufw kuralları eklendi."
else
    uyari "Aktif firewalld/ufw bulunamadı. Plesk Güvenlik Duvarı eklentisi kullanıyorsanız"
    uyari "TCP 21115-21119 ve UDP 21116 portlarını elle açın."
fi
uyari "Sunucu sağlayıcınızın (bulut) güvenlik duvarında da aynı portlar açık olmalı."

# 7) Veri klasörü ve servisleri başlat
mkdir -p data
chmod 700 data
bilgi "RustDesk imajı indiriliyor ve servisler başlatılıyor..."
"${COMPOSE[@]}" pull
"${COMPOSE[@]}" up -d

# 8) Anahtarın oluşmasını bekle (en fazla 30 sn)
for _ in $(seq 1 30); do
    [[ -s data/id_ed25519.pub ]] && break
    sleep 1
done
[[ -s data/id_ed25519.pub ]] || hata "Anahtar oluşmadı. Logları inceleyin: ${COMPOSE[*]} logs hbbs"

# Özel anahtarı yalnızca root okuyabilsin
chmod 600 data/id_ed25519 2>/dev/null || true

ANAHTAR="$(cat data/id_ed25519.pub)"
echo
basari "RustDesk sunucusu çalışıyor."
echo "------------------------------------------------------------"
echo " ID Sunucusu    : $ALAN_ADI"
echo " Relay Sunucusu : $ALAN_ADI"
echo " Anahtar (Key)  : $ANAHTAR"
echo "------------------------------------------------------------"
uyari "data/id_ed25519 (özel anahtar) dosyasını güvenli bir yere yedekleyin."
uyari "Kaybolursa tüm istemcileri yeniden yapılandırmanız gerekir."
