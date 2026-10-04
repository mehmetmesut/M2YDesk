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
- **Kod imzası (Authenticode) yok**, ancak `surum.json` **Ed25519 ile imzalıdır** (aşağıda "İmza"): sunucu ele geçirilse bile sahte SHA-256/adres içeren bildirim kabul edilmez.
- Aktif bağlantı varken güncelleme yapılmaz (üst kaynak davranışı korunur).
- MSI ile kurulu sürüm: özel istemcide `update_msi` kapalıdır, exe yolu kullanılır — **gerçek cihazda test edilmedi** (yerel oturum).

## İmza
`surum.json` ve `engel.json` yanında ayrık imza bulunur: `surum.json.sig` / `engel.json.sig` = dosyanın **ham baytları** üzerine Ed25519 imzanın base64'ü (tek satır). İstemci önce `.sig`'i indirir, sonra dosyayı derlemeye gömülü açık anahtar(lar)dan biriyle doğrular. İmza yok/bozuk/eşleşmiyor → **güncelleme yapılmaz**, **engel listesi uygulanmaz** (önceki önbellek de kullanılmaz), günlüğe uyarı yazılır. Kod: `hbb_common::m2y::verify_detached` (birim testli), `src/common.rs` (`m2y_fetch_sig`).

Açık anahtarlar derleme zamanında `M2Y_UPDATE_PUBKEYS` ortam değişkeninden gelir (virgülle ayrılmış base64, 32 bayt). Boşsa derleme uyarı verir ve imzalı dosyalar **reddedilir** (güvenli varsayılan: güncelleme yok).

**Kural:** İmzalama **sunucuda yapılmaz**; kullanıcının bilgisayarında veya GitHub Actions'ta yapılır. Özel anahtar depoya, sohbete, sunucuya girmez.

1. **Anahtar üretimi (bir kez, kendi bilgisayarınızda):** `python3 server/scripts/imzala.py anahtar-uret ~/m2y-imza.pem` (`pip install cryptography` gerekir). Özel anahtar dosyaya 600 izinle yazılır, ekrana basılmaz; ekrana basılan **açık anahtarı** kopyalayın. Özel anahtarın yedeğini çevrimdışı güvenli bir yerde (şifreli USB/parola yöneticisi) saklayın. Windows'ta 600 izni uygulanmaz; dosyayı yalnızca sizin erişebildiğiniz klasörde tutun.
2. **GitHub Variables:** Depo → Settings → Secrets and variables → Actions → **Variables** → `M2Y_UPDATE_PUBKEYS` = açık anahtar. (Açık anahtar gizli değildir.) Ardından istemcileri yeniden derleyin; `m2y-build.yml` değişken boşsa `::warning::` verir. İsteğe bağlı: Actions'ta imzalamak için özel anahtar PEM içeriği **Secret** `M2Y_UPDATE_SIGNING_KEY` olarak eklenir, iş akışında `$RUNNER_TEMP` altına dosyaya yazılıp `imzala.py imzala … --anahtar` ile kullanılır.
3. **Her yayında:** sunucuda `istemci-hazirla.sh` `surum.json`'ı **imzasız** üretir (`.sig` yoksa/eskiyse uyarır). Dosyayı bilgisayarınıza alın, **içeriğini denetleyin** (sürüm, adresler; SHA-256'lar GitHub Release dosyalarıyla aynı mı — sunucu güvenilmez kabul edilir, körü körüne imzalamayın), imzalayın ve yalnızca `.sig`'i yükleyin:
   ```bash
   scp sunucu:<SITE_DIZINI>/guncelleme/surum.json .
   python3 server/scripts/imzala.py imzala surum.json --anahtar ~/m2y-imza.pem
   python3 server/scripts/imzala.py dogrula surum.json --acik-anahtar "<M2Y_UPDATE_PUBKEYS>"
   scp surum.json.sig sunucu:<SITE_DIZINI>/guncelleme/
   ```
   `engel.json` her değiştiğinde aynı adımlar (`engel.json` → `engel.json.sig`). İmzadan sonra dosyada tek bayt değişirse imza geçersizleşir.
4. **Anahtar döndürme:** yeni çift üretin; `M2Y_UPDATE_PUBKEYS` = `yeni,eski` yapıp yeni sürüm yayınlayın (eski istemciler hâlâ eski anahtarla imzalı dosyayı kabul eder). Tüm istemciler yeni sürüme geçince dosyaları yeni anahtarla imzalayın ve eski anahtarı listeden çıkarın.
5. **Anahtar kaybı / sızıntısı:** özel anahtar **kaybolursa** mevcut istemciler hiçbir yeni bildirimi kabul etmez → kullanıcılar yeni anahtarlı sürümü indirme sayfasından **elle** kurmalıdır (yedek bu yüzden şarttır). **Sızarsa** anahtarı listeden çıkarıp yeni sürüm yayınlayın; eski sürümler sızan anahtara güvenmeye devam eder, kullanıcıları elle güncellemeye yönlendirin.
- Sınır: imza tazelik (zaman damgası) içermez; ele geçirilmiş sunucu daha önce imzalanmış **eski** bir `surum.json`/`engel.json`'ı sunabilir (güncellemeyi dondurma, eski engel listesine dönme). Sahte içerik ise imzalanamaz.

## Test (yerel oturum)
1. 1.0.0 kurulu; sunucuda `M2Y_SURUM=v1.0.1 … istemci-hazirla.sh` (release 1.0.1 yayımlanmış olmalı).
2. Bağlantı yokken ≤30 sn sonra güncelleme başlamalı; günlükte `New version available: 1.0.1`.
3. `surum.json` içinde sha256'yı bozup tekrar dene: `SHA-256 mismatch` günlüğü ve güncelleme yapılmamalı.
