# Üye olmayan kullanıcı kuralları (Görev 3)

Kod: `libs/hbb_common/src/m2y.rs` (saf mantık + testler), bağlantılar `src/client/io_loop.rs`, `src/client.rs`, `src/common.rs::m2y_connect_gate`.

| Kural | Uygulama |
|---|---|
| Üye tanımı | `LocalConfig` `access_token` **ve** `user_info` dolu (hesap girişi) |
| Oturum süresi | Bağlantı kurulunca sayaç; 4:30'da uyarı kutusu, 5:00'da oturum kapanır (`io_loop` 1 sn'lik `status_timer`) |
| Bekleme | Kapanışta cihaz 2 dk yeni **giden** bağlantı kuramaz (`m2y-block-until`, Unix sn, yerel yapılandırma) |
| Engel listesi | `https://<sunucu>/guncelleme/engel.json` → `{"id":[…],"uuid":[…],"mac":[…]}`, değerler **küçük harfli, kırpılmış metnin SHA-256'sı**; 10 dk önbellek; ağ hatasında engel uygulanmaz |
| Relay | Üye olmayan: `request_relay` içinde adres `host:21127`; üye: değişmez (`:21117`) |

## Kapalı gönderilir
`res/m2y/m2ydesk.json` → `"m2y-nonmember-limit": "N"`. Hesap girişi/API sunucusu olmadığından herkes "üye olmayan" sayılırdı (danışmanın kendi oturumu da 5 dk'da kesilirdi). API sunucusu kurulup `disable-account` kalkınca "Y" yapılıp yeniden derlenir. Engel listesi kuralı bu anahtardan bağımsız çalışır.

## Bilinen sınırlar (dürüst not)
- **İstemci kaynağı açık**: değiştirilmiş istemci sayaçları/bekleme kaydını atlatabilir; süre kuralı bir *kullanım politikası*dır, güvenlik sınırı değil. Bekleme kaydı yerel dosyada (silinirse sıfırlanır). Gerçek zorlama sunucu tarafında olmalı.
- **Relay portu**: RustDesk'te relay adresini iki akış belirler: (a) denetleyen taraf `RequestRelay` ile seçer → :21127 çalışır; (b) karşı taraf (`get_relay_server`, kendi `relay-server` seçeneği) seçip `RelayResponse` ile bildirir → :21117 kalır. Hangisinin kullanıldığı hbbs davranışına bağlı ve **doğrulanmadı**; yerel oturum günlüklerle doğrulayacak. (b) çıkarsa 21127 yönlendirmesi etkisiz kalır (sistem yine çalışır).
- Doğrudan (P2P) bağlantılar relay'den geçmez; sunucu tarafı 5 eşzamanlı oturum sınırı bunları göremez.
- `engel.json` kimlik doğrulamasızdır (HTTPS'e güvenir); yalnızca kötüye kullanımı caydırır.
