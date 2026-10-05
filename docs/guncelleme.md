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

## Zorunlu güncelleme (karar 05.10.2026; istemci kodlandı, bkz. "Uygulama")
- `surum.json`'a `"asgari_surum": "x.y.z"` alanı eklenir (imzalı dosyanın içinde → sahtelenemez). `istemci-hazirla.sh`: `M2Y_ASGARI_SURUM` ortam değişkeni (varsayılan: yayınlanan sürüm = herkes en son sürüme geçmek zorunda).
- İstemci (iki program) açılışta ve 30 dk'da bir `surum.json`'ı imza doğrulamasıyla okur; kendi sürümü `asgari_surum`'dan küçükse **engelleyici pencere**: "Yeni sürüm yayında — devam etmek için güncellemeniz gerekiyor" + "Şimdi güncelle". Bu sırada gelen/giden bağlantı yapılmaz (oturum kapısı gibi `stop-service`), pencere kapatılamaz (yalnızca programdan çıkış).
  - Kurulu Windows (exe/MSI): mevcut SHA-256 doğrulamalı sessiz güncelleme hemen başlatılır, ilerleme gösterilir.
  - Hızlı Destek / taşınabilir: yeni exe indirilir, SHA-256 doğrulanır, eski dosyanın yanına `-yeni` olarak konur, program kendini yeniden başlatıp eskisini değiştirir; olmazsa indirme sayfası açılır.
  - macOS/Linux/Android: indirme sayfası bağlantısı.
- Sunucu tarafı ek zorlama: `/api/m2y/yetki` istekte istemci sürümünü alır, `M2Y_ASGARI_SURUM`'dan eskiyse belirteç vermez (eski denetleyici bağlanamaz). Ağ yoksa son başarılı `surum.json` kullanılır.

### Uygulama (istemci, 05.10.2026 — derlenmedi)
**Dosyalar:** `libs/hbb_common/src/m2y.rs` (`update_required`, `OPT_MIN_VERSION`, `OUTDATED_LOCAL` + `update_tests`), `src/common.rs` (`m2y_store_min_version`, `m2y_mandatory_update_*`, `m2y_download_verified`, `m2y_replace_and_restart`), `src/flutter_ffi.rs` (bağlar: `main_m2y_mandatory_update`, `main_m2y_check_mandatory_update`, `main_m2y_mandatory_update_now`; birleşik kapı), `src/core_main.rs` (`--m2y-replace`), `src/client.rs` (`surum` alanı + 426), `flutter/lib/common/widgets/m2y_zorunlu_guncelleme.dart`, `desktop_home_page.dart`, `connection_page.dart`, `server/scripts/istemci-hazirla.sh`.

**Durum:** `do_check_software_update` imzayı doğruladıktan sonra `asgari_surum`'u yerel yapılandırmaya (`m2y-asgari-surum`) yazar; alan yoksa temizler. İmzasız/doğrulanamayan dosya ve ağ hatası değeri **değiştirmez** (son doğrulanmış değer geçerli kalır → çevrimdışı da zorunluluk sürer; yeni sürüme geçince kendi sürümü asgariye eşit olduğundan kendiliğinden kalkar). Karşılaştırma `m2y::update_required(crate::VERSION, asgari)`: `v` öneki kabul, 1–4 sayısal parça, bozuk/boş girdi → zorunlu değil.

**Denetim:** ana pencere açılışında `M2yZorunluGuncelleme.start()` → `main_m2y_check_mandatory_update` (hemen + 30 dk'da bir; `enable-check-update`'ten bağımsız). Bitince `m2y_zorunlu_guncelleme` olayı → arayüz durumu yeniden okur.

**Katman:** zorunluysa ana sayfa yerine kapatılamayan katman (giriş ekranından da önce): "Yeni sürüm yayında — devam etmek için güncellemeniz gerekiyor (mevcut x, gerekli y)", solda "Programdan çık", sağda "Şimdi güncelle". Giden bağlantı düğmesi ve `onConnect` devre dışı.
- Kurulu Windows (`windows_install`, MSI dahil): kurulum exe'si indirilir, SHA-256 doğrulanır, `platform::update_to` (`--update`, UAC) çalıştırılır.
- Taşınabilir / Hızlı Destek (`windows` / `windows_qs`): exe çalışan exe'nin yanına `<ad>-yeni.exe` olarak indirilir (SHA-256 doğrulanmadan yazılmaz), `--m2y-replace <eski_exe>` ile başlatılır, program kapanır. Yardımcı ~60 sn boyunca eskisinin üzerine kopyalamayı dener (dosya kilidi), sonra eski yolu başlatır; yalnızca aynı klasördeki `.exe` hedef kabul edilir. Artık `-yeni.exe` sonraki açılışta silinir.
- Başarısızlıkta (adres/özet/indirme/UAC reddi) hata gösterilir ve indirme sayfası açılır. macOS/Linux: "Şimdi güncelle" indirme sayfasını açar.

**Kapı etkileşimi:** oturum kapısı ve zorunlu güncelleme aynı `stop-service` + `m2y-gate-stopped` yolunu kullanır; `flutter_ffi::m2y_apply_gate` ikisini birleştirir: kapı `zorunlu || oturum yok` iken kapalı, yalnızca ikisi de açık istediğinde açılır (oturum durumu henüz bilinmiyorsa açmaz). Kullanıcının elle durdurduğu hizmet yine korunur (`gate_transition`).

**Sunucu zorlaması (istemci tarafı):** `/api/m2y/yetki` gövdesi `{hedef_id, surum}`; 426 dönerse bağlantı reddinde "Programınız eski; bağlanmak için güncelleyin" gösterilir (m2y-api tarafı ayrıca kodlanmalı).

**Yayın:** `istemci-hazirla.sh` `asgari_surum` = `M2Y_ASGARI_SURUM` (x.y.z, `v` öneki atılır; bozuksa betik durur) yoksa yayınlanan sürüm. Alan imzalı dosyanın içindedir; imzalamadan önce denetleyin.

**Bilinen sınırlar / doğrulanmamış varsayımlar:**
- Derlenmedi; `update_tests` çalıştırılamadı. Yeni bağlar için `flutter_rust_bridge` kod üretimi gerekir.
- Kurulu Windows'ta güncelleme arayüz sürecinden UAC ile başlar (sessiz değil); hizmet sürecinin günlük sessiz güncellemesi ayrıca sürer. UAC reddedilirse indirme sayfası açılır.
- Taşınabilir değiştirmede, exe'yi kullanan başka süreç (ör. Hızlı Destek taşınabilir hizmeti) 60 sn içinde kapanmazsa değiştirme olmaz; `-yeni.exe` elle çalıştırılabilir. Exe yazılamaz bir klasördeyse indirme sayfası açılır.
- Kapı yalnızca ana pencere (Flutter) açıkken uygulanır; Android/mobil arayüze bağlanmadı (yalnızca masaüstü katmanı). Ayarlar sekmesi katmanın dışında kalabilir.
- 426 iletisi süreç genelindeki son yetki isteğine bakar; eşzamanlı iki bağlantıda ileti karışabilir.
