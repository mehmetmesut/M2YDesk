# Devir Notu (bulut oturumu → yerel oturum)

Bu dosya iki Claude oturumu arasındaki ortak hafızadır. **Yerel oturum ilk iş bunu okusun**, her önemli adımdan sonra "Durum" bölümünü güncelleyip commit/push etsin; bulut oturumu `git pull` ile okur.

## Proje
M2YDesk: RustDesk 1.4.9 tabanlı, kendi sunucuda barındırılan uzaktan destek sistemi. Sürüm **1.0.0**.
- Sunucu/alan adı: **desk.mehmetmesut.com** (Plesk, IP `217.195.207.159`, Plesk paneli `https://217.195.207.159:8443`)
- Depo: `mehmetmesut/M2YDesk` (özel), dal `m2ydesk`
- Ürünler: **M2YDesk** (tam istemci), **M2YDesk QS** (yalnızca ID + şifre, danışanlar için)
- Kullanıcı tercihleri: Türkçe, kısa/net yanıt; Plesk (Linux) + FTP/SFTP; footer kredisi "Yeşil Dönüşüm Mühendisi © Creator M2Y" → https://mehmetmesut.com

## Durum (güncel)
| İş | Durum |
|---|---|
| Sunucu altyapısı (`server/`: docker-compose hbbs/hbbr) | ✅ **sunucuda çalışıyor** (`/opt/m2ydesk/server`, Docker, hbbs+hbbr `-k _`; eski systemd RustDesk servisleri ve birim dosyaları kaldırıldı). TCP 21115-21119 dışarıdan erişilebilir. Depo özel olduğundan `kurulum.sh` yerine eşdeğer komutlar elle uygulandı |
| İstemci kaynağı, markalama, gömülü yapılandırma (`res/m2y/*.json`), ikonlar | ✅ |
| GitHub Actions `m2y-build.yml` — Windows desk+qs, MSI | ✅ ilk derleme geçti (release `m2y-test`, eski adlı 1.4.9 dosyalarıyla) |
| Alt alan adı `desk.mehmetmesut.com` + DNS A kaydı | ✅ yayında |
| **Let's Encrypt SSL** | ✅ yalnızca ana alan adı, 28.12.2026'ya kadar, otomatik yenilenir |
| **İndirme sayfası yayında** | ✅ https://desk.mehmetmesut.com (docroot `/var/www/vhosts/mehmetmesut.com/desk.mehmetmesut.com`). `ayar.js` 1.0.0 adlarıyla; **4 dosya `indir/` altında, SHA-256 release ile doğrulandı, siteden indirilebiliyor** (Android/macOS/Linux yok). Mobilde taşma yok, `/indir/` 403. "QS" etiketi sayfada "Hızlı Destek" oldu |
| GitHub variable `M2Y_SERVER_KEY` | ✅ eklendi (açık anahtar) |
| 1.0.0 derlemesi (anahtar gömülü) | ✅ run #5 başarılı (release `v1.0.0`; #4 `Cargo.lock` uyuşmazlığıyla düşmüştü, `2b9dcd4`). Hızlı Destek ayar girmeden `desk.mehmetmesut.com:21116`'ya kayıt oldu (sunucu günlüğünde görüldü) |
| İki cihaz arası gerçek bağlantı testi | ✅ 29.09.2026 kullanıcı doğruladı: ID+şifre ile bağlantı kuruldu, sorun yok |
| Yönetim katmanı (hesap/API, günlük, sınırlar, süper admin, canlı panel, engelleme) | 📋 plan hazır: `docs/yonetim-katmani-plani.md`; kodlanmadı |
| Android/Linux/macOS derlemeleri, Liquid Glass Flutter teması, kod imzalama | ⏳ sonraki tur |

## Yerel oturumda sırayla yapılacaklar
1. Chrome ile Plesk → `desk.mehmetmesut.com` → SSL/TLS → Let's Encrypt (yalnızca ana alan adı). Sonra `https://desk.mehmetmesut.com` sertifikasını doğrula.
2. SSH ile sunucuda:
   ```bash
   sudo git clone https://github.com/mehmetmesut/M2YDesk.git -b m2ydesk /opt/m2ydesk
   cd /opt/m2ydesk/server && sudo bash scripts/kurulum.sh
   ```
   (Depo özel: GitHub kullanıcı adı + PAT gerekir.) Çıktıdaki **Anahtar** satırını not al.
