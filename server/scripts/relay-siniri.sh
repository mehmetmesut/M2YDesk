#!/usr/bin/env bash
# İkinci relay (:21127) için eşzamanlı bağlantı sınırı (iptables connlimit).
#
# ⚠️ DIŞA DÖNÜK / GÜVENLİK DUVARI DEĞİŞİKLİĞİ: kullanıcı onayı olmadan çalıştırmayın.
# Bir oturum relay'de İKİ TCP bağlantısı (denetleyen + denetlenen) kullanır → 5 oturum = 10 bağlantı.
# --connlimit-mask 0: tüm kaynaklar birlikte sayılır (toplam 5 eşzamanlı oturum).
# Kalıcı yapmak için: iptables-persistent / firewalld doğrudan kuralı kullanın.
#
# Kullanım:  sudo bash scripts/relay-siniri.sh ekle | kaldir | durum
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "root gerekli" >&2; exit 1; }
PORT=21127; LIMIT=${M2Y_BAGLANTI_SINIRI:-10}
KURAL=(-p tcp --syn --dport "$PORT" -m connlimit --connlimit-above "$LIMIT" --connlimit-mask 0 -j REJECT --reject-with tcp-reset)
case "${1:-durum}" in
  ekle)   iptables -C INPUT "${KURAL[@]}" 2>/dev/null || iptables -I INPUT "${KURAL[@]}"; echo "Kural eklendi (sınır: $LIMIT bağlantı)";;
  kaldir) iptables -D INPUT "${KURAL[@]}" 2>/dev/null && echo "Kural kaldırıldı" || echo "Kural yoktu";;
  durum)  iptables -S INPUT | grep -- "--dport $PORT" || echo "Kural yok";;
  *) echo "Kullanım: $0 ekle|kaldir|durum" >&2; exit 1;;
esac
