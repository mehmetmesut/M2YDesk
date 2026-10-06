# E-posta + kod ile zorunlu oturum açma (tasarım, 04.10.2026)

**Durum:** Karar verildi, kodlanmadı. Uygulayıcı: bulut oturumu (istemci + sunucu servisi kodu); sunucu kurulumu ve SMTP: yerel oturum.

## Kararlar (kullanıcı)
| Konu | Karar |
|---|---|
| Kapsam | **Her iki program**: Hızlı Destek (danışan) ve tam M2YDesk |
| Zorunluluk | **Zorunlu.** Kod doğrulanmadan program ID/parola göstermez, bağlantı kabul etmez ve kurmaz. Oturum açılmamışsa **her açılışta** e-posta ekranı gelir |
| Akış | E-posta yaz → e-postaya gelen **eşsiz kod** → kodu gir → oturum açıldı → **sabit parola** (6 hane, yalnız rakam, iki kez) — bu adım atlanamaz (sabit parola daha önce belirlendiyse tekrar sorulmaz) |
| Sonra | Sabit parola ve "Sürekli erişim" ayarlardan / Hızlı Destek'te ana penceredeki menüden değiştirilebilir |

## İstemci akışı
1. Açılış → `access_token` yoksa veya sunucu geçersiz sayarsa **tam ekran giriş adımı** (ana pencere içeriği gizli; Hızlı Destek 280 px genişliğe sığmalı).
2. Ekran 1: e-posta alanı + KVKK aydınlatma bağlantısı + açık rıza kutusu → "Kod gönder". E-posta biçimi istemcide ve sunucuda doğrulanır.
3. Ekran 2: 6 haneli kod alanı, "Kodu yeniden gönder" (geri sayımlı), "E-postayı değiştir". Doğrulanınca `access_token` + `user_info` `LocalConfig`'e yazılır (mevcut hesap altyapısı; kullanıcı **üye** sayılır).
4. Ekran 3 (sabit parola yoksa): 6 hane rakam ×2 → `set_permanent_password`; Hızlı Destek'te `verification-method=use-both`, "Sürekli erişime izin ver" varsayılan açık.
5. Ana ekran. Çıkış yapılırsa 1'e döner.
- Bilinen hesap altyapısı (`/api/login`, `user_info`) yeniden kullanılır; yeni giriş türü yalnızca kod tabanlı.
- **KARAR:** **Her iki programda** (tam M2YDesk ve Hızlı Destek) giriş ekranında **Google ile giriş** ek seçenek olarak bulunur (mevcut OIDC akışı: `/api/oidc/auth`, tarayıcıda Google onayı); e-posta+kod birincil. Hızlı Destek'te `disable-account` kaldırılmadan yalnızca giriş ekranı açılır (ayarlar yine kapalı); 280 px pencereye sığmalı.

## Sunucu (yeni ince servis veya API eki)
- Uçlar: `POST /api/m2y/kod-gonder {email}` → her zaman 200 (hesap var/yok sızdırmaz); `POST /api/m2y/kod-dogrula {email, kod}` → `access_token` + `user` (rustdesk-api kullanıcısıyla eşleşmiş/oluşturulmuş).
- ❓ `lejianwen/rustdesk-api` e-posta kodu ile girişi destekliyor mu → bulut araştırsın. Desteklemiyorsa: ayrı Go/Rust ince servis (`m2y-auth`) kodu doğrular, rustdesk-api'de kullanıcıyı bulur/oluşturur ve onun token'ını döndürür; ya da rustdesk-api'ye MIT yaması.
- Kod: 6 hane, **10 dk** geçerli, tek kullanımlık; sunucuda yalnızca **hash** saklanır; sabit zamanlı karşılaştırma; e-posta başına **5 hatalı deneme** → kod iptal.
- Hız sınırı: e-posta başına 15 dk'da 3 gönderim, IP başına saatte 10; aşımda 429.
- Kod ve token **günlüğe yazılmaz**.
- E-posta gönderimi: Plesk posta (ör. `noreply@mehmetmesut.com`), SMTP 587 + STARTTLS. **SMTP parolası yalnızca sunucu `.env`'inde** (depoya/sohbete yazılmaz; kullanıcı kendisi girer). SPF/DKIM/DMARC `mehmetmesut.com` için doğrulanmalı (spam'e düşmesin).
- E-posta içeriği (Türkçe, sade): "M2YDesk doğrulama kodunuz: 123456 — 10 dakika geçerlidir. Bu isteği siz yapmadıysanız dikkate almayın." + footer kredisi.

