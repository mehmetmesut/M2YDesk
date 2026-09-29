# M2YDesk güncelleme mekanizması

İstemci, `https://desk.mehmetmesut.com/guncelleme/surum.json` dosyasını (GET) okur. Alan adı derleme zamanında `M2Y_SERVER_HOST` ile gelir (`hbb_common::m2y_update_url`).

## surum.json şeması
```json
{"version":"1.0.1","tarih":"2026-09-29",
 "dosyalar":{"windows_install":{"url":"https://desk.mehmetmesut.com/indir/M2YDesk-1.0.1-x86_64-install.exe","sha256":"…"},
             "windows":{…},"windows_qs":{…},"windows_msi":{…},"macos_apple":{…},"linux_deb":{…},"android":{…}}}
```
`server/scripts/istemci-hazirla.sh` release dosyalarını indirirken SHA-256'ları hesaplayıp bu dosyayı **atomik** yazar (etiket `x.y.z` değilse dokunmaz).

## Davranış
| Varyant | Denetim | Eylem |
|---|---|---|
| M2YDesk, Windows, **kurulu** (`windows_install`) | açılışta + günde bir (`enable-check-update=Y`) | `allow-auto-update=Y` ise **sessiz güncelleme**: indir → SHA-256 doğrula → `--update` |
| M2YDesk taşınabilir / macOS / Linux / Android | aynı | Yalnızca ana ekranda "Yeni sürüm" kartı → indirme sayfası |
| Hızlı Destek | `enable-check-update=Y`, `allow-auto-update=N` | Yalnızca kart |

## Güvenlik ve sınırlar
- Dosya adresi yalnızca `https://<M2Y_SERVER_HOST>/` altında kabul edilir; SHA-256 boşsa dosya reddedilir.
- Doğrulanmayan dosya diske yazılmaz, çalıştırılmaz. Daha önce indirilmiş dosya ancak hash eşleşirse yeniden kullanılır.
- **Kod imzası yok.** Bütünlük yalnızca HTTPS + SHA-256'ya dayanır; `surum.json` ve `indir/` aynı sunucuda olduğundan sunucu ele geçirilirse imza koruması yoktur. 2. faz: Ed25519 ile imzalı `surum.json` (açık anahtar istemciye gömülü) önerilir.
- Aktif bağlantı varken güncelleme yapılmaz (üst kaynak davranışı korunur).
- MSI ile kurulu sürüm: özel istemcide `update_msi` kapalıdır, exe yolu kullanılır — **gerçek cihazda test edilmedi** (yerel oturum).

## Test (yerel oturum)
1. 1.0.0 kurulu; sunucuda `M2Y_SURUM=v1.0.1 … istemci-hazirla.sh` (release 1.0.1 yayımlanmış olmalı).
2. Bağlantı yokken ≤30 sn sonra güncelleme başlamalı; günlükte `New version available: 1.0.1`.
3. `surum.json` içinde sha256'yı bozup tekrar dene: `SHA-256 mismatch` günlüğü ve güncelleme yapılmamalı.