3. Sağlayıcı/bulut güvenlik duvarında TCP 21115-21119 + UDP 21116 açık mı doğrula.
4. GitHub → Settings → Secrets and variables → Actions → Variables → `M2Y_SERVER_KEY` = anahtar.
5. Actions → "M2YDesk build" → Run workflow: `tag` = `v1.0.0`, `build_windows` açık.
6. Sunucuda `GITHUB_TOKEN=... sudo -E bash scripts/istemci-hazirla.sh` (SITE_DIZINI = Plesk'te desk alt alanının httpdocs yolu) → indirme sayfası dosyaları sunar.
7. Gerçek cihazda M2YDesk QS'i çalıştırıp ID+şifre ile bağlantı testi.

## Bilinen notlar
- Depo özel: Actions dakikaları sınırlı (Windows 2×, macOS 10×). Public yapmak önerildi (AGPL-3.0 zaten kaynak sunmayı gerektirir).
- Windows derlemesi ~65 dk; vcpkg adımı ~21 dk.
- İmzasız exe: SmartScreen uyarısı beklenir.
- Gizli bilgi (PAT, root şifresi, özel anahtar `id_ed25519`) ASLA depoya/sohbete yazılmaz.

## Sorunlar / açık işler (yerel oturum, 29.09.2026)
- **indir/ dosyaları**: depo özel olduğundan release dosyaları sunucuya otomatik inemiyor; Plesk yükleme aracı ~10 MB ile sınırlı (exe'ler ~23 MB). Çözüm: depoyu public yapmak ya da sunucuda `GITHUB_TOKEN` ortam değişkeniyle `istemci-hazirla.sh` çalıştırmak (PAT ayrıca istenecek).
- Eski `m2y-test` 1.4.9 dosyaları anahtarsız derlendi; bu sunucuya bağlanamaz, sayfaya konmadı.
- **Bulut oturumundan istenen iş**: "QS" = "Hızlı Destek". `index.html`'de etiketler yerelde değişti (push edildi); ürün/istemci arayüzündeki adlandırma da gözden geçirilmeli. `kurulum.sh` Docker'ı kendisi kurmuyor; Ubuntu 22.04'te `apt install docker.io docker-compose-v2` yeterli.

## Depo adı (29.09.2026)
`mehmetmesut/RustDesk` → **`mehmetmesut/M2YDesk`** olarak yeniden adlandırıldı (özel, dal aynı). Eski adres GitHub'da yönlendirilir; yeni klonlar `https://github.com/mehmetmesut/M2YDesk.git` kullanmalı, Actions adresleri `/mehmetmesut/M2YDesk/actions/...` olur.

## Bulut uygulama planı (29.09.2026, onay bekliyor)
Görev 1–8'in kod doğrulamalı planı: [`bulut-uygulama-plani.md`](bulut-uygulama-plani.md). Yerel oturumdan istenecek işler planın §2'sinde (ikinci hbbr `:21127`, `guncelleme/` dizini, güncelleme testi, API sunucusu). Onay 29.09.2026 alındı. **Görev 4 ✅** (QS → Hızlı Destek: pencere başlığı `displayAppName`, exe metaverisi, belgeler; iç ad `M2YDeskQS` ve dosya adı `-qs-` değişmedi). **Görev 1 ✅ (kod; derlenmedi, yerel test bekliyor)**: `surum.json` denetimi, SHA-256 doğrulamalı sessiz güncelleme (kurulu Windows), diğerlerinde kart. Ayrıntı: [`guncelleme.md`](guncelleme.md). **Görev 3 ✅ (kod; derlenmedi)**: `hbb_common::m2y` (5 dk sınır, 2 dk bekleme, `engel.json`, relay :21127 yönlendirme; 6 birim testi geçti) + `io_loop`/`client.rs`/`common.rs` bağlantıları. **Kurallar `m2y-nonmember-limit=N` ile KAPALI gönderilir** (üye girişi/API yok; yoksa danışmanın kendi oturumu da 5 dk'da kesilirdi). Ayrıntı: [`uye-kurallari.md`](uye-kurallari.md). **Görev 2 ✅ (kod; derlenmedi)**: sysinfo'ya `mac`, heartbeat kapısı (`m2y-report-device` + `m2y-report-consent`), Flutter onay ekranı, `api-server=https://<sunucu>`; ayrıntı ve plandan sapma (reddederse kapanmaz): [`cihaz-bilgisi.md`](cihaz-bilgisi.md). **Görev 5 ✅**: indirme sayfasına KVKK aydınlatma metni + açık rıza kutusu (işaretlenmeden `indir/` bağlantıları engellenir; 360–1280 px taşma yok, Playwright ile doğrulandı). Metin bilgilendirme amaçlıdır; **hukukçu incelemesi önerilir** (veri sorumlusu adı/iletişim, saklama süresi). **Görev 7 ✅**: [`api-sunucusu-degerlendirme.md`](api-sunucusu-degerlendirme.md) — `lejianwen/rustdesk-api` (MIT) uygun ama **MAC alanı, 2FA ve cihaz engelleme yok** (yama gerekir); web istemci lisansı ❓. **Görev 6 ✅ (inceleme/belge)**: [`android-ios.md`](android-ios.md) — iş akışı hazır ama **kalıcı imza anahtarı Secret'ı yok** → her derleme farklı debug imzalı olur; Android'de cihaz onay ekranı yok (yalnızca masaüstü). iOS: resmi RustDesk + QR. Sıradaki: birleşik derleme (kullanıcı onayı bekleniyor).

## Yeni plan (29.09.2026)
- Pro özelliklerinin kendi çözümümüzle karşılanması planı: [`yonetim-katmani-plani.md`](yonetim-katmani-plani.md). Sıra: Aşama 0 (1.0.0 derleme + dosyalar + ilk bağlantı testi) → 1 (hesap/API sunucusu) → 2/3 (güncelleme, üye/üye olmayan sınırları).
- **Bulut oturumundan istenen iş (Aşama 2/3 istemci kodu):** güncelleme denetimini `desk.mehmetmesut.com/guncelleme/surum.json`'a yönlendirme + sessiz güncelleme; girişsiz kullanıcı için relay `:21127`, 5 dk oturum kesme, 2 dk bekleme; girişli kullanıcı için sınırsız. Ayrıntı planda.
- Derleme #4 `Cargo.lock` uyuşmazlığıyla düştü (portable-packer 1.4.9→1.0.0), düzeltildi (`2b9dcd4`), run #5 çalışıyor.
- **Süper admin gereksinimi (29.09.2026):** `mehmetmesut@gmail.com` Google girişi = süper admin; tüm cihazların ID, IP, MAC, bilgisayar/oturum adı görünür, takma adla adres defterine eklenir. Bulut oturumundan istenen iş: istemci sistem bilgisine MAC adresi eklenmesi + QS'e salt raporlama işlevi. Ayrıntı ve KVKK notu: `docs/yonetim-katmani-plani.md` (satır 10).

## Yerel oturumdan istenen iş — Görev 1 (29.09.2026)
- Sunucuda `server/site/httpdocs/.htaccess` yeni sürümünü (surum/engel.json için no-store) siteye kopyala.
- Sürüm 1.0.1 derlemesinden sonra `istemci-hazirla.sh` çalıştır → `guncelleme/surum.json` + boş `engel.json` oluşur; `guncelleme.md` "Test" adımlarını uygula (özellikle MSI ile kurulu sürüm).
- Not: ana crate bulut ortamında derlenemiyor (gstreamer yok); yalnızca `hbb_common` testleri (`cargo test -p hbb_common m2y`) çalıştı. Derleme hatası çıkarsa Actions günlüğünü DEVIR'e yaz.

## Yerel oturumdan istenen iş — Görev 3 (29.09.2026)
- İkinci hbbr (`:21127`, aynı `-k _`) compose'a eklenecek (dosyayı bulut yazar, sonra uygulanır). **Önce** `docker logs hbbs` ile gerçek bağlantıda hangi akışın kullanıldığını doğrula: `request relay attempt` (denetleyen taraf seçer → :21127 çalışır) mı, `relay requested from peer` (karşı taraf seçer → :21117) mı. Ayrıntı `uye-kurallari.md` §Relay.
- connlimit/iptables ve güvenlik duvarı değişikliği **dışa dönük: kullanıcı onayı şart**.

## Yerel oturumdan istenen iş — Görev 2 (29.09.2026)
- API sunucusu (Görev 7 sonucuna göre) `https://desk.mehmetmesut.com/api/` altında (Plesk nginx proxy) yayına alınmadan yeni sürümü dağıtma. İstemci `/api/heartbeat` ve `/api/sysinfo` (POST, JSON) çağırır.
- Onay ekranını gerçek cihazda dene (Hızlı Destek 280 px pencerede metin taşıyor mu).

## Yerel oturumdan istenen iş — Görev 5 (29.09.2026)
- `server/site/httpdocs/index.html` yeni sürümünü siteye kopyala (`ayar.js`/`indir/` dokunulmaz).

## Yerel oturumdan istenen iş — Görev 7 (29.09.2026)
- `api-sunucusu-degerlendirme.md` §"Önerilen entegrasyon" adımları (Docker + Plesk nginx `/api`, `/_admin`; admin parolası; Google OIDC). Son sürüm/tarihi GitHub'da elle doğrula (bulut ortamından GitHub API 403).
- Kullanıcıdan karar: MAC yaması (fork) yapılsın mı; 2FA için Google 2FA yeterli mi.

## Yerel oturumdan istenen iş — Görev 6 (29.09.2026)
- Kullanıcı Android APK'yı dağıtacaksa `android-ios.md`'deki `keytool` komutuyla **kendi bilgisayarında** keystore üretip 4 GitHub Secret'ı eklemeli (parolaları sohbete/depoya YAZMA). Aksi halde APK'lar arası güncelleme çalışmaz.

## Derleme durumu (29.09.2026) — sürüm 1.0.1
- Run #6 ([Actions](https://github.com/mehmetmesut/M2YDesk/actions/runs/36606176759)): Windows M2YDesk (exe/install/msi) ✅, Hızlı Destek ✅, Linux deb ✅ → release `v1.0.1` yayınlandı. Android ❌ (mac_address/lang::translate Android'de yok) → `5eca200` ile düzeltildi, yalnızca-Android yeniden derleme kuyrukta.
- **Yerel oturumdan istenen iş:** `GITHUB_TOKEN=... sudo -E bash scripts/istemci-hazirla.sh` (v1.0.1; `indir/`, `ayar.js`, `guncelleme/surum.json`, `engel.json`); sonra gerçek Windows cihazda 1.0.0 → 1.0.1 güncelleme testi + onay ekranı (Hızlı Destek 280 px) + bağlantı testi.
- `m2y-nonmember-limit=N` (kapalı) ve API sunucusu yok: cihaz bilgisi onayı çıkar ama sunucuda görünen bir şey olmaz.
- Karar (kullanıcı): Google girişinin 2FA'sı yeterli; `rustdesk-api` fork'lanmayacak (MAC ileride ayrı ince servis). İmzalama (Windows/Apple/Android) Secret'lar eklenince `m2y-build.yml`'ye eklenecek; şimdilik imzasız.

## Hesap + Google girişi (29.09.2026) — hazırlık tamam, sunucu kurulumu yerelde
- İstemci: `m2ydesk.json` → hesap/adres defteri açık, `m2y-nonmember-limit=Y`. **Yeni derleme gerekli (1.0.2), kullanıcı onayı bekleniyor.**
- Sunucu dosyaları (bulut yazdı): `server/docker-compose.yml` (`api`, `hbbr2` profilleri), `server/plesk-nginx.conf.example`, `server/scripts/relay-siniri.sh`. Kurulum/Google adımları: [`hesap-ve-google-girisi.md`](hesap-ve-google-girisi.md).
- **Yerel oturumdan istenen iş (sırayla):** (1) `docker compose --profile api up -d`, nginx yönergeleri, admin parolası; (2) kullanıcı Google OAuth istemcisini kurar, sırları YALNIZCA panele girer; (3) `curl .../api/login-options`; (4) 1.0.1'de giriş + adres defteri + cihaz listesi uçtan uca; (5) `--profile limit` + relay-siniri.sh (**önce kullanıcı onayı**); (6) ancak sonra 1.0.2'yi dağıt.
- Doğrulanmadı: `RUSTDESK_API_*` değişken adları, hbbr `-p` bayrağı, OIDC callback yolu, panelde OIDC ile ilk kullanıcıyı admin yapma.

## Yerel oturum için hazırlık (29.09.2026)
- Tam devam promptu: [`YEREL-DEVAM-PROMPTU.md`](YEREL-DEVAM-PROMPTU.md). Yardımcı betikler: `server/scripts/api-kur.sh`, `dogrula.sh`.
- Android derlemesi: run #7 `get_sysinfo`'da `out` değişkeni `mut` değildi (`a512820` ile düzeltildi), 3. deneme (run #8) kuyrukta; Windows/Linux etkilenmedi.

## Yerel oturum notu (29.09.2026, akşam) — sıradaki işler
- **Yöntem düzeltmesi:** Sunucuda `/opt/m2ydesk` git klonu DEĞİL (dosyalar elle yazıldı). `git pull`/`istemci-hazirla.sh` yerine PAT'sız yol: `server/` → `scp` (data/ ve .env'e dokunulmaz); release dosyaları Chrome ile indirilip `scp`; `ayar.js`, `guncelleme/surum.json`, `engel.json` SHA-256 ile elle üretilir.
- **Yeni iş — site sadeleştirme (kullanıcı isteği):** `server/site/httpdocs/index.html` gereksiz/hatalı/mükerrer bilgilerden arındırılıp sadeleştirilecek; platformlar: Windows (Hızlı Destek), Windows (Kurulum), macOS, Linux, Android, iOS. Doğru içerik (KVKK onay kutusu, QR, SmartScreen/Gatekeeper uyarıları) korunur. Taslak kullanıcı onayına sunulacak. (Bulut bu dosyada değişiklik yapacaksa önce DEVIR'e yazsın, çakışma olmasın.)
- Sıra: site sadeleştirme → Y1 (1.0.1 yayını) → Y2 (API, onaylı) → Y3 (hbbr2, onaylı) → Y4–Y6. Henüz hiçbiri başlamadı.

## Sorun: "Bağlantı Hatası – Eş tarafından sıfırlandı" (30.09.2026) — çözüldü (sunucu)
- Belirti: M2YDesk → Hızlı Destek (ID 39379022, mobil/CGNAT ağ, NAT ASYMMETRIC) bağlantısı ~50 ms sonra `Connection closed: Reset by the peer`. İstemci günlüğü: `TCP Hole Punched ... relay_server: desk.mehmetmesut.com` → doğrudan bağlantı sahte başarılı, ara cihaz kesiyor, relay'e düşülmüyor. hbbr günlüğü o güne kadar hiç bağlantı görmemişti (tüm oturumlar P2P idi).
- Çözüm: hbbs'e `ALWAYS_USE_RELAY=Y` (sunucuda `/opt/m2ydesk/server/docker-compose.yml`, yedek `docker-compose.yml.bak-20260930`; depoda `server/docker-compose.yml`). hbbs yeniden başlatıldı, günlükte `ALWAYS_USE_RELAY=Y`. Tüm trafik artık sunucudan geçer (bant genişliği sunucuya yük); üye olmayan :21127 sınırı da bunu gerektiriyordu.
- İstemci kodu değişmedi; yeniden derleme gerekmez.

## Sorun: "Servis çalışmıyor / Servisi başlat" (04.10.2026) — bulut oturumundan istenen iş
- Kanıt (kullanıcının Windows PC'si, kurulu M2YDesk 1.0.0, `C:\Program Files\M2YDesk`): Windows olay günlüğü (Service Control Manager) her kurulumda aynı deseni gösteriyor: `7045 hizmet yüklendi` → `7009 bağlanma beklenirken zaman aşımı (30000 ms)` → `7000 başlatılamadı` → `7045` yeniden yükleme → çalışıyor. 30.09 kurulumundan sonra hizmet hiç çalışmadı; 04.10 17:35 açılışında da başlamadı (o arada hizmet günlüğü yok). Kullanıcı "Servisi başlat"a basınca (20:49:55) kuruldu ve çalıştı. `stop-service` hiçbir yapılandırmada Y değil (kullanıcı/LocalService profili).
- İstenen (kullanıcı: "servis doğrudan başlatılmalı, uyarı çıkmamalı"):
  1. `src/platform/windows.rs` hizmet kurulumu: başlangıç türü **Otomatik (Gecikmeli)** + hata kurtarma (`sc failure <ad> reset= 86400 actions= restart/5000/restart/10000/restart/30000`), ilk başlatmadaki 30 sn zaman aşımı nedeni (hizmet `StartServiceCtrlDispatcher`'a geç bağlanıyor mu) incelensin.
  2. Arayüz: kurulu sürümde hizmet çalışmıyor ve kullanıcı bilinçli durdurmadıysa (`stop-service` != Y) **sessizce başlat** (`main_start_service` eşdeğeri), "Servisi başlat" bağlantısını yalnızca başarısızlıkta göster.
  3. Kurulum (exe + MSI) sonunda hizmetin çalıştığı doğrulansın.

## Yeni istekler (04.10.2026) — bulut oturumundan istenen iş
- **Üyelik ekranı:** sol gezinme çubuğunun (sol panel "Sizin Masaüstünüz") **altında** üyelik kartı: girişsizken "Üye ol / Giriş yap" (e-posta+parola ve Google), girişliyken ad/e-posta + "Üye: sınırsız" rozeti ve çıkış. Mevcut Ayarlar → Hesap akışını yeniden kullansın (API: `/api/login-options`, `/api/oidc/auth`, `/api/login`). Yalnızca tam istemci (Hızlı Destek'te yok).
- **Sabit (kalıcı) parola:** Tam istemcide zaten var (sol paneldeki kalem simgesi → kalıcı parola; `verification-method` varsayılan `use-both`). Kullanıcı karşı tarafa (danışan) tekrar tekrar parola sormadan bağlanabilmek istiyor → **Hızlı Destek'te** `verification-method` `use-temporary-password` sabit. Öneri: Hızlı Destek'e danışanın **kendi belirleyeceği** isteğe bağlı sabit parola ("Sürekli erişime izin ver" + parola + açık rıza metni, istediği an kaldırma), varsayılan kapalı. Kullanıcı kararı bekleniyor (gözetimsiz erişim = güvenlik/KVKK).

## Yeni özellik: WhatsApp ile ID/parola gönderme (04.10.2026, yerel oturum yazdı — derlenmedi)
- Sol panelde parola bölümünün altında "WhatsApp ile gönder" düğmesi (`desktop_home_page.dart::buildWhatsAppShare`). Tıklanınca `https://wa.me/<numara>?text=M2YDesk uzaktan destek / ID / Parola` tarayıcıda/WhatsApp'ta açılır; gönderimi kullanıcı kendisi onaylar (otomatik gönderim yok).
- Numara koda gömülü değil: gömülü yapılandırmada üst düzey `m2y-whatsapp` (HARD_SETTINGS, `bind.mainGetHardOption`); boşsa düğme gizlenir. İki üründe de `905307302002`.
- Mesaj biçimi: başlık + "ID:" ve "Parola:" etiketlerinin altında değer **kendi satırında, boşluksuz** (çift dokunuşla tek başına seçilip kopyalanır). Parola "-" (yalnızca kalıcı parola modu) ise eklenmez.
- Doğrulama: yerelde Dart/Flutter yok → bir sonraki Actions derlemesinde (kullanıcı onayıyla) derlenip Hızlı Destek 280 px pencerede görünüm kontrol edilecek.

## Derleme kuralı (kullanıcı, 04.10.2026)
- **Ara derleme yok.** Tüm geliştirmeler (WhatsApp düğmesi ✅ kod, hizmet otomatik başlatma, üyelik kartı, sabit parola kararı) bitince **tek bir "gerçek doğrulama derlemesi"** (1.0.2) yapılacak. Bulut oturumu kodunu bitirince DEVIR'e "derlemeye hazır" yazsın; derlemeyi yerel oturum kullanıcı onayıyla başlatır.
- Yerelde Flutter 3.24.5 kuruldu (`C:\tools\flutter`): WhatsApp kodu `dart analyze` → hata yok; `dart format` → yeni satırlar uyumlu (dosyanın eski satırları zaten biçimsiz, dokunulmadı).

## KARAR — Hızlı Destek'te sürekli erişim (sabit parola) (kullanıcı, 04.10.2026) — bulut oturumundan istenen iş
- **İlk açılışta** (onay ekranlarıyla birlikte, kapatılamaz adım) danışandan **6 haneli, yalnızca rakam** sabit parola belirlemesi istenir; parola iki kez girilir (doğrulama). "Sürekli erişime izin ver" **varsayılan AÇIK**.
- Ekranda açık bilgilendirme: "Bu parolayla danışmanınız siz bilgisayar başında olmasanız da bağlanabilir. İstediğiniz an kapatabilir veya değiştirebilirsiniz."
- Sonradan değiştirilebilir: Hızlı Destek'te `disable-settings` olduğundan **ana pencerede küçük bir menü/simge** (ör. parola satırındaki kalem) → "Sabit parolayı değiştir" ve "Sürekli erişimi kapat/aç". Kapalıyken yalnızca tek kullanımlık parola çalışır.
- Uygulama: `m2ydesk-qs.json` `verification-method` → `use-both` (geçici + kalıcı); parola `set_permanent_password` ile; doğrulama `^[0-9]{6}$` (reddedilen girdi temizlenmez, hata gösterilir). Parola sohbete/günlüğe yazılmaz.
- WhatsApp mesajı: sürekli erişim açıkken mesaja **sabit parola eklenmez** (yalnızca ID; danışman parolayı ilk kurulumda bir kez öğrenir) → ❓ kullanıcıya sorulacak; şimdilik tek kullanımlık parola eklenmeye devam eder.
- Güvenlik notu (yerel oturum, kod incelendi): 6 rakam = 1.000.000 olasılık. Mevcut koruma `src/server/connection.rs` `LOGIN_FAILURES`: aynı IP'den 1 dk'da >6 hatada 1 dk bekletme, toplam >30 hatada "Too many wrong attempts" (IP başına, süreç yeniden başlayana kadar). ❓ `ALWAYS_USE_RELAY=Y` sonrası tüm bağlantılar relay'den geldiği için `self.ip` relay (sunucu) IP'si olabilir → sayaçlar herkes için ortak olur, bir saldırgan meşru danışmanı da kilitleyebilir. Bulut: relay'de gerçek karşı taraf IP'sinin kullanıldığını doğrula, değilse sayaç anahtarına peer ID ekle. Varsayılan açık gözetimsiz erişim KVKK aydınlatma metnine eklenecek.

## KARAR — Zorunlu e-posta + kod ile oturum açma (kullanıcı, 04.10.2026) — bulut oturumundan istenen iş
- **Her iki programda** (Hızlı Destek + M2YDesk) açılışta e-posta → e-postaya gelen eşsiz kod → oturum açıldı → sabit parola (6 hane rakam, atlanamaz). **Zorunlu:** oturum yoksa her açılışta sorulur, kod doğrulanmadan ID/parola gösterilmez, bağlantı yok.
- Tam tasarım, sunucu uçları, güvenlik (10 dk, hash, 5 deneme, hız sınırı), SMTP ve riskler: [`eposta-kod-girisi.md`](eposta-kod-girisi.md).
- Bu karar önceki "Hızlı Destek'te hesap yok" kararını **değiştirir**; üye olmayan 5 dk/2 dk kuralları fiilen devre dışı kalır (❓ kullanıcıya soruldu).
- Yerel oturum işi: SMTP hesabı (Plesk posta) + SPF/DKIM/DMARC kontrolü, servis kurulumu (parolayı kullanıcı `.env`'e girer).

## KARAR — Üye olmayan kuralları kaldırıldı (kullanıcı, 04.10.2026)
- Oturum zorunlu → herkes üye. 5 dk / 2 dk ve 5 eşzamanlı oturum kuralı **kaldırıldı**: `res/m2y/m2ydesk.json` `m2y-nonmember-limit` = `N` (Hızlı Destek'te anahtar yok = kapalı; `limits_enabled()` yalnızca "Y" ile çalışır).
- **Y3 iptal:** ikinci relay `hbbr2` (:21127) ve `relay-siniri.sh` kurulmayacak. `ALWAYS_USE_RELAY=Y` kalır (CGNAT sorunu için gerekli). `engel.json` engel listesi kalır.
- Bulut oturumundan istenen iş (düşük öncelik): `m2y.rs` içindeki süre/bekleme/:21127 kodu ve `io_loop`/`client.rs` bağlantıları ölü kod oldu; e-posta girişi işi sırasında temizlenebilir (engel listesi kodu korunmalı). `server/docker-compose.yml` `limit` profili ve `relay-siniri.sh` belgelerde "kullanılmıyor" diye işaretlensin veya kaldırılsın.

## KARAR — Oturum ayrıntıları (kullanıcı, 04.10.2026) — bulut oturumundan istenen iş
- **Çevrimdışı tolerans 7 gün (kayan):** cihaz sunucuya **her ulaştığında 7 günlük süre sıfırlanır**; 7 gün kesintisiz ulaşılamazsa oturum geçersiz (token silinir, giriş ekranı); 401'de hemen kapanır.
- **E-posta hatırlanır:** `m2y-last-email`; giriş ekranında dolu gelir, birincil düğme "Doğrulama kodu gönder" (teşvik); "Bu cihazdan e-postamı unut" seçeneği.
- **Google ile giriş her iki programda** (M2YDesk + Hızlı Destek) ek seçenek; e-posta+kod birincil.
- Ayrıntı: `eposta-kod-girisi.md` (Kararlar/İstemci akışı, Sonuçlar 2–3).

## KARARLAR — Güvenlik ve destek özellikleri (kullanıcı, 04.10.2026) — bulut + yerel oturum işi
Tam tasarım: [`guvenlik-ve-destek-ozellikleri.md`](guvenlik-ve-destek-ozellikleri.md). Özet:
1. Hızlı Destek: sürekli erişim açıkken **Windows açılışında otomatik başlatma** (tepsi).
2. **Yalnızca yetkili hesaplardan bağlantı:** `mehmetmesut@gmail.com`, `mehmetmesut.yilmaz@antalya.edu.tr` + panelden eklenecek danışmanlar; API'nin verdiği Ed25519 imzalı kısa ömürlü belirteçle doğrulama (istemciye açık anahtar gömülü).
3. **Sunucu izleme ve alarm** (hbbs/hbbr/API/HTTPS/SSL<14 gün/disk/trafik) → e-posta + WhatsApp (CallMeBot; anahtarı kullanıcı `.env`'e girer). Yerel oturum işi.
4. **SmartScreen:** ücretsiz kesin yol yok Türkiye'den bireysel olarak; en iyi ücretsiz yol Hızlı Destek'i **Microsoft Store (MSIX)** ile yayınlamak; SignPath ücretsiz ama depo açık + yayıncı "SignPath Foundation"; Azure Artifact Signing TR'ye kapalı. Kısa vade: her sürümde WDSI gönderimi.
5. **İmzalı `surum.json`/`engel.json`** (Ed25519; imza CI/kullanıcı bilgisayarında, sunucuda değil).
6. **"Destek iste"** düğmesi + bildirim ("X kuruluşundan Ayşe destek bekliyor") + panelden tek tıkla bağlan; WhatsApp düğmesi kalır.
7. **Oturum kaydı + aylık Excel/PDF rapor** (kim, ne zaman, süre, not).
8. **Görünür bağlantı çerçevesi** "Danışmanınız bağlı" + "Bağlantıyı kes" → "Emin misiniz?" onayı.

## Yerel oturum üstlendi (04.10.2026) — bulut bu işleri YAPMASIN
- **İmzalı surum.json/engel.json (Ed25519)** — istemci doğrulaması + `server/scripts/imzala.py` + CI değişkeni `M2Y_UPDATE_PUBKEYS` (yerel, ajanla).
- **Sunucu izleme/alarm** — `server/scripts/izleme.sh` + systemd timer; bildirim: e-posta + **ntfy** (CallMeBot yerine: ücretsiz, açık kaynak, hesap gerektirmez; gizli konu adı `.env.izleme`'de).
- **İndirme sayfası sadeleştirme** — `server/site/httpdocs/index.html` (6 platform).
- **Gönderen posta:** `m2ydesk@mehmetmesut.com` — kurulum betiği sunucuda `/root/m2y-posta-kur.sh` (parola rastgele, ekrana yazılmaz, `/opt/m2ydesk/server/.env.smtp` 600); **kullanıcı kendisi çalıştıracak**. DNS: SPF/DKIM(`default`)/DMARC(`p=quarantine`) mevcut, 587 açık.

## Tamamlandı (yerel, 04.10.2026) — imzalı güncelleme, izleme, site
- **İmzalı `surum.json`/`engel.json`** (Ed25519, ayrık `.sig`): `hbb_common::m2y::verify_detached`/`verify_signed` (+birim testi), `src/common.rs` `.sig` indirip doğrular (imzasız/bozuksa güncelleme yok, engel listesi uygulanmaz), `build.rs` + `m2y-build.yml` `M2Y_UPDATE_PUBKEYS`, `server/scripts/imzala.py` (anahtar-uret/imzala/dogrula; PyNaCl ile çapraz doğrulandı). **Rust derlenmedi** → 1.0.2 doğrulama derlemesinde kontrol. Kullanıcı işi: anahtar çifti üret (kendi PC'si), açık anahtarı `M2Y_UPDATE_PUBKEYS` Variable'ına ekle; her yayında `.sig` üret. Bilinen sınır: imzada zaman damgası yok (eski imzalı dosya yeniden sunulabilir).
- **İzleme:** `server/scripts/izleme.sh` + `izleme-kur.sh` sunucuya kopyalandı (LF), elle bir kez çalıştırıldı: 8 denetimin hepsi OK. Zamanlayıcıyı **kullanıcı** kuracak (ntfy konu adı yalnızca onun terminalinde görünsün). `.gitattributes`: `*.sh eol=lf`.
- **Site:** `index.html` sadeleştirildi (6 platform, KVKK kutusu korunarak, tekrarlar/hatalar kaldırıldı); depoda, **yayın kullanıcı onayı bekliyor**.

## Yapıldı (yerel, 04.10.2026 akşam)
- **Sadeleştirilmiş indirme sayfası yayında** (`index.html` + `.htaccess`; eski sürümler sunucuda `varsayilan-yedek/index-20261004.html`, `htaccess-20261004.txt`). Canlı denetim: başlık doğru, 6 sekme, taşma yok, Hızlı Destek/Kurulum/MSI bağlantıları HTTP 200.
- **Güncelleme imza anahtarı üretildi:** özel anahtar kullanıcının PC'sinde `%USERPROFILE%\.m2ydesk\m2y-imza.pem` (yalnızca kullanıcı erişimi; depoda/sunucuda yok). Açık anahtar GitHub Variable **`M2Y_UPDATE_PUBKEYS`** = `qrRkSEUtfpoBb08T/qU2EskGPZzwCG+SpxJoDiBM448=` olarak eklendi. Her yayında `imzala.py imzala <surum.json|engel.json> --anahtar <pem>` ile `.sig` üretilip sunucuya yüklenecek (yerel oturum).

## Yapıldı (yerel, 04.10.2026 gece) — posta, izleme, SSH güvenliği
- **Gönderen posta `m2ydesk@mehmetmesut.com` kuruldu** (kullanıcı Plesk SSH Terminali'nden `/root/m2y-posta-kur.sh` çalıştırdı). SMTP ayarları `/opt/m2ydesk/server/.env.smtp` (600; parola rastgele, hiç gösterilmedi). Gmail'e teslim doğrulandı (`status=sent 250 OK`). E-posta+kod girişi bu SMTP'yi kullanacak.
- **İzleme zamanlayıcısı aktif** (`m2y-izleme.timer`, 5 dk). Test alarmları hem **ntfy** hem **e-posta** ile teslim edildi. ntfy konusu sunucuda `.env.izleme`'de (kullanıcıya iletildi).
- **SSH sertleştirme** (kullanıcı `/root/m2y-guvenlik.sh` çalıştırdı): root yalnızca anahtarla (`PermitRootLogin prohibit-password`, drop-in `/etc/ssh/sshd_config.d/99-m2y-sertlestirme.conf`), `MaxAuthTries 3`, `LoginGraceTime 30`; fail2ban 3 hata → 24 sa (pencere 1 sa); `62.238.13.104` (Hetzner/Helsinki, yalnız başarısız deneme) kalıcı engelli; kullanıcının ev (88.232.174.141) ve iş (185.33.62.141) IP'leri güvenilir listede. Diğer site kullanıcılarının SFTP parola girişine dokunulmadı. Geri alma: `bash /root/m2y-guvenlik.sh geri-al`.

## Y2 — Hesap API'si canlıda (yerel, 04.10.2026 gece)
- `m2y-api` (lejianwen/rustdesk-api) Docker'da `127.0.0.1:21114`, veri `/opt/m2ydesk/server/data/api`. README ile değişken adları **doğrulandı**; düzeltmeler: `LANG=en` (tr desteklenmiyor), `GIN_TRUST_PROXY=127.0.0.1`, `CAPTCHA_THRESHOLD=3`, `BAN_THRESHOLD=5`.
- Plesk nginx: `/var/www/vhosts/system/desk.mehmetmesut.com/conf/vhost_nginx.conf` (+`httpdmng --reconfigure-domain`, `nginx -t` OK). Dışarıdan `GET /api/login-options` → 200; `/_admin/` yalnızca ev+iş IP'leri (başka IP → 403 doğrulandı).
- OIDC geri dönüş adresi (README): `https://desk.mehmetmesut.com/api/oidc/callback`.
- **Kullanıcı işi:** ilk admin parolasını kendisi okuyup değiştirsin (`docker logs m2y-api 2>&1 | grep -i password` — sohbete yapıştırmasın); Google OAuth istemcisini kurup Client ID/Secret'ı yalnızca panele girsin.
- `izleme.sh` m2y-api kapsayıcısını ve 21114'ü artık otomatik denetler (kapsayıcı var).

## Y6 — Yedekleme (yerel, 04.10.2026 gece)
- `yedekleme.sh` genişletildi: artık **hesap API veritabanı** (`data/api/rustdeskapi.db`) ve `.env`, `.env.smtp`, `.env.izleme`, `docker-compose.yml` de yedekleniyor (sırlar içerir → arşiv 600). Tutarlılık için hbbs + m2y-api birkaç saniye durdurulup başlatılıyor (relay oturumları etkilenmez). Arşiv yolları proje köküne göre (`data/...`); `geri-yukleme.sh` hem yeni hem eski yapıyı açar, API'yi de başlatır.
- İlk yedek alındı: `/opt/m2ydesk/server/yedekler/rustdesk-yedek-20261004-231850.tar.gz` (11 dosya). Cron: her gece **03:15** (`/var/log/m2y-yedek.log`), 30 gün saklama.
- ⚠️ Yedekler aynı sunucuda; sunucu dışı kopya henüz yok (öneri: Plesk Yedekleme Yöneticisi → harici depolama veya kullanıcının şifreli Drive'ı).
- `dogrula.sh`: iptal edilen hbbr2/21127 denetimi çıkarıldı, API portu 21114 eklendi. Kalan 2 ✘: `surum.json`, `engel.json` (Y1 ile imzalı üretilecek).

## Y1 hazırlığı — tarayıcısız yayın (yerel, 04.10.2026 gece)
- Chrome eklentisi yanıt vermediği ve depo özel olduğu için kalıcı yol: **sunucu release dosyalarını kendisi indirir.** Kullanıcı GitHub'da yalnızca `mehmetmesut/M2YDesk` için **Contents: Read-only** fine-grained belirteç oluşturur ve Plesk SSH Terminali'nde `bash /opt/m2ydesk/server/scripts/github-belirtec-kaydet.sh` ile girer (`read -s`, doğrulanır, `/opt/m2ydesk/server/.env.github` 600; ekrana/günlüğe yazılmaz). `istemci-hazirla.sh` ortamda yoksa bu dosyadan okur; ürettiği dosyaların sahipliğini siteyle eşitler. `.env.github` gece yedeğine dahil.
- Sonra (yerel oturum): `SITE_DIZINI=/var/www/vhosts/mehmetmesut.com/desk.mehmetmesut.com M2Y_SURUM=v1.0.1 bash scripts/istemci-hazirla.sh` → `surum.json`/`engel.json` PC'ye alınıp denetlenir, `imzala.py` ile imzalanır, `.sig` yüklenir.

## Yerel oturum üstlendi (04.10.2026 gece, ajanlarla) — bulut bu işleri YAPMASIN
1. **Hizmet otomatik başlatma + Hızlı Destek Windows açılışında başlatma** (`src/platform/windows.rs`, `desktop_home_page.dart` hizmet/başlangıç kısmı).
2. **Bağlantı çerçevesi "Danışmanınız bağlı" + "Bağlantıyı kes" → "Emin misiniz?"** (bağlantı yöneticisi / cm penceresi).
3. **Araştırma:** `lejianwen/rustdesk-api` ile e-posta+kod girişi ve imzalı yetki belirteci nasıl entegre edilir (kaynak kod incelemesi; belge `docs/api-entegrasyon-arastirma.md`).
Bulut için kalanlar: e-posta+kod giriş ekranı (istemci), sabit parola ilk açılış akışı, üyelik kartı, yetkili hesap doğrulaması (istemci), "Destek iste", oturum kaydı/rapor.

## Tamamlandı (yerel ajanlar, 04.10.2026 gece) — derlenmedi, 1.0.2 doğrulama derlemesinde denetlenecek
- **Bağlantı göstergesi** (`server_page.dart`): danışanın cm penceresinde kırmızı şerit "Danışmanınız bağlı — <ad>" + "Bağlantıyı kes" → onay (Vazgeç solda, Evet kes sağda; Enter/Esc=Vazgeç); eski Disconnect da onaylı. Ekran kenarı çerçevesi YOK (yerel katmanlı pencere gerekir; sonraki tur). Belge: `baglanti-gostergesi.md`.
- **Hizmet sorunu kök neden:** 7009/7000, kurulum betiğinin geçici `--import-config` hizmetinden (bilinçli, zararsız). Açılışta başlamama nedeni kesin değil (Defender taraması / hizmet yok). Değişiklikler (`windows.rs`, `core_main.rs`, `flutter_ffi.rs`, `connection_page.dart`): hizmet **Otomatik (Gecikmeli)** + hata kurtarma (5/10/30 sn yeniden başlat) + etkileşimli kullanıcıya yalnız **başlatma (RP)** izni (SDDL incelendi: durdurma/silme yok); açılışta bir kez sessiz başlatma denemesi (UAC yok, en çok 15 sn), başarısızsa "Servisi başlat" görünür. 1.0.0 kurulumlarında eski izinler → bağlantı bir kez görünür.
- **Hızlı Destek otomatik başlatma:** `HKCU\...\Run` (her açılışta exe yoluna eşitlenir; `m2y-autostart=N` kaldırır). Pencere açık başlar (gizli başlatma argümanı yok). Belge: `hizmet-ve-otomatik-baslatma.md`.
- Derleme riski: `windows-service` 0.6 ve `winreg` çağrıları, `update_me` format! argümanı.

## API entegrasyon araştırması (yerel ajan, 04.10.2026 gece) — `api-entegrasyon-arastirma.md`
- rustdesk-api'de **SMTP / e-posta kodu girişi / "kullanıcı adına belirteç" ucu YOK**; istemcinin `email_check`/`email_code` diyaloğu hazır ama sunucu karşılığı yok → **öneri: rustdesk-api fork + yalıtılmış `m2y` Go paketi** (~3 gün yalnız e-posta kodu; tüm kalemler ~15–16 gün).
- OIDC: kullanıcı otomatik oluşur, `email_verified` bakılmaz (yama gerek); e-postayla otomatik admin ayarı yok; `isProtected` yok.
- Denetim: `/api/audit/conn` (new/close) saklanıyor ama e-posta/kuruluş/not yok ve uçlar **kimliksiz** (sahtelenebilir).
- Yetki belirteci: `LoginRequest`'te boş alan yok → `message.proto`'ya `bytes m2y_auth = 100` (geriye uyumlu); öneri: **hedef cihaza bağlı, ≤5 dk ömürlü** belirteç.
- Upstream ~1 yıldır durağan → fork bakımı bizde. Kararlar bekliyor: fork açılması (özel depo), belirteç biçimi, Vue panel fork'u.

## KARAR + başladı — m2y-api fork'u (kullanıcı, 05.10.2026)
- **Fork onaylandı:** özel depo **`mehmetmesut/m2y-api`** (lejianwen/rustdesk-api `c5687e1`, MIT; `upstream` uzak adı korunur). Yerel klon: `C:\Users\Mmy\Desktop\YazılımProjelerim\m2y-api`.
- **Belirteç kararı:** yetkili hesap belirteci **hedef cihaza bağlı, 5 dk ömürlü**, Ed25519 imzalı (`proto`'ya `bytes m2y_auth = 100`; istemci tarafı bulut/sonraki aşama).
- **Aşama 1 (yerel, Opus ajanı, sürüyor):** e-posta+kod girişi (`/api/m2y/kod-gonder`, `/api/m2y/kod-dogrula`, SMTP ortam değişkenleri, HMAC'li kod, hız sınırları), `M2Y_ADMIN_EMAILS` ile otomatik ve korumalı admin, OIDC `email_verified` zorunluluğu, `/api/m2y/yetki` belirteç ucu. Derleme/test sunucuda geçici `golang:1.23` kapsayıcısında.
- Sonraki aşamalar: Destek iste (talep tablosu + bildirim), oturum kaydı/rapor (kimlikli audit, not, Excel/PDF), MAC alanı, Vue panel ekranları; istemci: e-posta+kod ekranı, `m2y_auth` doğrulaması.

## KALDIĞIMIZ YER (05.10.2026 sabah, kullanıcı bilgisayarı kapattı)
- m2y-api Aşama 1 ajanı **yarıda kaldı**. Ara kayıt: `mehmetmesut/m2y-api` dalı **`m2y-asama1-wip`** (`bf3a45f`, derlenmemiş/test edilmemiş olabilir; `main` değişmedi). Yeni oturumda: dalı incele → eksikleri tamamla → sunucuda `golang:1.23` ile `go build/vet/test` → `main`'e birleştir → sunucuda API'yi güncelle. Sunucuda `/root/m2y-api-derleme` geçici klasörü kalmış olabilir (sil).
- ruskdesk deposunda push edilmemiş iş yok.

## m2y-api Aşama 1 CANLIDA (yerel, 05.10.2026)
- Fork `mehmetmesut/m2y-api` `main` = `ab9a6ea` (Opus ajanı: f6ce7da, 056ecb6, c055d6d; yerel güvenlik düzeltmesi ab9a6ea: korumalı hesabın parolasını yalnız sahibi değiştirir, e-posta başına günde ≤10 kod → tahmin üst sınırı 50/gün). 66 test geçti (46 M2Y). `m2y-asama1-wip` dalı artık gereksiz.
- Sunucuda derleme: `scripts/m2y-api-guncelle.sh` (kaynak `/root/m2y-api-derleme`, golang:1.23 statik ikili, panel arayüzü çalışan kapsayıcıdan kopyalanır, imaj `m2y-api:yerel`). Sırlar `/opt/m2ydesk/server/.env.m2yapi` (600, rastgele üretildi, gösterilmedi; gece yedeğine dahil): `M2Y_KOD_SIRRI`, `RUSTDESK_API_JWT_KEY`, `M2Y_YETKI_ANAHTARI` (Ed25519), SMTP (Postfix, `host.docker.internal:587`). Yöneticiler: mehmetmesut@gmail.com, mehmetmesut.yilmaz@antalya.edu.tr. Geçiş öncesi DB yedeği `yedekler/rustdeskapi-oncesi-*.db`. Geri dönüş: `M2Y_API_IMAJ=lejianwen/rustdesk-api:latest docker compose --profile api up -d api`.
- Uçtan uca: `POST /api/m2y/kod-gonder` → 200 ve Gmail'e teslim (`status=sent`); yanlış kod → 400; `/api/m2y/yetki-acik-anahtar` → 200; `/_admin/` → 200 (izinli IP).
- **Bulut için:** istemciye gömülecek yetki açık anahtarı `GET https://desk.mehmetmesut.com/api/m2y/yetki-acik-anahtar` (base64). Belirteç biçimi ve imza ayrıntısı: m2y-api `docs/m2y.md`. İstemci tarafı (e-posta+kod ekranı, `m2y_auth` proto alanı ve doğrulama) bulut/sonraki iş.
- Açık güvenlik notları (m2y.md): yetki belirteci 5 dk içinde aynı hedefte yeniden kullanılabilir; IP sınırı bellek içi; IPv6 /64 gruplaması yok.

## KARAR — Bulut oturumu KULLANILMIYOR (kullanıcı, 05.10.2026)
Tüm geliştirme **yerel oturumda** sürer. Daha önce "bulut oturumundan istenen iş" diye yazılan maddelerin hepsi yerelin işidir. Yerel iş planı (ajanlarla, paralel, dosya sınırları ayrık):
- **A (Opus):** zorunlu e-posta+kod giriş ekranı (iki program; Google ek seçenek; 7 gün kayan oturum; e-posta hatırlanır) + ilk açılışta 6 haneli sabit parola (atlanamaz, sürekli erişim varsayılan açık; Hızlı Destek'te değiştir/kapat menüsü).
- **C (Opus):** yetkili hesap belirteci `m2y_auth` (proto alanı, denetleyici `/api/m2y/yetki`'den alır, kontrol edilen taraf gömülü açık anahtarla doğrular, yetkisizi reddeder).
- **E (Sonnet):** m2y-api Aşama 2 (Destek iste talepleri + bildirim, kimlikli oturum kaydı + not + aylık Excel/PDF, MAC alanı).
- Sonra: üyelik kartı + "Destek iste" düğmesi (istemci), ekran kenarı çerçevesi, 1.0.2 tek doğrulama derlemesi.

## Yönetim paneli girişi (yerel, 05.10.2026)
- Kalıcı kural (kullanıcının tüm projeleri): sabit yönetici **mehmetmesut@gmail.com** hesabı m2y-api'de oluşturuldu (id 2, yönetici, korumalı; parola bcrypt). Kurulum idempotent: `python3 /opt/m2ydesk/server/scripts/yonetici-hesabi.py` (varsa dokunmaz). Yerleşik `admin` hesabına rastgele parola atandı → `/opt/m2ydesk/server/.env.m2yadmin` (600, gösterilmedi; gece yedeğine eklenecek).
- Kısa adres: **https://desk.mehmetmesut.com/yonetici** → `/_admin/` (302). Panelin kendisi hâlâ yalnız ev+iş IP'lerine açık (izinsizde 403). Panel arayüzü hash yönlendirmeli (`#/login`) olduğu için adres çubuğunda `/_admin/#/...` görünmesi arayüz derlemesi değişmeden önlenemez.

## Y1 — 1.0.1 YAYINDA (yerel, 05.10.2026)
- GitHub fine-grained belirteç (yalnız M2YDesk, Contents RO, süresiz — kullanıcı tercihi) sunucuda `.env.github` (600). `istemci-hazirla.sh` ile v1.0.1: Windows QS/exe/install/msi + **Linux deb + Android APK** `indir/` altında; `ayar.js` güncel.
- **Hata bulundu ve düzeltildi:** indirme isteğinde iki `Accept` başlığı (vnd.github+json + octet-stream) gittiği için GitHub dosya yerine 1,8 KB JSON meta veri döndürüyordu → site kısa süre bozuk dosya sundu. Düzeltme: indirmede yalnız octet-stream + yetki; JSON gelirse dosya reddedilir (`.indiriliyor` geçici adı). Yeniden indirildi; 6 dosyanın SHA-256'sı GitHub release ile **birebir** (tarayıcıdan bağımsız doğrulandı).
- `surum.json` (1.0.1) ve `engel.json` kullanıcının PC'sinde denetlenip `imzala.py` ile imzalandı, `.sig` yüklendi; `dogrula.sh` → hiç ✘ yok.
- Her yeni sürümde aynı akış: sunucuda `istemci-hazirla.sh` → PC'ye `surum.json` al → GitHub hash'leriyle karşılaştır → imzala → `.sig` yükle.

## İstemci: giriş kapısı + yetki belirteci kodlandı (yerel ajanlar A ve C, 05.10.2026) — DERLENMEDİ
- `a2d5b64` (C): `LoginRequest.m2y_auth = 100`; denetleyici `/api/m2y/yetki`'den hedefe bağlı 5 dk belirteç alır (yalnız doğrulanan TLS); kontrol edilen taraf `m2y-require-auth=Y` iken parola denetiminden ÖNCE `verify_m2y_auth` ile doğrular, değilse reddeder (sayaç artar). Derlemede `M2Y_AUTH_PUBKEYS` (GitHub var eklendi). Etki: stok RustDesk ve 1.0.0/1.0.1 istemciler 1.0.2'ye bağlanamaz; IP ile doğrudan bağlantı reddedilir. Belge: `yetki-belirteci.md`.
- `56ab5bb` (A): `m2y_login_gate.dart`/`m2y_auth.dart`/`m2y_fixed_password.dart`: oturum yoksa giriş ekranı (hatırlanan e-posta, KVKK rızası, kod, Google), 7 gün kayan oturum (`/api/currentUser` 30 dk'da bir), 401'de çıkış; ilk girişte 6 haneli sabit parola; QS'te sürekli erişim varsayılan açık (`verification-method`=`use-both-passwords`, default-settings'e taşındı). Oturum yokken `stop-service=Y` ile cihaz kayıt olmaz (gelen bağlantı ulaşmaz).
- Bilinen sınırlar: `generated_bridge.dart` olmadan yeni bind adları analizde denetlenmedi; web derlemesi kırılabilir (CI web derlemiyor); tepsi "Hizmeti başlat" kapıyı elle açabilir (yine de C belirteci olmadan bağlanılamaz).

## m2y-api Aşama 2 CANLIDA (yerel, 05.10.2026)
- Fork main `328e198` (ajan E): `POST /api/m2y/talep` (Destek iste; 10 dk'da 3), `GET /api/m2y/talepler`, `POST /api/m2y/talep/:id/durum`, `POST /api/m2y/profil` (kuruluş), `POST /api/m2y/oturum` (başlangıç/bitiş, 12 sa'da kapanmayan "bitiş bilinmiyor"), `POST /api/m2y/oturum/:uuid/not`, `GET /api/m2y/rapor?ay=YYYY-MM&bicim=xlsx|pdf|json` (yalnız admin), MAC `peers.mac`, migrasyon 267. 29 yeni test geçti. PDF: fpdf + gömülü DejaVu (lisans `service/m2yfont/LICENSE.txt`).
- Destek talebi bildirimi: e-posta (admin+yetkili) + ntfy (`M2Y_NTFY_URL`, izleme konusuyla aynı; `.env.m2yapi`'ye eklendi).
- Uçtan uca (sabit hesapla): giriş, profil, talep (e-posta `status=sent` + ntfy "…destek bekliyor"), talepler, oturum başlangıç/bitiş/not, xlsx (PK) ve pdf (%PDF-) rapor → hepsi 200. Test talebi #1 kapatıldı; test oturumu raporda "TEST notu" ile görünür.
- **İstemci tarafı (sıradaki):** denetleyici oturum başında/sonunda `/api/m2y/oturum` çağırsın + bitişte not penceresi; Hızlı Destek'te "Destek iste" düğmesi (`/api/m2y/talep`); panelde talepler/rapor ekranı (Vue fork yok → şimdilik `/api/m2y/rapor` doğrudan indirme).

## KARAR — Zorunlu güncelleme (kullanıcı, 05.10.2026) — İSTEMCİ KODLANDI (`6ad4f82`, derlenmedi)
Danışanlara güncelleme bildirimi + güncel sürümü yükleme zorunluluğu. Tasarım: `guncelleme.md` → "Zorunlu güncelleme" (imzalı `surum.json` `asgari_surum`, engelleyici pencere, kurulu sürümde sessiz güncelleme, taşınabilir/QS'te kendini değiştirme, API `/api/m2y/yetki`'de sürüm denetimi).

## Yönetim paneli /yonetici + canlı test + Türkçeleştirme (yerel, 05.10.2026)
- Panel artık **doğrudan** `https://desk.mehmetmesut.com/yonetici/` altında sunuluyor (nginx `proxy_pass …/_admin/`; panel arayüzü göreli yol, API mutlak `/api/admin`). `/yonetici` ve eski `/_admin/` → 301 `/yonetici/`. Yalnız ev+iş IP (diğerleri 403). Güvenlik başlıkları: X-Frame-Options DENY, nosniff, Referrer-Policy.
- Chrome'da canlı tarama: 22 sayfa (kişisel cihazlar, adres defterleri, etiketler, paylaşım/giriş kayıtları, kullanıcı/grup/cihaz grubu yönetimi, OAuth, belirteçler, denetim günlükleri, sunucu komutu) + Filtrele/Ekle formları + Sunucu komutu'ndaki tüm Yenile düğmeleri → başarısız API isteği, JS hatası, hata bildirimi **yok**. Not: arka plan sekmesinde rAF/geçişler durur; tarama `requestAnimationFrame`'i Worker zamanlayıcısına bağlayarak yapıldı (yoksa içerik ilk sayfada kalır ve sahte "temiz" sonuç çıkar).
- **Düzeltildi — "dial tcp 127.0.0.1:21117: connection refused"** (Sunucu komutu): API köprü ağdaydı → `network_mode: host` + `RUSTDESK_API_GIN_API_ADDR=127.0.0.1:21114`, SMTP 127.0.0.1 (`b0f3361`). ID/aktarma durumu "Kullanılabilir"; 21114 dışarıdan kapalı.
- **Türkçe + M2YDesk markası CANLIDA:** m2y-panel `92bba6c`+ (tek dil tr, "M2YDesk Yönetim", M2Y logosu), m2y-api `489cf1e` (tr.toml, LANG=tr, Accept-Language yok sayılır), `ecc57b6` (sunucu komutu açıklamaları), `0739866` (doğrulama iletilerinde alan adları Türkçe: "Ad zorunlu bir alandır"). DB: gruplar "Varsayılan grup"/"Paylaşım grubu", admin takma adı "Yönetici". Dağıtım: `m2y-panel/dist` → `/root/m2y-panel-dist`, m2y-api `git archive` → `/root/m2y-api-derleme`, sonra `m2y-api-guncelle.sh`.
- (Çözüldü, yukarıda) Eski sorun: panel Türkçe değil (dil seçenekleri zh/en/fr/ko/ru/es/zh-TW; açılışta Çince karşılama). Kullanıcı kuralı: **panel yalnız Türkçe**. Panel kaynağı özel fork **`mehmetmesut/m2y-panel`** (lejianwen/rustdesk-api-web, MIT; yerel `YazılımProjelerim\m2y-panel`). Ajan I: tr.json + tek dil Türkçe + Element Plus tr + marka "M2YDesk Yönetim" + API `resources/i18n/tr.toml`. Sonra: `m2y-api-guncelle.sh` panel arayüzünü kapsayıcıdan değil m2y-panel derlemesinden alacak.

## Panel yeniden tasarımı CANLIDA (yerel, 05.10.2026) — m2y-panel `213327a`
- Yön: **siber/teknik** (koyu varsayılan + açık tema; neon yeşil `--accent`, camgöbeği `--accent-2`; Space Grotesk + JetBrains Mono variable, `@fontsource-variable`, kendi sunucudan). Belirteçler `src/styles/tokens.scss`, Element Plus eşlemesi + işlem butonu kuralları `src/styles/theme.scss`.
- Sabit kutu iskelet: `.shell` 100dvh, yalnız `.main` kayar (Lenis); başlık+sekmeler aşağı kaydırırken gizlenir, yukarıda belirir. Önizlemeli menü (hover kartı, `menu/previews.js`).
- Hareket (`src/fx/`): GSAP+ScrollTrigger+Lenis+SplitType; yalnız transform/opacity; imleç lerp + manyetik düğme + eğim yalnız `(hover:hover) and (pointer:fine)`; `prefers-reduced-motion`'da kapalı. Açılış perdesi (çift kapı) `index.html` + `fx/boot.js`.
- Giriş: 100dvh hero, karakter bazlı başlık, clip-path yüzen şekiller + imleç paralaksı. Ana sayfa: hero + paralaks + **sabitlenen yatay galeri** (pinSpacing kapalı; kaydırma uzunluğunu `.rail-wrap` yüksekliği verir — ScrollTrigger flex ebeveynde pinSpacing'i uygulamıyordu).
- İşlem butonu kuralı: onay → altta sağ, olumsuz → altta sol (dialog/MessageBox/form sonu CSS ile), tablo hücresinde Sil solda/Düzenle sağda, düzenleme düğmesi kartın üstünde sağda (info.vue). "Ekle" düğmeleri `type=success`.
- Dağıtım: `m2y-panel` → `npm run build` → dist tar → `/root/m2y-panel-dist` → `m2y-api-guncelle.sh` (hızlı deneme için `docker cp` ile çalışan kapsayıcıya). Önceki dist: `/root/m2y-panel-dist.onceki.tgz`.
- Doğrulama: 22 sayfa + ekleme formları Chrome'da temiz (0 API hatası, 0 JS hatası). Not: arka plan sekmesinde `requestAnimationFrame` durur; tarama için rAF'ı Worker zamanlayıcısına bağla.

### Güncelleme (05.10.2026, kullanıcı geri bildirimi) — panel SADE + KOMPAKT (m2y-panel `e048ba1`)
Kullanıcı: "Fixed-Box, daha minimalist, kompakt, verimli; mouse ikonu değişmesin". Önceki sürümdeki özel imleç, manyetik düğme, hero, sabitlenen galeri, menü önizlemesi, gren, GSAP/Lenis/SplitType **kaldırıldı**. Şimdi: 14px taban, 208px kenar çubuğu, 48+36px üst çubuk, 24px alt çubuk; sayfa kaymaz — liste sayfalarında sorgu kutusu / tablo kutusu (`el-table height=100%`, iç kaydırma) / sayfalama kutusu sabit; ana sayfa 3 kutu ızgara. Buton kuralları aynen sürüyor (onay altta sağ, olumsuz altta sol, düzenle üstte sağ). Doğrulama: 22 sayfa temiz, hiçbir sayfada sayfa-kaydırma yok.

### Güncelleme 2 (05.10.2026) — BOXED çerçeve + üst gezinme + Calibri (m2y-panel)
Kullanıcı: ekranın tamamı kullanılmasın, yanlarda boşluk (boxed); sol menü üst navbar'a; ana başlık → alt başlık yeniden kurgu; tüm sistemde Calibri. Yapıldı: `.frame` 1360px (`--frame-w`) ortalı kutu, dış zemin `--bg-outer`; üst nav `src/layout/nav.js` (Ana sayfa · Cihazlar · Adres defteri[Benim/Tümü] · Kullanıcılar · Günlükler[Benim/Tümü] · Sunucu; yetkisiz rotalar `router.hasRoute` ile gizlenir); sayfa başlığı ve sekme başlığı nav etiketinden (`NAV_INDEX`). Sekme çubuğu (tags) ve kenar çubuğu kaldırıldı. Yazı tipi: `Calibri, Carlito, 'Segoe UI'` (mono dahil her yerde; web fontu yüklenmiyor, Calibri'siz sistemde Carlito yedeği), taban 15px. 21 sayfa temiz; yalnız Sunucu komutu sayfası içerik uzunluğundan kendi kutusunda kayar.

### Güncelleme 3 (05.10.2026) — teknik başlıklar Türkçeleştirildi (m2y-panel `8d53be4`, m2y-api `02ddef6`)
Sunucu komutu kartları (gerçek işlev rustdesk-server kaynağından doğrulandı): MUST_LOGIN → "Bağlanmak için oturum açmayı zorunlu kıl" (bu sunucuda komut yok, kart pasif); ALWAYS_USE_RELAY → "Bağlantıları her zaman aktarma sunucusundan geçir"; RELAY_SERVERS → "Aktarma sunucusu listesi" (sırayla dağıtım); **BLOCK_LIST → "Engel listesi — bağlantıyı tamamen reddet"** (hbbr bağlantıyı kabul etmez); **BLACK_LIST → "Hız sınırı listesi — bağlantıyı yavaşlat"** (hbbr hızı `limit-speed`e düşürür, kesmez). Her karta kısa açıklama (`.setting-desc`); metinler `tr.json` (`*Title`/`*Desc` anahtarları), kod/API anahtarları değişmedi. Ayrıca: CPU→İşlemci (CPU), UUID→Cihaz benzersiz kimliği (UUID), Kullanılabilir→Erişilebilir, Basit/Gelişmiş→Temel ayarlar/Gelişmiş komutlar, PKCE/Issuer/ToRemote/ToLocal açıklamaları, komut listesi açıklamaları (API). Kartlar eşit genişlikli ızgara.

### Güncelleme 4 (05.10.2026) — kullanıcı listesi sade + ayrıntı sayfası (m2y-panel)
`/user/index`: yalnız Kullanıcı adı · E-posta · Grup · Durum · [Sil sol | Gözat sağ]. Gözat → `/user/view/:id` (`UserView`, gizli rota): tüm alanlar, üstte sağda Parolayı sıfırla + Düzenle, altta solda Listeye dön + Sil, yanda ilişkili kayıtlar (etiketler, adres defteri). `m2y_korumali` bayrağı doluysa Sil gizlenir (şu an API her iki kullanıcı için `false` döndürüyor; sunucu tarafı 403 korumasına güveniliyor — bayrağın doğru dolup dolmadığı m2y-api'de ayrıca kontrol edilmeli). `useDel` içindeki eksik `await` düzeltildi.

### Güncelleme 5 (05.10.2026 öğleden sonra) — korumalı bayrağı, ekran çerçevesi, 1.0.2 derlemesi BAŞLADI
- m2y-api `fix`: yönetici liste/ayrıntıda `m2y_korumali` artık `M2yKorumaliMi` (bayrak VEYA `M2Y_ADMIN_EMAILS`) ile hesaplanıyor → mehmetmesut@gmail.com `true`; panelde Sil gizlenir/durum kilitlenir.
- Ekran kenarı çerçevesi (Windows): `src/platform/m2y_frame.rs` (katmanlı + tıklanmaz + üstte + `WDA_EXCLUDEFROMCAPTURE`, 5 px kırmızı halka, sanal masaüstü), `main_m2y_set_frame` (flutter_ffi.rs), `server_page.dart` şerit sayacı; winapi `wingdi`+`libloaderapi` özellikleri eklendi. DERLENMEDİ — CI derleme hatası verirse ilk şüpheli bu modül ve ajan H'nin `common.rs` ekleri.
- Sürüm 1.0.2 (Cargo.toml, portable, Cargo.lock, pubspec 1.0.2+3). **GitHub Actions koşusu 37306821269** (`m2y-build.yml`, tag `v1.0.2`, Windows+Android+Linux; commit fbbee62) başlatıldı. Bitince: `istemci-hazirla.sh` (M2Y_SURUM=v1.0.2) → `surum.json` hash doğrula → imzala → `.sig` yükle; sonra sunucuda `M2Y_ASGARI_SURUM=1.0.2` (zorunlu güncelleme) ve gerçek cihazda doğrulama (giriş kapısı, çerçeve, güncelleme).
- Google OAuth: Chrome'da GoogleMaps projesinde (fluid-stratum-505512-t5) istemci formu dolduruldu (Web application, origin https://desk.mehmetmesut.com, redirect …/api/oidc/callback); "Create" ve gizli anahtarın panele girilmesi kullanıcıda.

### Güncelleme 6 — 1.0.2 derleme #9 başarısız, #10 başlatıldı
- #9 (fbbee62): Android ve Windows `cargo build` hatası: `E0616 LoginConfigHandler.id özel` (`flutter_ffi.rs` `session_m2y_info`) ve `E0433 log` (`m2y_frame.rs`). Düzeltme `4132d50`: `lc.read().unwrap().get_id().to_owned()` ve `hbb_common::log::warn!`. #9 iptal edildi.
- **#10: koşu 37311232770** (tag v1.0.2, Win+Android+Linux, commit 4132d50). Çözümleme hataları başka tür hataları gizlemiş olabilir (E0433 tip denetimini keser) → yeni tur hata verirse günlükten oku (GitHub iş sayfası → "Build rustdesk" adımı → `get_page_text`).
- Google OAuth: Client ID panelde forma yazıldı, Client Secret kullanıcıda; JSON dosyası Masaüstü'nde duruyor (silinmeli).

### Güncelleme 7 — Google girişi çalışıyor; derleme #10 Dart adlarında düştü, #11 başladı
- Google OIDC: sağlayıcı kayıtlı (`/api/login-options` → google), `/api/oidc/auth` doğru client_id/redirect/PKCE ile Google URL'si üretiyor. Gerçek oturum denemesi kullanıcıda.
- #10 (4132d50): **Rust derlemesi geçti** (Android lib 4m41s). Android Dart adımı düştü: `bind.mainM2y…` tanımsız — **frb rakamdan sonraki harfi büyütür** (`session_send2fa`→`sessionSend2Fa`), yani `main_m2y_*` → `mainM2Y*`, `session_m2y_info` → `sessionM2YInfo`. Düzeltme `dd148b5` (tüm `bind.*M2y*` çağrıları). KURAL: yeni Rust FFI adı + rakam içeriyorsa Dart adını buna göre yaz.
- **#11: koşu 37315821669** (tag v1.0.2, Win+Android+Linux, commit dd148b5).

## Y2 — 1.0.2 YAYINDA (yerel, 05.10.2026 akşam)
- Derleme #11 (koşu 37315821669, commit dd148b5) başarılı, 1 sa 9 dk: Windows (desk + Hızlı Destek, exe/install/msi), Android APK, Linux deb. Release `v1.0.2` yayımlandı.
- Sunucuda güncel `istemci-hazirla.sh` (asgari sürüm destekli) ile `indir/` ve `ayar.js` 1.0.2'ye geçti; `guncelleme/surum.json` (sürüm 1.0.2, `asgari_surum` 1.0.2).
- Doğrulama: 6 dosyanın SHA-256'sı GitHub API `digest` = `surum.json` = diskteki dosya (hepsi eşleşti; exe ile install.exe aynı ikili). `surum.json` PC'de `imzala.py` ile imzalandı, `dogrula` GEÇERLİ, `.sig` yüklendi; `dogrula.sh` hiç ✘ yok.
- `asgari_surum` yalnız ≥1.0.2 istemcilerince okunur (eskiler alanı bilmez) → şu an kimseyi kesmez. **Eski istemcileri kesen ayar API'deki `M2Y_ASGARI_SURUM` (yetki isteğine 426) — kullanıcı onayı bekliyor, AYARLANMADI.**
- Sırada: gerçek cihaz testi (giriş kapısı/e-posta kodu, Google girişi, ekran kenarı çerçevesi, Destek iste, oturum notu, zorunlu güncelleme penceresi), sonra onayla `M2Y_ASGARI_SURUM=1.0.2`.

## Microsoft Store (06.10.2026) — Hızlı Destek
- Geliştirici hesabı (bireysel, ücretsiz) açıldı; yayımcı görünen adı **M2Y Software**. Ürün adı ayrıldı: **M2YDesk Hızlı Destek**, Store ID `9MZ8NFJ4QVM9` (3 ay içinde gönderilmezse ad düşer).
- Kimlik: Name `M2YSoftware.M2YDeskHzlDestek`, Publisher `CN=F12BF89C-A343-46B6-A6E6-0B2F2C0D6B7F`, PFN `M2YSoftware.M2YDeskHzlDestek_r2jdj4998dc4a` → GitHub Variables `M2Y_MSIX_NAME/PUBLISHER/PUBLISHER_DISPLAY`.
- Paketleme: `res/m2y/msix/` (manifest şablonu + `hazirla.py`: sürücüleri dışlar, Store simgelerini üretir), workflow QS işinde "Build Microsoft Store package" adımı (makeappx, imzasız; Store imzalar) → `M2YDesk-QS-<sürüm>-x86_64.msix`.
- Store sürümünde güncelleme Store'a yönlendirilir (`m2y_is_store()` = exe yolu `\WindowsApps\`); kendi kendini değiştirme kapalı.
- Sürüm 1.0.3. Test derlemesi koşu **37361973060** (tag m2y-test, yalnız Windows): QS sıkı görünüm düzeltmeleri + ilk MSIX. Sırada: MSIX'i Partner Center'a yükle, Store sayfası (açıklama, ekran görüntüleri, gizlilik bağlantısı, yaş derecelendirmesi, ücretsiz, pazarlar).
- Tam M2YDesk Store'a: hizmet + sürücüler MSIX'te kısıtlı; değerlendirme bekliyor (kullanıcı istedi).
- **Yazı tipi ve ölçek (06.10.2026):** Tüm Flutter pencerelerinde `fontFamily` Windows'ta sistem **Calibri**, diğer platformlarda gömülü **Carlito** (Calibri ile metrik uyumlu, OFL; `flutter/assets/fonts/carlito`, yalnız Regular+Bold ≈1,3 MB). Yazı ölçeği pencere genişliğine oranlı: `main.dart` `m2yTextScale` (≤360 px 0,94 → ≥640 px 1,06; Android 1,04). QS giriş ekranındaki ayrı 0,86 küçültme kaldırıldı (yalnız yoğunluk).
- **macOS hazırlığı:** macOS işine M2Y simgesi (`uret.py` + `sips`/`iconutil` → `AppIcon.icns`) ve ad-hoc imza (`codesign -s -`) eklendi. Site: macOS sekmesine tek komut `curl -fsSL https://desk.mehmetmesut.com/mac-kur.sh | bash` (imzalı surum.json'dan dmg + SHA-256 doğrulama, /Applications'a kopyalama, karantina kaldırma; izinleri VERMEZ). Sekme, dmg yayımlanınca görünür.
- Test derlemesi #12 iptal; **#13 koşu 37362749355** (tag m2y-test, Windows + macOS, commit cba9550): QS düzeltmeleri, Calibri/ölçek, ilk MSIX ve ilk macOS dmg.
- **Windows PowerShell kurulum (06.10.2026):** `win-kur.ps1` sitede. Hızlı Destek: `$env:M2Y_HIZLI='1'; irm https://desk.mehmetmesut.com/win-kur.ps1 | iex`; kalıcı kurulum (MSI, UAC): `irm https://desk.mehmetmesut.com/win-kur.ps1 | iex`. surum.json'dan indirir, SHA-256 doğrular (eşleşmezse çalıştırmaz). PowerShell indirmesinde Zone.Identifier (MOTW) olmadığı için **SmartScreen uyarısı çıkmaz** (doğrulandı). nginx: `win-kur.ps1|mac-kur.sh` → `text/plain; charset=utf-8` (PowerShell 5.1 Türkçe doğru okuyor, doğrulandı). Sitedeki Windows sekmelerinde komut + Kopyala düğmesi.
- Test derlemesi #13: windows desk ve macOS "runner alınamadı" (GitHub kapasite; fatura/kota DEĞİL — ay kullanımı 4,43 $ tamamı ücretsiz kotada). QS bitince "Re-run failed jobs".

## SmartScreen planı (06.10.2026) — "Windows kişisel bilgisayarınızı korudu"
Durum: tarayıcıdan indirilen her exe/msi (Mark-of-the-Web) imzasız olduğu için SmartScreen "tanınmayan uygulama" uyarısı veriyor (1.0.3 testinde kullanıcı yeniden gördü). Kesin çözüm **kod imzalama sertifikası**; Azure Trusted Signing Türkiye'ye kapalı, sahte ülke bilgisi reddedildi.
1. **Hemen (yapıldı):** Sitede birincil yol PowerShell komutu (`win-kur.ps1`, MOTW yok → uyarı çıkmaz); uygulama içi güncelleme Rust ile indirdiği için mevcut kullanıcılar uyarı görmez; Hızlı Destek için Microsoft Store (MSIX, Store imzalar).
2. **Kalıcı (kullanıcı kararı/satın alma):** OV kod imzalama sertifikası. Seçenekler: Certum "Open Source Code Signing in the Cloud" (SimplySign, ~€49/yıl; proje açık kaynak lisanslı olmalı — M2YDesk AGPL türevi) ya da Certum "Standard Code Signing in the Cloud"; SSL.com OV + eSigner (~$289/yıl, resmi GitHub Action `SSLcom/esigner-codesign`). 2026'dan itibaren sertifika en çok ~460 gün geçerli. **Not:** 2024'ten beri EV de anında itibar vermiyor; OV/EV fark etmeksizin itibar temiz indirme sayısıyla (günler–haftalar) oluşur; itibar sertifikaya bağlanır, yeni sürümlere taşınır. İlk haftalarda uyarı "bilinmeyen yayıncı" yerine yayıncı adıyla çıkar.
3. **Uygulama (sertifika alınınca):** imzalanacaklar: dış taşınabilir paketleyici exe (M2YDesk ve QS), içteki `M2YDesk*.exe`, MSI (`signtool sign /fd sha256 /tr http://time.certum.pl /td sha256`). SimplySign CI'da zahmetli → PC'de imzala: akış sırası **imzala → SHA-256 → surum.json → .sig** (imza hash'i değiştirir; mevcut `istemci-hazirla.sh` sırası güncellenecek). MSIX imzalanmaz (Store imzalar).
4. Düşük getirili: her sürümde Microsoft WDSI dosya gönderimi (SmartScreen yanlış pozitif).
- **Varsayılan görüntü ayarları (06.10, kullanıcı isteği):** `res/m2y/m2ydesk.json` `default-settings`'e eklendi: `view-style: adaptive`, `image-quality: best`, `show-monitors-toolbar/collapse-toolbar/show-remote-cursor/follow-remote-cursor/follow-remote-window: Y` (+ `scroll-style: scrollauto`, `enable-file-copy-paste: Y`, `terminal-persistent: Y`). Gömülü yapılandırma `default-settings` içindeki display anahtarlarını `DEFAULT_DISPLAY_SETTINGS`'e yazar; kullanıcı Ayarlar'dan değiştirebilir. **Henüz derlenmedi** (derleme #15 bu değişiklikten önce başladı).
- Derleme #15 (run 37418489301, `m2ydesk`, Windows): Google/Webauth düğmeleri tek satır. Kullanıcı PC'yi kapattı; sonraki oturumda sonuç kontrol edilecek.
- **Store ≠ kod imzalama:** Partner Center üyeliği yalnız Store'dan kurulan MSIX'i Microsoft sertifikasıyla imzalar; sitedeki exe/MSI için OV sertifika gerekir (yukarıdaki plan).

## Yerel ön izleme ve testler (06.10.2026) — derlemeden önce görerek doğrulama
Amaç (kullanıcı): her geliştirmede ≈1 saatlik GitHub derlemesini beklemeden arayüzü yerelde görmek/test etmek; derleme yalnız son onaydan sonra.
- **Kurulu:** Flutter 3.24.5 (`C:\tools\flutter`, CI ile aynı), Visual Studio Derleme Araçları 2022 + C++ iş yükü (`VCTools`; Build Tools'ta iş yükü kimliği `Microsoft.VisualStudio.Workload.VCTools`, `NativeDesktop` DEĞİL) + Windows SDK 26100 + CMake. `flutter doctor` Visual Studio ✓.
- **İndirilenler (depo içinde, git'e girmez — `/yerel-onizleme/`):** `ci-derleme-15\` (CI artefaktları: bridge-artifact, m2y-windows-desk zip'i), `rust-cekirdek\` (paket exe'sinden `paket-ac.py` ile açılmış `librustdesk.dll` vb.; paket biçimi = `libs/portable/src/bin_reader.rs`, Brotli + md5). `flutter/lib/generated_bridge*.dart` CI köprü çıktısından kopyalandı (git'te ignore).
- **A — canlı ön izleme:** `araclar\yerel-onizleme.ps1` → `flutter run -d windows` (M2Y_BINARY_NAME=M2YDesk; çekirdek DLL'i Debug klasörüne önceden konur). Çalışırken `r` hot reload. Sınır: Rust'a gömülü şeyler (varsayılan ayar JSON'u, servis başlatma) çekirdek yeniden derlenmeden değişmez; çekirdek DLL'i yenilenmek isterse yeni derlemenin paketinden tekrar `paket-ac.py`.
- **C — görünüm testleri:** `flutter/test/m2y_gorunum_test.dart` (Carlito'yu Calibri/Carlito adıyla yükler; 224/280 px panel × yazı ölçeği 0.8–1.3: taşma, metin küçülmesi, düğme yüksekliği, Vazgeç solda/Gönder sağda). `flutter test --no-pub test/m2y_gorunum_test.dart` ≈ 20 sn. `flutter analyze --no-pub <dosyalar>` ≈ 15–40 sn (Dart hatalarını derlemeden önce yakalar).
- **Testin yakaladığı gerçek hata:** `m2ySideButton`/`m2yCompactDialog` düğme `textStyle`'ı sabit `TextStyle` ile verilince yazı ailesi (Calibri) kayboluyordu; ayrıca `buttonStyle.merge(tema)` sırası genel düğme temasını sıkı değerlerin üstüne bindiriyordu. İkisi düzeltildi (`c5db50b`).
- **Kural (bundan sonra):** her UI değişikliğinde `flutter analyze` + `flutter test` + (mümkünse) ön izleme; GitHub derlemesi son onaydan sonra.
- Not: 1.4.9 dosyaları `m2y-test` sürümünden silindi (4 dosya).
- **Ön izleme DOĞRULANDI (06.10, 10:04):** `R:\flutter` üzerinden `flutter build windows --debug` başarılı (ilk derleme ≈1,5 dk, sonrası ≈20–40 sn); uygulama açıldı, güncel kaynak koddan sol panel/bağlantı kartı/üyelik kartı ekran görüntüsüyle görüldü (computer-use ile `m2ydesk.exe` penceresi). TUZAK: proje yolundaki `ı` (ASCII dışı) shader derlemesini bozar → `subst R:`; ayrıca CMake `install` adımı `target\debug\librustdesk.dll` ister.
- Testler: `m2y_gorunum_test.dart` 14 test (yan düğmeler, diyalog, giriş ekranı Google/Webauth düğmeleri). Test için `PlatformFFI.ffiBind` setter'ı eklendi (`@visibleForTesting`, sahte köprü).
- `M2yOidcButtons` ayrı bileşen oldu; düğme metinleri sabit Türkçe (Google ile giriş yap / Webauth ile devam et).
- Not: yerel `flutter pub get`, `flutter/pubspec.lock` dosyasını değiştirir (Flutter 3.24.5 çözümlemesi); CI'yı etkilememesi için commit'e ALMA (`git checkout flutter/pubspec.lock`).
- **Hızlı Destek (QS) arayüz kuralları (kullanıcı, 06.10):** (1) aydınlatma metni (onay penceresi) dışında HİÇBİR yerde kaydırma yok — pencere içeriğe göre büyür (`M2yBoyutIzleyici`, `m2yPencereBuyutup`, `m2yKaydirmaGerekirse` in `m2y_pencere.dart`); (2) giriş yalnız iki seçenek: Google (üstte, tam genişlik) veya e-posta kodu; Webauth QS'te yok; (3) giriş/sabit parola kutusu genişliği 360 → 288 px. Hata düzeltildi: içerik penceredeki geçerli genişliğe göre ölçüldüğü için pencere bir kez daralınca (136 px) geri büyüyemiyordu → `OverflowBox` ile sınırsız ölçüm. Testler: `m2y_gorunum_test.dart` 19 test.
- Hızlı Destek ön izlemesi: `araclar\yerel-onizleme.ps1 -Hizli` (çekirdek: `yerel-onizleme\rust-cekirdek-qs`, CI #15 QS artefaktından). Ön izleme kullanıcının gerçek QS profilini (`%APPDATA%\M2YDeskQS`) kullanır.