## Sonuçlar ve riskler (dürüst not)
1. **Üye olmayan kuralları (5 dk / 2 dk, 5 eşzamanlı) KALDIRILDI** (kullanıcı kararı 04.10.2026): giriş zorunlu, herkes üye. `m2y-nonmember-limit=N`; hbbr2/relay-siniri kurulmayacak.
2. **KARAR — çevrimdışı tolerans 7 gün:** Oturum açmış cihaz sunucuya ulaşamasa da oturum **son başarılı sunucu doğrulamasından itibaren 7 gün** geçerli kalır. **Kayan süre:** cihaz sunucuya **her ulaştığında** (her başarılı heartbeat/token doğrulaması) 7 günlük süre **sıfırlanır** (`m2y-last-auth-ok`, Unix sn, yerel yapılandırma). Düzenli çevrimiçi olan cihazın oturumu hiç düşmez. 7 günü aşınca oturum geçersiz sayılır (token silinir), giriş ekranı açılır. Sunucu token'ı açıkça reddederse (401) süre beklenmeden oturum kapanır. İlk giriş her zaman sunucu ister.
3. **KARAR — e-posta hatırlanır:** Oturum düşse de son kullanılan e-posta yerel yapılandırmada kalır (`m2y-last-email`). Giriş ekranı açılınca alan **dolu** gelir ve birincil düğme **"Doğrulama kodu gönder"** olur (tek tıkla kod isteğine teşvik; yanında "Başka e-posta kullan"). Çıkışta da e-posta hatırlanır; kullanıcı "Bu cihazdan e-postamı unut" ile silebilir (KVKK).
3. **E-posta teslimi:** kod spam'e düşerse danışan bağlanamaz → SPF/DKIM şart; ekranda "spam klasörünü kontrol edin" notu.
4. **KVKK:** e-posta kişisel veridir; aydınlatma metni + açık rıza; saklama süresi ve silme talebi panelde.
5. Kaynak açık olduğundan değiştirilmiş istemci giriş ekranını atlayabilir; asıl zorlama sunucuda olmalı (ör. hbbs/relay'de token doğrulaması — ileri aşama). Şimdilik istemci tarafı zorlama + API'de cihaz kaydı.
6. Bağımlılık: hesap API'si (Y2) ve SMTP kurulmadan bu sürüm **dağıtılmaz**; aksi hâlde kimse programı kullanamaz.

## Uygulama (istemci, 05.10.2026 — derlenmedi)

**Dosyalar:** `flutter/lib/common/widgets/m2y_auth.dart` (durum denetleyicisi), `m2y_login_gate.dart` (giriş ekranları), `m2y_fixed_password.dart` (sabit parola formu + Hızlı Destek menüsü), `flutter/lib/models/user_model.dart` (`m2ySendCode`, `m2yVerifyCode`, `m2yVerifySession`), `login.dart` (OIDC düğmesine isteğe bağlı metin), `desktop_home_page.dart` (bağlantı: `M2yAuth.instance.start()`, `Obx` ile kapı, ID satırında Hızlı Destek menüsü), `src/ui_interface.rs` + `src/flutter_ffi.rs` (yeni bağlar: `main_m2y_auth_expired`, `main_m2y_mark_auth_ok`, `main_m2y_set_connection_gate`), `libs/hbb_common/src/m2y.rs` (saf yardımcılar + birim testleri), `res/m2y/m2ydesk-qs.json`.

**Akış:** Ana sayfa açılışında `M2yAuth.start()`:
- `access_token` yoksa ya da `m2y-last-auth-ok` 7 günden eskiyse (veya hiç yoksa) → giriş ekranı, bağlantı kapısı kapanır.
- Token var ve süre içinde → hemen açılır (çevrimdışı tolerans), `/api/currentUser` arka planda doğrulanır; 200 → `m2y-last-auth-ok` = şimdi; 401 → oturum silinir, giriş ekranı; ağ hatası → süre dolmuşsa giriş ekranı. Doğrulama 30 dakikada bir tekrarlanır. Mevcut `refreshCurrentUser` başarısı da süreyi sıfırlar.
- Ekran 1: e-posta (hatırlanan `m2y-last-email` dolu gelir; "Başka e-posta kullan", "Bu cihazdan e-postamı unut"), "KVKK aydınlatma metni" bağlantısı (`https://desk.mehmetmesut.com/kvkk`), açık rıza kutusu (hatırlanan e-posta varsa işaretli gelir), "Doğrulama kodu gönder"; altında sunucunun OIDC seçenekleri ("Google ile giriş yap", mevcut `/api/oidc/auth` akışı, her iki programda). E-posta kırpılır + küçük harfe çevrilir.
- Ekran 2: 6 haneli kod (6 rakam girilince kendiliğinden gönderilir), "Kodu yeniden gönder" (60 sn geri sayım), "E-postayı değiştir" (solda) / "Doğrula" (sağda), spam notu. Başarıda `access_token` + `user_info` yerel yapılandırmaya yazılır, e-posta `m2y-last-email`'e kaydedilir.
- Ekran 3 (yalnızca `permanent-password-set` false ise, atlanamaz): 6 rakam × 2, `^[0-9]{6}$`; geçersiz girdi silinmez, hata gösterilir; `main_set_permanent_password_with_result`. Hızlı Destek'te "Sürekli erişime izin ver" (varsayılan açık) + bilgilendirme metni.
- Hazır → kapı açılır, ana içerik gösterilir. Çıkış (ayarlar ya da Hızlı Destek menüsü) veya 401 → `userName` boşalır → giriş ekranı.
- Hızlı Destek ID satırında ⋮ menüsü: "Sabit parolayı değiştir", "Sürekli erişimi kapat/aç", "Oturumu kapat". Sürekli erişim açık = `verification-method=use-both-passwords` + `m2y-autostart` boş; kapalı = `use-temporary-password` + `m2y-autostart=N`. Bu yüzden `verification-method` QS yapılandırmasında `override-settings`'ten `default-settings`'e taşındı (değer `use-both-passwords`; Rust `use-both` diye bir değer tanımaz, temp/kalıcı dışındaki her değer "ikisi" sayılır).

**Bağlantı reddi yöntemi — `stop-service` kapısı:** Oturum yokken `ui_interface::m2y_set_connection_gate(true)` mevcut `stop-service=Y` seçeneğini IPC ile yazar. Rendezvous arabulucusu bu seçenekte sunucuya kayıt olmaz (ID çevrimdışı görünür, delik açma/relay isteği gelmez) ve doğrudan IP dinleyicisi (21118) kapanır; seçenek değişince arabulucu kendiliğinden yeniden başlar (`ipc::CheckIfRestart`). Gerekçe: `src/server/**`'a dokunmadan, hazır ve sınanmış bir yolla gelen bağlantının hiç ulaşmaması (bağlantıyı kabul edip reddetmekten daha güvenli; parola denemesi bile yapılamaz). `set_option("stop-service")` kurulu sürümde hizmeti kaldırıp yönetici izni istediği için kullanılmadı; seçenek doğrudan `OPTIONS` + `ipc::set_options` ile yazılır, Windows hizmeti çalışmayı sürdürür. Kullanıcının bilinçli "hizmeti durdur" seçimi korunur: kapıyı bu akış kapattıysa `m2y-gate-stopped=Y` işareti konur, oturum açılınca yalnızca o durumda açılır (`m2y::gate_transition`).

**Bilinen sınırlar / doğrulanmamış varsayımlar:**
- Derlenmedi, çalıştırılmadı; Rust birim testleri (`m2y.rs`: `auth_expiry_window`, `email_and_password_rules`, `gate_transitions`) çalıştırılamadı.
- 7 gün denetimi yalnızca ana pencere (Flutter) açıkken yapılır; yalnızca hizmet/tepsi çalışan kurulu M2YDesk'te pencere açılmadan kapı kapanmaz.
- Uygulama açılışında oturum yoksa kapı kapanana kadar (ilk birkaç yüz ms) arabulucu kayıt olabilir; bir kez kapandıktan sonra `stop-service` yapılandırmada kalıcıdır.
- `stop-service=Y` iken kurulu sürümde açılıştaki sessiz hizmet başlatma (`m2y_try_start_service_on_launch`) atlanır; hizmet o anda çalışmıyorsa oturum açıldıktan sonra "Servisi başlat" gerekebilir. Tepsideki "Hizmeti başlat" kapıyı elle açabilir (istemci tarafı zorlama; asıl zorlama sunucuda olmalı).
- Sunucu belirteç ömrü `RUSTDESK_API_APP_TOKEN_EXPIRE` (varsayılan 168 sa) mutlaksa ve `/api/currentUser` yenilemiyorsa düzenli çevrimiçi cihaz da 7 günde bir 401 alıp yeniden giriş ister.
- `/api/currentUser` 400 dönerse oturum kapatılmaz (yalnızca 401); mevcut `refreshCurrentUser` (tam sürüm) 400'de de çıkış yapar.
- `web/bridge.dart` yeni bağları içermez; web derlemesi yapılırsa `user_model.dart` derlenmez (CI web derlemiyor).
- Cihaz bilgisi onay iletişim kutusu (2 sn) giriş ekranının üstünde açılabilir.
