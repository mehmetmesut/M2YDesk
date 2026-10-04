# Devir Notu (bulut oturumu → yerel oturum)

Bu dosya iki Claude oturumu arasındaki ortak hafızadır. **Yerel oturum ilk iş bunu okusun**, her önemli adımdan sonra "Durum" bölümünü güncelleyip commit/push etsin; bulut oturumu `git pull` ile okur.

## Proje
M2YDesk: RustDesk 1.4.9 tabanlı, kendi sunucuda barındırılan uzaktan destek sistemi. Sürüm **1.0.0**.
- Sunucu/alan adı: **desk.mehmetmesut.com** (Plesk, IP `217.195.207.159`, Plesk paneli `https://217.195.207.159:8443`)
- Depo: `mehmetmesut/M2YDesk` (özel), dal `claude/tender-darwin-l1fq1r`
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
   sudo git clone https://github.com/mehmetmesut/M2YDesk.git -b claude/tender-darwin-l1fq1r /opt/m2ydesk
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
- Güvenlik notu (yerel oturum): 6 rakam = 1.000.000 olasılık; RustDesk'in başarısız giriş sınırının (`LOGIN_FAILURES`) bu sürümde etkin olduğu doğrulansın, gerekirse 3 hatada 1 dk kilit. Varsayılan açık gözetimsiz erişim KVKK aydınlatma metnine eklenecek.
