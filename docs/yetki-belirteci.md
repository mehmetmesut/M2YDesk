# Yetkili hesap belirteci (`m2y_auth`)

Amaç: Hızlı Destek ve M2YDesk gelen bağlantıyı **yalnızca** m2y-api'nin yetkili saydığı hesaplardan
(admin ya da `m2y_yetkili=true`) kabul eder (karar: `docs/guvenlik-ve-destek-ozellikleri.md` §2).

## Akış

1. Denetleyen istemci oturum açmışsa (`access_token` dolu), parola/LoginRequest gönderilmeden hemen önce
   `POST <api-server>/api/m2y/yetki` çağrılır: `Authorization: Bearer <access_token>`, gövde
   `{"hedef_id":"<hedef cihaz ID>"}`, toplam zaman aşımı 5 sn (`src/client.rs`, `m2y_fetch_auth`).
   - Yalnızca sertifikası doğrulanan TLS kullanılır (Rustls, olmazsa native-tls); taşıyıcı belirteç
     sızmasın diye "geçersiz sertifikayı kabul et" geri düşüşü **yoktur**.
   - `200 {"belirtec": ...}` → belirteç `LoginRequest.m2y_auth` (proto alan 100) içine konur.
   - Oturum yok / 401 / 403 / ağ hatası / zaman aşımı → alan boş gider (günlüğe uyarı).
2. Kontrol edilen taraf (`src/server/connection.rs`, LoginRequest işlenirken, onay/parola denetiminden
   **önce**) `m2y-require-auth` = `Y` ise belirteci doğrular (`hbb_common::m2y::verify_m2y_auth`):
   - imza: gömülü açık anahtarlardan herhangi biri (derleme zamanı `M2Y_AUTH_PUBKEYS`, virgüllü base64),
   - `h` == kendi ID'si, `x + 60 sn > şimdi` (saat sapması toleransı), `e` boş değil.
   - Geçersiz: başarısız deneme sayacı (parola ile aynı `LOGIN_FAILURES`) artar, `"Bu cihaza yalnızca
     yetkili danışmanlar bağlanabilir"` hatası gönderilir, bağlantı kapanır.
   - Geçerli: normal akış sürer; **parola yine sorulur**.
   - Günlük: e-posta maskelenir (`m***@alan.com`); belirteç günlüğe yazılmaz.
3. Denetleyen taraf bu hatayı alınca kullanıcıya "Bu cihaza bağlanma yetkiniz yok veya sunucuya
   ulaşılamadı" iletisini gösterir (`handle_login_error`).

## Biçim (m2y-api `service/m2y_yetki.go` ile birebir)

```
belirteç = base64url(yük) + "." + base64url(imza)      (dolgusuz base64url)
yük      = {"e":"<e-posta>","h":"<hedef ID>","x":<son geçerlilik, Unix sn>,"n":"<rastgele>"}
imza     = Ed25519(özel anahtar, yük JSON baytları)      → doğrulama 1. parçanın çözülmüş baytları üzerinde
```

Süre 300 sn. Yük yeniden serileştirilmez; imza sunucunun ürettiği baytlar üzerinde doğrulanır.

## Yapılandırma

| Yer | Değer |
|---|---|
| `res/m2y/m2ydesk.json`, `m2ydesk-qs.json` → `override-settings` | `"m2y-require-auth": "Y"` |
| GitHub → Settings → Variables → **`M2Y_AUTH_PUBKEYS`** | `p/UXPmltiAKeRjWNWExrFg1V95uydUw+4rvGfM6Cgco=` (canlı sunucunun açık anahtarı; anahtar döndürmede virgülle ikincisi eklenir) |

`M2Y_AUTH_PUBKEYS` boşsa derleme `cargo:warning` / iş akışı `::warning::` verir ve `m2y-require-auth`
açık istemci **tüm** gelen bağlantıları reddeder (güvenli varsayılan).

## Bilinen sınırlar

- Doğrudan IP ile bağlantıda hedef ID bir IP olduğundan sunucu belirteç vermez → reddedilir.
- "Taraf değiştir" (switch sides) dönüşü bu denetimden geçmez; o yol yalnızca kontrol edilen cihazın
  kendi ürettiği UUID ile çalışır.
- Belirteç 5 dk içinde aynı hedefe tekrar kullanılabilir (sunucu `n` takibi yapmaz).
- Kaynak açık: değiştirilmiş bir *kontrol edilen* istemci denetimi kapatabilir; bu yalnızca kendi cihazını açar.
- Stok RustDesk denetleyicileri alanı göndermez → reddedilir (beklenen).

## Test

- Birim: `cargo test -p hbb_common m2y` — `auth_tests`: sabit vektör (tohum 32×0x07, PyNaCl ile
  m2y-api biçiminde üretildi; sodiumoxide ile aynı belirteç baytlarının üretildiği de sınanır), geçerli,
  anahtar döndürme, yanlış hedef, süresi dolmuş (60 sn tolerans sınırı), bozuk imza/yük, yanlış/eksik
  anahtar, bozuk biçim, e-posta maskesi.
- Elle: (1) yetkili hesapla oturum aç → Hızlı Destek'e bağlan → parola sorulmalı; (2) oturumu kapat →
  bağlan → "Bu cihaza bağlanma yetkiniz yok…"; (3) yetkisiz hesap → 403 → aynı ileti; (4) kontrol edilen
  tarafın günlüğünde `yetki belirteci geçerli: m***@…` / `reddedildi: <neden>`.
