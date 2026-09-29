# Bulut Oturumu Uygulama Planı (kod doğrulamalı, onay bekliyor)

Tarih: 29.09.2026. Bu plan `docs/BULUT-BASLANGIC-PROMPTU.md` §4'teki 1–8 görevlerin kaynak koda göre gözden geçirilmiş halidir. Satır numaraları `claude/tender-darwin-l1fq1r` dalına aittir.

## 0. İlk plandaki hatalar ve düzeltmeler

| # | Önceki varsayım | Koddaki gerçek | Düzeltme |
|---|---|---|---|
| 1 | Güncelleme adresi bir seçenekle değiştirilir | `check_software_update()` özel istemcide (`app-name != "RustDesk"`) hiç çalışmıyor (`src/common.rs:941`); adres sabit `https://api.rustdesk.com/version/latest` (`libs/hbb_common/src/lib.rs:496`); indirme adresi GitHub `tag→download` + `rustdesk-<sürüm>` dosya adından türetiliyor (`src/updater.rs:135-153`); `update_msi` özel istemcide kapalı (`updater.rs:122`) | Erken dönüş M2Y için kaldırılır; sabit adres `surum.json`'a çevrilir (GET); indirme adresi ve SHA-256 doğrudan `surum.json`'dan okunur; MSI kurulumda exe yoluyla güncelleme **test edilmeli** (belirsiz) |
| 2 | Üye olmayan relay portu `relay-server` seçeneğiyle istemciden seçilir | Relay adresi hbbs'in delik-açma yanıtından gelir (`src/client.rs:512`), port `check_port(.., 21117)` ile eklenir (`client.rs:912`); karşı taraf adresi `RequestRelay` ile bağlanan taraftan alır | Port değişikliği bağlanan istemcide, `create_relay`/`request_relay` çağrılarında yapılır; hbbs ayarı gerekmez |
| 3 | 5 dk sınırı için mevcut `auto_disconnect_timer` kullanılır | `src/server/connection.rs:374` sayacı **boşta kalma** sayacıdır ve kontrol edilen tarafta çalışır | Yeni oturum sayacı bağlanan tarafta (`src/ui_session_interface.rs` / `client.rs`) tutulur |
| 4 | MAC/UUID gönderimi yalnızca `get_sysinfo()` genişletmesidir | UUID zaten gönderiliyor (`src/hbbs_http/sync.rs:134`); ancak `register-device=N` iken `get_api_server()` boş döner (`common.rs:1048`) ve hiçbir şey gönderilmez; API sunucusu yok | MAC eklenir; gönderim **onay + API sunucusu** koşuluna bağlanır. API sunucusu kurulmadan görev 2 sunucuda görünmez |
| 5 | Engelleme kontrolü API'den yapılır | API sunucusu henüz yok | v1: sitede hash'li `engel.json`; v2: API |
| 6 | Sunucuda `ALWAYS_USE_RELAY=Y` zorunlu | Üyeleri de relay'e zorlar, bant genişliği maliyeti | Öneri: girişsiz istemcide `force-always-relay` zorlanır, hbbs ayarı kapalı kalır (karar: sizde) |

## 1. Görev sırası ve kapsam

Sıra: **4 → 1 → 3 → 2 → 5 → 7 → 6 → derleme**. Her görev ayrı commit, DEVIR.md güncellenir.

### Görev 4 — "QS" → "Hızlı Destek" (~20 dk)
- `res/m2y/m2ydesk-qs.json` `app-name` **değişmez** (`M2YDeskQS`, boşluksuz, servis/klasör adı). Görünen ad: Windows `Runner.rc` (QS sed adımı `m2y-build.yml`), `src/lang/tr.rs` (başlık), `flutter` başlık metni, `res/m2y/README.md`, `docs/*`, site.
- Dosya adı `M2YDesk-QS-…exe` kalır (`-qs-` UAC kuralı, `core_main.rs:139`).

### Görev 1 — Güncelleme mekanizması (~2 s)
- `libs/hbb_common/src/lib.rs:496` → `https://desk.mehmetmesut.com/guncelleme/surum.json` (derleme zamanı `M2Y_SERVER_HOST`), GET.
- `surum.json` şeması (istemci-hazirla.sh üretir):
  ```json
  {"version":"1.0.1","tarih":"2026-09-29",
   "dosyalar":{"windows_install":{"url":"https://desk.mehmetmesut.com/indir/M2YDesk-1.0.1-x86_64-install.exe","sha256":"…"},
               "windows":{…},"windows_qs":{…},"windows_msi":{…}}}
  ```
- `src/common.rs:941` erken dönüş kaldırılır; `do_check_software_update` yanıtı yeni şemaya göre ayrıştırır, `SOFTWARE_UPDATE_URL` yerine dosya URL'si + sha256 saklanır.
- `src/updater.rs`: indirme adresi `surum.json`'dan; indirdikten sonra **SHA-256 doğrulanmadan** çalıştırılmaz; uyuşmazlıkta dosya silinir, log yazılır.
- `res/m2y/m2ydesk.json`: `enable-check-update=Y`, `allow-auto-update=Y` (sessiz güncelleme yalnızca kurulu Windows sürümünde; taşınabilir/QS yalnızca bildirir). QS json'unda ikisi `N` kalır.
- Belge: kod imzası yok; bütünlük HTTPS + SHA-256 ile. `docs/guncelleme.md`.
- Test: `hbb_common` birim testi (şema ayrıştırma, sha256 karşılaştırma). Gerçek güncelleme testi yerel oturumda (1.0.0 → 1.0.1).

