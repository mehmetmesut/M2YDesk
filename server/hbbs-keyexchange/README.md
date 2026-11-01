# hbbs KeyExchange yaması

Açık kaynak hbbs, hesapla oturum açmış resmî RustDesk istemcilerinin (iOS/Android/masaüstü)
beklediği imzalı `KeyExchange` el sıkışmasını göndermez; istemci 18 sn sonra
"Failed to secure tcp: deadline has elapsed" verir. Bu yama, RustDesk Pro gibi her TCP
bağlantısında önce imzalı `KeyExchange` gönderir; istemci yanıtlarsa kanal şifrelenir,
yanıtlamazsa (M2YDesk ve oturumsuz istemciler mesajı atlar) düz kanalda devam edilir.

Kaynak: `rustdesk/rustdesk-server` 873230e (1.1.17), sunucuda `/opt/m2ydesk/hbbs-src`.

Sıra (sunucuda, betikler `/tmp`'ye kopyalanıp):
1. `hbbs_derle.sh` — yamayı uygular (`hbbs_yama.py`), musl statik derler → `hbbs-m2y`
2. `hbbs_test.sh` — birim testleri (`m2y_key_exchange_tests`)
3. `hbbs_yayin.sh` — `m2y-hbbs:yerel` imajı, compose'da yalnız hbbs imajı değişir, yedek `docker-compose.yml.bak-20261101`

Geri dönüş: `cp docker-compose.yml.bak-20261101 docker-compose.yml && docker compose up -d hbbs`.
