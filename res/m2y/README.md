# M2YDesk gömülü yapılandırma

`src/common.rs::load_custom_client()` bu klasördeki JSON'u derleme zamanında gömer ve açılışta imzasız uygular
(üst kaynaktaki imzalı `custom.txt` yolunun yerine geçer).

| Dosya | Varyant | Cargo özelliği |
|---|---|---|
| `m2ydesk.json` | **M2YDesk** — tam istemci | (varsayılan) |
| `m2ydesk-qs.json` | **M2YDesk Hızlı Destek** (kod adı QS) — yalnızca gelen bağlantı, ID + şifre | `m2y_qs` |

Yer tutucular derleme zamanında ortam değişkenlerinden doldurulur:

| Yer tutucu | Ortam değişkeni | Varsayılan |
|---|---|---|
| `${M2Y_SERVER_HOST}` | `M2Y_SERVER_HOST` | `desk.mehmetmesut.com` |
| `${M2Y_SERVER_KEY}` | `M2Y_SERVER_KEY` | boş (uyarı loglanır) |

`M2Y_SERVER_KEY`, sunucudaki `server/data/id_ed25519.pub` içeriğidir (açık anahtar, gizli değildir).

## Kurallar
- Tüm değerler **string** olmalı (`"Y"`/`"N"`); sayı/boolean sessizce yok sayılır.
- Üst düzey anahtarlar (`conn-type`, `disable-*`) `HARD_SETTINGS`'e gider.
- `override-settings` kullanıcı tarafından değiştirilemez; `default-settings` değiştirilebilir.
- `app-name` boşluksuz ASCII olmalı (Windows servis adı, URL şeması ve klasör adları buradan türer).