### Görev 3 — Üye / üye olmayan kuralları (~3 s)
- "Girişli" = `LocalConfig` `access_token` **ve** `user_info` dolu (`src/hbbs_http/account.rs:265-272`). API sunucusu olmadan kimse giriş yapamaz → bu görev tamamlandığında **herkes üye olmayan sayılır**; API sunucusu kurulunca üyeler açılır. (Dürüst not: istemci kaynak açık; bu sınırlar değiştirilmiş istemciyle atlatılabilir. Sunucu tarafı gerçek kontrol = 21127 connlimit + 2. fazda API.)
- Bağlanan tarafta (`src/client.rs`): girişsizse relay adresi `host:21127`, `force_relay=true`.
- Oturum sayacı: bağlantı kurulunca 5 dk; 4:30'da uyarı; 5:00'da `close` + mesaj "Üye olmayan oturum süresi doldu (5 dk). 2 dk sonra tekrar bağlanabilirsiniz. Sınırsız kullanım için giriş yapın."; hedef ID için 2 dk engel (bellekte, `HashMap<id, Instant>`); süre dolmadan bağlanma girişimi aynı mesajla reddedilir.
- Engelli cihaz: açılışta `https://desk.mehmetmesut.com/guncelleme/engel.json` (`{"id":["sha256…"],"uuid":[…],"mac":[…]}`) GET; eşleşme varsa "Erişim engellendi" ve çıkış. Ağ hatasında engel yok (kullanılabilirlik). hbbs OSS'te ID engel listesi olup olmadığı **doğrulanmadı** (yerel oturum: `hbbs --help`).
- `src/lang/tr.rs` + `en.rs` yeni metinler.

### Görev 2 — Cihaz bilgisi + onay (~2 s)
- `get_sysinfo()` (`src/common.rs:857`): `mac` (`mac_address::get_mac_address()`, `config.rs:1067`'de zaten kullanılıyor), `uuid` zaten var (`sync.rs:134`), `hostname`/`username`/`os` zaten var.
- Hızlı Destek ilk açılışta **aydınlatma ekranı** (Flutter, `desktop_home_page.dart`, yalnızca `isIncomingOnly`): metin + "Kabul ediyorum" → `LocalConfig m2y-consent=Y`; reddedilirse kapanır. Kabul yoksa `sync::start()` çağrılmaz.
- QS json: `register-device` override'ı kaldırılır (varsayılan `N`), kabulden sonra `Y` yazılır; `api-server=https://desk.mehmetmesut.com` (API sunucusu kurulunca çalışır; öncesinde 404 → zaten sessiz).
- Sunucuda **hiçbir şey görünmez** ta ki görev 7'deki API sunucusu kurulana kadar (yerel oturum işi).

### Görev 5 — Site onay metni (~30 dk)
- `index.html`: KVKK aydınlatma özeti (işlenen veri: ID, IP, MAC, cihaz adı, işletim sistemi, bağlantı zamanları; amaç: uzaktan destek; saklama; haklar) + onay kutusu; kutu işaretlenmeden indirme düğmeleri pasif. Sayfa içi JS, sunucu kodu yok. 360–1280 px taşma testi.

### Görev 7 — API sunucusu ve web istemci araştırması (~1 s)
- `lejianwen/rustdesk-api`: lisans, son commit, OIDC/Google, 2FA, cihaz envanteri (`/api/sysinfo`, `/api/heartbeat` alanları; MAC alanını kabul ediyor mu?), adres defteri, denetim, roller, engelleme, hbbs entegrasyonu. Web istemci: `rustdesk-web` OSS durumu. Doğrulanmayan her madde "❓" işaretli. Çıktı: `docs/api-sunucusu-degerlendirme.md`.

### Görev 6 — Android / iOS (~1 s)
- `m2y-build.yml` `build_android` adımını inceleme; imzasız APK mı, keystore Secret mi (`M2Y_ANDROID_KEYSTORE_B64`, `_PASS`) — yalnızca belge, Secret oluşturma sizde. iOS: resmi RustDesk uygulaması + QR metni (mevcut).

### Derleme (görev 8)
- Tek birleşik derleme, **yalnızca onayınızla** (Windows ~65 dk, 2× dakika).

## 2. Yerel oturumdan istenecek işler (DEVIR.md'ye yazılacak)
1. `server/docker-compose.yml`'e ikinci hbbr (`hbbr2`, port 21127, aynı `-k _` anahtar) — dosyayı bulut yazar, yerel uygular; `iptables`/firewalld `connlimit 5` (dışa dönük: önce onay).
2. Sitede `guncelleme/` dizini; `istemci-hazirla.sh` güncellenmiş haliyle çalıştırılır (`surum.json`, boş `engel.json`).
3. Windows kurulu sürümde 1.0.0 → 1.0.1 sessiz güncelleme testi (exe ve MSI ayrı).
4. Görev 7 sonucuna göre API sunucusu kurulumu.
5. Android keystore Secret'ları (gerekirse).

## 3. Süre
Kod: ~9–10 saat bulut; test/derleme: ~2 saat yerel + 65 dk Actions.
