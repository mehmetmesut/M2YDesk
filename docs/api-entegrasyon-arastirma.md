# rustdesk-api entegrasyon araştırması (04.10.2026)

**Durum:** Yalnızca araştırma; kod yazılmadı. Konu: e-posta+kod girişi, yetkili hesap belirteci, "Destek iste", oturum kaydı/aylık rapor, MAC alanı.
**Kapsam:** `lejianwen/rustdesk-api` kaynak kodu (depo klonlanıp satır satır okundu) + bu depodaki istemci kodu (`src/`, `flutter/`, `libs/hbb_common`).

**Kaynak sürümü:** `master` @ `c5687e1`, son commit **29.09.2025**, son sürüm **v2.7** (28.09.2025); Vue yönetim paneli (`rustdesk-api-web`) son commit 31.08.2025. Yani her ikisi de bugüne göre yaklaşık **1 yıldır durağan** → pratikte fork'u biz sahipleneceğiz (MIT lisans buna izin verir).
Bağlantılar bu commit'e sabitlenmiştir: `https://github.com/lejianwen/rustdesk-api/blob/c5687e1/<yol>#L<satır>`. Aşağıda yollar `API:` önekiyle, bu depodaki dosyalar `İSTEMCİ:` önekiyle yazılmıştır.

## 0. Özet (karar için)

| Soru | Kısa cevap |
|---|---|
| 1. Oturum/belirteç | `user_tokens` tablosu, rastgele **MD5(kullanıcı adı+zaman)** (veya `jwt.key` varsa JWT+tablo), 168 sa **kayan** süre. İstemci `/api/login` yanıtında `type=access_token`, `access_token`, `user{name,email,is_admin,status,info}` bekler |
| 2. E-posta kodu | rustdesk-api'de **SMTP/e-posta kodu yok**, e-posta-kod girişi de yok. **Önerilen: (a) fork'a yalıtılmış `m2y` paketi ekle** (~3 iş günü). (b) ayrı servis "kullanıcı adına belirteç" uç noktası olmadığı için kırılgan (~4 gün + kalıcı hareketli parça) |
| 3. Google/OIDC | Evet: yeni kullanıcı **otomatik oluşur** (`auto_register` açıksa), e-posta saklanır, **aynı e-postalı mevcut kullanıcıya otomatik bağlanır**. "Belirli e-postayı otomatik admin yap" ayarı **yok** (önceden admin kullanıcı oluşturarak çözülür) |
| 4. Denetim | İstemci `POST /api/audit/conn` (`new` / `close`) gönderir, API `audit_conns` tablosunda **saklar** (hedef ID, kaynak ID, kaynak adı, IP, tür, açılış/kapanış). Süre türetilebilir ama **e-posta/kuruluş/not yok**, kayıtlar **kimlik doğrulamasız** (sahtelenebilir), kapanış kaybolabilir → aylık rapor için **yama gerekir** |
| 5. Destek iste | Mevcut karşılığı **yok**. Fork'a `support_requests` tablosu + `/api/m2y/destek` uçları eklenir |
| 6. Belirteç alanı | `LoginRequest`'te **güvenle kullanılabilir boş alan yok** (`my_name`, `avatar`, `hwid`, `os_login`, `option` hepsi başka işe bağlı). **Yeni bir proto alanı (ör. `bytes m2y_auth = 100`) eklenir**; `libs/hbb_common` bu depoda izlendiği için yapılabilir, eski istemciler alanı yok sayar |
| 7. Cihaz listesi | Takma ad, grup, son IP, son çevrimiçi zamanı var; "çevrimiçi" bayrağı sunucuda yok (zamandan türetilir). MAC için 5 Go dosyası + `DatabaseVersion` artışı + Vue panel sayfası |

Yan bulgular (§9): `heartbeat`, `sysinfo`, `audit/*` uçları **kimlik doğrulamasız**; belirteç üretimi zayıf; heartbeat gövdesinde `conns` (canlı bağlantı kimlikleri) ve yanıtta `disconnect` desteği var (güvenilir oturum kapanışı ve uzaktan sonlandırma için kullanılabilir).

---

## 1. Oturum ve belirteç; istemcinin beklediği alanlar

### 1.1 Belirteç üretimi (sunucu)

| Konu | Bulgu | Kaynak |
|---|---|---|
| Parola girişi | `POST /api/login` → `LoginForm` bağlanır, `InfoByUsernamePassword` ile doğrulanır (bcrypt, gerekirse yeniden hash), kullanıcı `Status==1` olmalı | [API:http/controller/api/login.go#L29-L92](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/controller/api/login.go#L29-L92), [API:service/user.go#L48-L71](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L48-L71) |
| Belirteç değeri | `GenerateToken`: `jwt.key` doluysa **HS256 JWT** (`user_id` + `exp`); boşsa **`MD5(kullanıcıAdı + time.Now().String())`** | [API:service/user.go#L89-L94](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L89-L94), [API:lib/jwt/jwt.go](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/lib/jwt/jwt.go) |
| Kayıt | `Login()` → `user_tokens` satırı: `user_id, device_uuid, device_id, token, expired_at` + `login_logs` satırı + cihaz–kullanıcı bağlama (`UuidBindUserId`) | [API:service/user.go#L97-L113](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L97-L113), [API:model/userToken.go](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/model/userToken.go) |
| Süre | `app.token-expire` (varsayılan yapılandırma **168h**). Yetkili uçlara her istekte, kalan süre < süre/3 ise **kayan yenileme** (`AutoRefreshAccessToken`) | [API:conf/config.yaml#L9](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/conf/config.yaml#L9), [API:service/user.go#L489-L508](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L489-L508) |
| Doğrulama | `RustAuth` ara katmanı: `Authorization: Bearer <token>` → JWT (varsa) + `user_tokens` satırı + süre + kullanıcı aktif. Yönetim API'si aynı belirteci `api-token` başlığıyla kullanır (`BackendUserAuth`), yönetici şartı `AdminPrivilege` | [API:http/middleware/rustauth.go](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/middleware/rustauth.go), [API:http/middleware/admin.go](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/middleware/admin.go) |
| Dikkat (hata) | `token-expire` boş/0 ise kod `604800` atar; bu `time.Duration` olduğu için **604,8 mikrosaniye** eder (7 gün değil). Yapılandırmada `168h` kalmalı; ortam değişkeniyle boş bırakılmamalı | [API:service/user.go#L490-L496](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L490-L496) |

### 1.2 İstemcinin çağırdığı uçlar ve gövdeler (bu depodan çıkarıldı)

| Uç | Kim çağırır | İstek gövdesi | Beklenen yanıt | Kimlik doğrulama |
|---|---|---|---|---|
| `GET /api/login-options` | `UserModel.queryOidcLoginOptions`, `account.rs` | – | `["common-oidc/[{\"name\":\"google\"}]","oidc/google"]` | yok |
| `POST /api/login` | Flutter `UserModel.login` ([İSTEMCİ:flutter/lib/models/user_model.dart#L178-L201](../flutter/lib/models/user_model.dart)) | `{username, password, id, uuid, autoLogin, type, verificationCode, tfaCode, secret, deviceInfo:{name,os,type}}` ([İSTEMCİ:flutter/lib/common/hbbs/hbbs.dart](../flutter/lib/common/hbbs/hbbs.dart)) | `{type:"access_token", access_token, user:{name,email,note,is_admin,status,info:{}}}` ([API:http/response/api/user.go#L21-L58](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/response/api/user.go#L21-L58)) | yok |
| `POST /api/oidc/auth` | [İSTEMCİ:src/hbbs_http/account.rs#L160-L176](../src/hbbs_http/account.rs) | `{op, id, uuid, deviceInfo}` | `{code, url}`; tarayıcıda `url` açılır | yok |
| `GET /api/oidc/auth-query?code&id&uuid` | `account.rs` (yoklama, zaman aşımı 5 dk) | – | bekleme: `{message,error}`; bitince `LoginRes` (yukarıdaki biçim) | yok |
| `POST /api/logout`, `POST /api/currentUser`, `GET /api/user/info` | Flutter | – | – | **Bearer** |
| `POST /api/heartbeat` | [İSTEMCİ:src/hbbs_http/sync.rs#L235-L262](../src/hbbs_http/sync.rs) | `{id, uuid, ver, conns?:[int], modified_at}` | `{}`; (Pro) `sysinfo`, `disconnect:[conn_id]`, `modified_at` | **yok** |
| `POST /api/sysinfo`, `/api/sysinfo_ver` | `sync.rs` | `{cpu, memory, os, hostname, username, mac, version, id, uuid, …}` | `SYSINFO_UPDATED` / `ID_NOT_FOUND` | **yok** |
| `POST /api/audit/conn`, `/api/audit/file` | [İSTEMCİ:src/server/connection.rs#L1429-L1440](../src/server/connection.rs), [`get_audit_server`: src/common.rs#L1300-L1307](../src/common.rs) | bkz. §4 | `""` | **yok** (başlık boş, `post_audit_async` → `post_request(url, body, "")`) |
| `/api/ab*`, `/api/users`, `/api/peers`, `/api/device-group/accessible` | adres defteri | – | – | **Bearer** |
| `/api/devices/cli`, `/api/devices/deploy`, `/api/record` | Pro özellikleri | – | rustdesk-api'de **yok**; istemci hatayı yutar (doğrulanmadı: her çağrı yolu için) | – |

**Önemli sonuçlar**
1. İstemci diyaloğu `email_check` yanıtı ve `email_code` istek türünü **zaten tanıyor** ([İSTEMCİ:flutter/lib/common/widgets/login.dart#L510-L535, #L687-L708](../flutter/lib/common/widgets/login.dart)), fakat **rustdesk-api bunu uygulamıyor**: `LoginForm` içinde `verificationCode`/`secret` alanı yok ve `Login()` `type` alanını okumuyor ([API:http/request/api/user.go#L28-L36](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/request/api/user.go#L28-L36)). Yani yerel bir "kod" akışı için istemci hazır ama sunucu yarısı yazılmalı; ayrıca bizim akışımız (önce e-posta ekranı, parolasız) bu hazır diyaloga birebir uymaz, M2Y'nin kendi ekranı gerekir.
2. `heartbeat` kimlik doğrulamasız olduğundan tasarım belgesindeki "her başarılı heartbeat'te 7 günlük süreyi sıfırla" için **belirteç doğrulayan bir uç gerekir**. Hazır olan: `POST /api/currentUser` (Bearer) → 200 = geçerli (ve belirteci kayan şekilde yeniler), 401 = reddedildi. M2Y istemcisi `m2y-last-auth-ok` değerini bu uçtan güncellemeli.
3. OIDC bekleme durumu **bellek içi `sync.Map`**'te (5 dk); API yeniden başlarsa bekleyen girişler düşer ([API:service/oauth.go#L60-L90](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/oauth.go#L60-L90)).

---

## 2. E-posta + tek kullanımlık kod girişi: seçenekler

**Ön bilgi (doğrulandı):** Kodda `smtp`, `gomail`, `SendMail` araması **sonuçsuz**; `mail` yalnızca LDAP/OIDC e-posta *alanı* olarak geçer. `go.mod` içinde e-posta kütüphanesi yok. **E-posta gönderme kodu yoktur, yazılmalıdır** (Go standart `net/smtp` 587+STARTTLS destekler; bakım için `wneessen/go-mail` gibi bir kütüphane daha rahat).
**Kullanıcı oluşturma ve oturum açma için yeniden kullanılabilir parçalar:** `UserService.Create/Register`, `UserService.Login(u, llog)` (belirteç + günlük + cihaz bağlama tek çağrıda), `LoginLimiter` (IP başına deneme/ban), `LoginRes`/`UserPayload` ([API:service/user.go#L97-L113, #L171-L185, #L429-L442](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L97-L113)).

### (a) Fork'a yalıtılmış `m2y` ekleri (yeni uçlar, mevcut `Login()` yeniden kullanılır)

- Yeni dosyalar: `http/controller/api/m2y_auth.go`, `service/m2y_mail.go`, `service/m2y_code.go`, `model/m2y_code.go`, `config/m2y.go` (SMTP bölümü); `http/router/api.go`'ya 2 satır; `cmd/apimain.go` içinde `AutoMigrate` listesine tablo + `DatabaseVersion` artışı.
- `kod-dogrula`: e-posta küçük harfe çevrilir; `InfoByEmail` ile kullanıcı bulunur, yoksa `Create` (`GroupId=1`, rastgele parola, durum 1); sonra `UserService.Login(...)` → bugünkü `LoginRes` aynen döner. İstemcideki mevcut `user_info`/`access_token` altyapısı değişmeden çalışır.
- Kod tablosu: `email, code_hash(SHA-256+tuz), expires_at, attempts, used_at, ip`; 6 hane, 10 dk, 5 yanlışta iptal, e-posta başına 15 dk'da 3 gönderim (tasarım belgesindeki kurallar).

| | |
|---|---|
| Artı | Tek süreç, tek veritabanı; belirteç/kullanıcı/grup/denetim/cihaz aynı yerde; web paneldeki kullanıcı listesi hemen e-postayla görünür; bizim yetkili belirteç, destek ve rapor uçları da aynı pakete girer; `Login()` sayesinde `login_logs`, cihaz bağlama bedavadır |
| Eksi | Kendi imajımızı derlemek ve yayınlamak gerekir (depoda `Dockerfile` var; SQLite sürücüsünün CGO gereksinimi ve imaj derleme ayrıntısı denenmedi, doğrulanmadı); upstream durağan olduğu için fork bakımı bizdedir; Vue yönetim paneli ayrı depo (§8) |
| Tahmini iş | **~3 iş günü**: posta servisi + yapılandırma 0,5 g; kod tablosu/hız sınırı/deneme sayacı 1 g; `kod-gonder`/`kod-dogrula` + Login bağlama 0,5 g; birim/entegrasyon testleri 0,5 g; imaj/CI ve nginx/`.env` 0,5 g |
| Güvenlik dikkati | Kod ve belirteç günlüğe yazılmaz; `kod-gonder` her zaman 200 (hesap var/yok sızdırmaz); sabit zamanlı karşılaştırma. **Opus ile yazılıp denetlenmeli** (kimlik/yetki) |

### (b) Ayrı ince servis (`m2y-auth`) + rustdesk-api yönetim API'si

- **"Kullanıcı adına belirteç üret" uç noktası YOK.** Yönetim API'sinde `user_token` için yalnızca `list`, `delete`, `batchDelete` var ([API:http/router/admin.go#L228-L234](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/router/admin.go#L228-L234)).
- Mümkün yollar:
  1. **Parola döndürme hilesi:** servis yönetici hesabıyla `POST /api/admin/user/create` (yoksa), `POST /api/admin/user/changePwd` (rastgele parola), sonra `POST /api/login` çağırıp gerçek belirteci alır. Çalışır, ama her girişte parola döner, `login_logs` yapay dolar, `disable-pwd-login` açılamaz, yönetici kimliği/parolası ince serviste durur (yüksek değerli sır) ve yönetici girişi captcha'ya takılabilir.
  2. **Doğrudan veritabanına yazma:** `user_tokens` satırı + (JWT açıksa) aynı `jwt.key` ile imzalı belirteç. Şemaya sıkı bağımlılık; upstream şema değişirse kırılır; iki yazar aynı DB'de.
  3. **Ters vekil olarak öne geçmek:** nginx `/api/m2y/*`'yi ince servise yönlendirir; yine 1. veya 2. gerekir.

| | |
|---|---|
| Artı | rustdesk-api imajı **hiç değişmez** (upstream'den doğrudan güncelleme); servis bağımsız dağıtılır/ölçeklenir; Go/Rust seçilebilir |
| Eksi | Yukarıdaki kırılganlıklar; iki servis, iki yapılandırma, bir izleme maddesi daha; yetkili belirteç, destek talebi ve oturum kaydı gene rustdesk-api verisine (kullanıcı, cihaz, denetim) ihtiyaç duyar → ya DB paylaşımı ya çok sayıda yönetim API çağrısı; "kimlik zorlaması sunucuda" hedefiyle uyumsuz bir ek saldırı yüzeyi |
| Tahmini iş | **~4 iş günü** yalnızca kod girişi için (servis 1,5 g + entegrasyon 1–1,5 g + dağıtım/vekil 0,5 g + test 0,5–1 g) ve kalıcı bakım yükü |

### (c) Diğer

- **Hazır `email_check` akışını sunucuda uygulamak** (istemci diyaloğunu kullanır): kullanıcı adı+parola gerektirir; M2Y'nin "yalnız e-posta" akışına uymaz. Reddedilir.
- **Google OIDC'yi tek yöntem yapmak**: e-posta+kod zorunlu kararıyla çelişir; yalnızca ek seçenek olarak zaten planlı (§3).

**Sonuç:** (a). Ayrıntılı kırılım §10'da.

---

## 3. OIDC (Google) girişi

| Soru | Cevap | Kaynak |
|---|---|---|
| Yeni kullanıcı otomatik oluşur mu? | **Evet**, yönetim panelindeki OAuth kaydında `auto_register` açıksa. Kapalıysa tarayıcı `/_admin/#/oauth/bind/<state>` sayfasına yönlendirilir (mevcut hesaba bağlama) | [API:http/controller/api/ouath.go#L216-L243](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/controller/api/ouath.go#L216-L243) |
| Kullanıcı nasıl oluşur? | `RegisterByOauth`: kullanıcı adı = `preferred_username` ya da küçük harfli e-posta (çakışırsa sonuna rakam), `GroupId=1`, **yönetici değil**, durum 1 (gorm varsayılanı) | [API:service/user.go#L321-L377](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L321-L377), [API:model/oauth.go#L98-L137](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/model/oauth.go#L98-L137) |
| E-posta saklanıyor mu? | **Evet**: `users.email` (küçük harfe çevrilerek), ayrıca `nickname`=ad, `avatar`; sağlayıcı bağı `user_thirds` tablosunda | aynı |
| Var olan e-postayla eşleşme | **Evet, otomatik**: aynı e-postalı kullanıcı varsa `user_thirds` bağlanır ve o kullanıcı olarak giriş yapılır. **`email_verified` kontrol edilmez** (yalnızca Google gibi doğrulamalı sağlayıcılarda güvenli; sonradan özel OIDC eklenirse hesap devralma riski) | [API:service/user.go#L338-L352](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L338-L352) |
| Belirli e-postayı otomatik admin yapma ayarı | **Yok** (`IsAdmin` yalnızca ilk kurulumdaki `admin` kullanıcısında ve panelden elle atanır). Çözüm: `mehmetmesut@gmail.com` e-postalı yönetici kullanıcıyı **önceden** oluştur (e-posta **küçük harf** olmalı: `InfoByEmail` tam eşleşme arar) → ilk Google girişinde otomatik bağlanır | [API:cmd/apimain.go#L337-L354](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/cmd/apimain.go#L337-L354), [API:service/user.go#L34-L38](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/user.go#L34-L38) |
| Silinemez/pasife alınamaz ("isProtected") | **Yok**: `User` modelinde böyle bir alan yok; `Delete` korumasız ([API:model/user.go](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/model/user.go), [API:http/controller/admin/user.go#L146-L169](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/controller/admin/user.go#L146-L169)). Sabit yönetici kuralı için fork'ta `IsProtected` + silme/pasifleştirme/yetki düşürme engeli gerekir (~0,5 g) |

Not: `User.Email` benzersiz değil (yalnızca indeks); iki kayıt aynı e-postayı taşıyabilir. M2Y kod girişinde e-posta için **benzersiz indeks + küçük harf normalizasyonu** eklenmeli.

---

## 4. Denetim / bağlantı günlükleri

### 4.1 İstemci ne bildiriyor?

Kontrol **edilen** taraf (bağlantıyı kabul eden cihaz) bildirir; kontrol eden bildirmez. Hedef URL: `<api>/api/audit/conn` (ve `/file`). Gövdeler ([İSTEMCİ:src/server/connection.rs#L1138-L1147, #L1385-L1400, #L1682-L1690](../src/server/connection.rs)):

| Zaman | Gövde |
|---|---|
| Bağlantı **geldiğinde** (parola/onay öncesi) | `{action:"new", ip, id:<hedef cihaz ID>, uuid, conn_id, session_id}` |
| **Doğrulama sonrası** | `{peer:[<kaynak ID>, <kaynak görünen ad>], type:0..4, id, uuid, conn_id, session_id}` (+ `primary_auth`, `two_factor`, `conn_audit_ref` sürüme göre) |
| Bağlantı **bittiğinde** | `{action:"close", id, uuid, conn_id, session_id}` |

`type`: 0 uzaktan masaüstü, 1 dosya aktarımı, 2 port yönlendirme, 3 kamera, 4 terminal. Kaynak adı `my_name` = kullanıcının `display_name`'i, yoksa işletim sistemi kullanıcı adı ([İSTEMCİ:src/client.rs#L2680-L2727](../src/client.rs)); **e-posta değil**.

### 4.2 rustdesk-api ne saklıyor?

`audit_conns` tablosu ([API:model/audit.go#L8-L21](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/model/audit.go#L8-L21), işleyici [API:http/controller/api/audit.go#L26-L59](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/controller/api/audit.go#L26-L59)):

| Alan | Anlam |
|---|---|
| `peer_id` | kontrol edilen cihaz ID'si |
| `from_peer`, `from_name` | kontrol eden ID'si ve görünen adı (**istemcinin kendi beyanı**) |
| `ip` | kontrol edenin IP'si (hedefin gördüğü) |
| `type`, `session_id`, `conn_id`, `uuid` | bağlantı türü / oturum / bağlantı sayacı / hedef cihaz UUID'si |
| `created_at` | `new` alındığı an (**doğrulamadan önce**) |
| `close_time` | `close` alındığı an (Unix sn) |
| `updated_at` | `new` sonrası her güncellemede değişir (doğrulama anı ve kapanış ikisi de bunu ezer) |

`audit_files` ayrıca dosya aktarım ayrıntısını (yol, adet, kaynak) tutar. Yönetim paneli listesi yalnızca `peer_id` ve `from_peer` ile arar; **tarih/ay filtresi yok**, dışa aktarma yok ([API:http/controller/admin/audit.go#L30-L46](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/controller/admin/audit.go#L30-L46)). Otomatik saklama süresi/temizleme **yok** (yalnızca elle `delete`/`batchDelete`).

### 4.3 Aylık danışan raporu için yeterli mi?

**Hayır, olduğu gibi yetmez.** Karşılaştırma (§ güvenlik-ve-destek-ozellikleri.md §7 isterleri):

| İster | Mevcut durum | Gereken |
|---|---|---|
| Denetleyen e-posta | yok (yalnızca beyan edilen ad + ID) | Yetkili belirteçteki doğrulanmış e-postayı kontrol edilen taraf denetim gövdesine koysun (yeni alan) |
| Danışan ad/e-posta/kuruluş | dolaylı: `peers.id` → `peers.user_id` → `users.email`/`group_id` (cihaz–kullanıcı bağı `login_logs` UUID eşleşmesiyle kurulur). Kuruluş için `Group` (kullanıcı grubu) kullanılabilir | Kuruluş adı alanı/grup ataması + rapor sorgusunda birleştirme |
| Süre (dk) | `close_time − created_at` (içinde parola bekleme süresi de var) | Doğrulama anını `authed_at` olarak sakla (`action==""` dalına bir alan); süre = `close_time − authed_at` |
| Bitiş güvenilirliği | `close` en iyi gayretle gönderilir (kuyruk `tx_post_seq`); program öldürülür/elektrik giderse **hiç gelmez** → `close_time=0` | Heartbeat gövdesindeki `conns` (canlı `conn_id`'ler, [İSTEMCİ:src/hbbs_http/sync.rs#L235-L242](../src/hbbs_http/sync.rs)) API'de işlensin: listede olmayan açık kayıt kapatılsın. Upstream `PeerInfoInHeartbeat` yalnızca `id, uuid, ver` okur ([API:http/request/api/peer.go#L75-L79](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/request/api/peer.go#L75-L79)) |
| Kısa not | yok | Yeni tablo `m2y_session_notes(audit_conn_id, author_email, note)` + uç |
| Aylık Excel/PDF | yok | Yönetim uçları `GET /api/admin/m2y/rapor?ay=YYYY-MM&…` (+ `.xlsx` için `excelize`, PDF için bir Go PDF kütüphanesi; ya da dışa aktarma yerel bir betikte) |
| Bütünlük | `audit/*` uçları **kimliksiz**: internetten herkes sahte `new/close` yollayabilir (rapor/faturalama için sakıncalı) | Kontrol edilen taraf kendi belirtecini `Authorization` başlığında göndersin (`post_request(url, body, header)` başlık parametresi var) ve API `peer_id` ile belirteç sahibinin cihazını eşleştirsin |

**Bonus (güvenilir kontrol):** heartbeat yanıtındaki `disconnect: [conn_id…]` istemcide zaten işleniyor ([İSTEMCİ:src/hbbs_http/sync.rs#L246-L255](../src/hbbs_http/sync.rs)); API bu alanı doldurursa yetkisiz/süresi dolmuş oturum **sunucudan sonlandırılabilir** (ek istemci kodu gerekmez; doğrulanmadı: yalnızca bağlantı sayacıyla kesim davranışı deneme gerektirir).

---

## 5. "Destek iste" için mevcut uç/kavram

- rustdesk-api'de **destek talebi/bilet kavramı yok**. Adres defteri, etiket, `share_record` (web istemci misafir bağlantısı; ayrıntı incelenmedi) ve `rustdesk/sendCmd` (hbbs yönetim komutları) başka işler içindir.
- Heartbeat'in sunucu→istemci kanalı (`sysinfo`, `disconnect`, `modified_at`) yalnızca bu alanlarla sınırlı; istemci tarafında yeni alan işlemek yeni kod gerektirir → **gerek yok**, yoklama yeterli.
- **Önerilen yer:** fork'ta (§2a ile aynı paket):
  - Tablo `m2y_support_requests(id, user_id, group_id, peer_id, note, status[açık/üstlenildi/kapandı], taken_by, created_at, closed_at)`.
  - `POST /api/m2y/destek` (**Bearer**, danışan): not, kuruluş (profil `Group`), cihaz ID'si (istemci kendi ID'sini gönderir); aynı kullanıcı için açık talep varken tekrar oluşturma (hız sınırı).
  - `GET /api/m2y/destek?durum=acik` (**yalnızca yetkili danışman rolü**): M2YDesk "Bekleyen talepler" listesi; satırdan tek tıkla normal bağlantı (cihaz ID'si hazır) + yetkili belirteç (§6). 30–60 sn yoklama yeterli.
  - Bildirim: aynı SMTP ile e-posta; WhatsApp (CallMeBot) sunucu betiği/`m2y` paketi içinden.
  - Danışan ekranı: `GET /api/m2y/destek/benim` ile durum ("Talebiniz iletildi").
- Tahmini iş: API 1 g + Hızlı Destek düğmesi/M2YDesk listesi (istemci tarafı ayrı kalem) .

---

## 6. Yetkili hesap belirteci: `LoginRequest` içinde kullanılabilir alan var mı?

`LoginRequest` ([İSTEMCİ:libs/hbb_common/protos/message.proto#L72-L91](../libs/hbb_common/protos/message.proto)) alanları ve uygunluk:

| Alan | Mevcut işlevi | Belirteç taşımaya uygun mu? |
|---|---|---|
| `username` (1) | hedef cihaz ID'si (`pure_id`) | Hayır |
| `password` (2) | sabit/geçici parola doğrulaması | Hayır; parola akışını bozar. Gözetimsiz erişimde parola ve belirteç **birlikte** gerekli |
| `my_id` (4), `my_name` (5) | kontrol edenin ID'si/adı; **bağlantı penceresinde (CM) görünür** ve **denetime yazılır** (`from_name`) | Hayır: belirteç UI'de/günlükte görünür, ayrıca `trusted device` eşleşmesi `my_name`'e bağlı ([İSTEMCİ:src/server/connection.rs#L2455-L2461](../src/server/connection.rs)) |
| `option` (6) `OptionMessage` | yalnızca sabit alanlar (kalite, ses, pano…), serbest metin yok | Hayır |
| `os_login` (12) | hedefte Windows kullanıcı adı/parolası ile oturum açma | Hayır; anlam kaydırma tehlikeli (parola alanı gibi işlenir) |
| `session_id` (10) | uint64 sayaç | Hayır |
| `version` (11) | sürüm karşılaştırmaları (`get_version_number`) | Hayır; sürüm sınamalarını bozar |
| `my_platform` (13) | OS adı; pano/kısayol davranışı buna bağlı | Hayır |
| `hwid` (14) | "bu cihaza güven" (2FA) için donanım kimliği | Hayır |
| `avatar` (17) | kontrol edenin avatarı; CM'de gösterilir | Teknik olarak serbest string ama UI'de işlenir/önbelleğe alınır; hack |
| `union` (7,8,15,16) | bağlantı türü | Hayır |

**Sonuç:** Güvenle kullanılabilecek mevcut alan **yok**. **Proto değişikliği gerekir**, ve düşük riskli:
- `libs/hbb_common` bu depoda **izleniyor** (alt modül değil; `git ls-files libs/hbb_common` dosyaları listeliyor, `.gitmodules` yok) → `message.proto`'ya `bytes m2y_auth = 100;` (üst sayıdan başlamak, upstream'in yeni alan numaralarıyla çakışmayı önler) eklenebilir. Protobuf **bilinmeyen alanları yok sayar**: stok RustDesk istemcileri ve hbbs/hbbr etkilenmez (hbbs LoginRequest'i görmez; iki istemci arasında şifreli akar).
- İstemci tarafı: `LoginRequest { …, ..Default::default() }` kalıbı zaten kullanılıyor ([İSTEMCİ:src/client.rs#L2723-L2741](../src/client.rs)) → alanı eklemek mevcut kodu bozmaz; yeni alan `lr.m2y_auth = token` olarak atanır. Doğrulama `handle_login_request_without_validation`/`on_message` içinde ([İSTEMCİ:src/server/connection.rs#L2449, #L2525](../src/server/connection.rs)).
- Ed25519 doğrulaması için `sodiumoxide::crypto::sign` istemcide zaten kullanılıyor ([İSTEMCİ:src/client.rs#L62](../src/client.rs), [`libs/hbb_common/src/m2y.rs`](../libs/hbb_common/src/m2y.rs)); ek bağımlılık gerekmez (Go tarafı `crypto/ed25519`, standart kütüphane).

**Tasarım önerileri (belirtecin güvenliği için)**
1. **Hedefe bağla (`aud`)**: tasarım belgesindeki "12 saat, genel" belirteç, bir danışmanın belirteci kötü niyetli/ele geçirilmiş **kontrol edilen** bir cihaza gönderildiğinde başka cihazlarda tekrar kullanılabilir demektir. Önerilen: belirteç **bağlantı başına** istenir: `POST /api/m2y/yetki-belirteci {hedef_id}` → `{email, rol, aud:hedef_id, jti, exp(≤5 dk)}`; kontrol edilen taraf `aud == kendi ID'si`, `exp` ve imzayı doğrular. Aksi halde belirteç çalma = 12 saat boyunca tüm cihazlar.
2. Doğrulama sonrası **e-posta ve rol** kontrol edilen tarafın denetim gövdesine yazılır (§4.3 "Denetleyen e-posta"): denetim güvenilir hale gelir.
3. Süreli imzalı belirteç **çevrimdışı doğrulanır** (açık anahtar istemciye gömülü), danışan cihaz API'ye ulaşamasa da çalışır; ancak danışmanın belirteç alması için çevrimiçi olması gerekir (kabul edilebilir).
4. Anahtar dönüşümü: `kid` alanı + istemcide birden çok açık anahtar (tasarım belgesiyle uyumlu).

---

## 7. Yönetim panelinde cihaz listesi ve MAC alanı

### 7.1 Bugünkü cihaz modeli

`peers` ([API:model/peer.go](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/model/peer.go)): `id, cpu, hostname, memory, os, username, uuid, version, user_id (+User), last_online_time, last_online_ip, group_id, alias, created_at, updated_at`.

| İstenen | Var mı? |
|---|---|
| Takma ad | **Evet** (`alias`; panelden düzenlenir, `alias like` ile aranır) |
| Grup | **Evet** (`group_id`) |
| Son IP | **Evet** (`last_online_ip`; heartbeat'te en geç 30 sn'de bir güncellenir) |
| Çevrimiçi durumu | Sunucuda **bayrak yok**; yalnızca `last_online_time`. Panel/`time_ago` filtresi bu zamandan türetir ([API:http/controller/api/index.go#L125-L147](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/controller/api/index.go#L125-L147), [API:http/controller/admin/peer.go#L96-L101](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/controller/admin/peer.go#L96-L101)); sütunun görünümü Vue kaynağında (**okunmadı**, doğrulanmadı) |
| Sahip kullanıcı | **Evet** (`user_id`, `login_logs` UUID eşleşmesiyle kurulur) |
| MAC | **Yok** |

### 7.2 MAC için değişecek dosyalar (API tarafı)

| # | Dosya | Değişiklik |
|---|---|---|
| 1 | `model/peer.go` | `Mac string \`json:"mac" gorm:"default:'';not null;"\`` |
| 2 | `http/request/api/peer.go` | `PeerForm.Mac` + `ToPeer()` içinde atama (istemci `sysinfo`'da `mac` gönderiyor: [İSTEMCİ:src/common.rs#L900-L904](../src/common.rs)). `SysInfo` işleyicisi **değişmez**: `Update` gorm `Updates(struct)` kullanır, sıfır olmayan alanları yazar ([API:service/peer.go#L151-L153](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/service/peer.go#L151-L153)) |
| 3 | `http/request/admin/peer.go` | `PeerForm.Mac` (+ `ToPeer`), `PeerQuery.Mac` |
| 4 | `http/controller/admin/peer.go` | `List` içinde `mac like ?` filtresi |
| 5 | `cmd/apimain.go` | `DatabaseVersion` 265 → 266: `AutoMigrate` yalnızca sürüm artınca çalışır, `Peer` zaten listede ([API:cmd/apimain.go#L26, #L259-L266](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/cmd/apimain.go#L26)) |
| 6 | (isteğe bağlı) `docs/` swagger | `swag init` ile yeniden üret |

Panel sütunu için ayrı depo: **`lejianwen/rustdesk-api-web`** (Vue 3.5 + Element Plus + Pinia + Vite; son commit 31.08.2025). Orada cihaz listesi ve düzenleme sayfasına `mac` sütunu/arama alanı + dil dosyaları eklenir (dosya yolu **okunmadı**, doğrulanmadı), sonra `vite build` çıktısı API imajının `resources/admin/` klasörüne konur (API deposunda `resources/admin` yok; imaja yayın sırasında girer). **MAC'i panelde göstermeden yalnızca API'de saklamak** da mümkündür (veritabanından/sorguyla okunur); panel değişikliği ayrı kararlaştırılabilir. Tahmini iş: API tarafı ~0,5 g, panel +0,5 g.

---

## 8. Yönetim paneli (Vue) hakkında önemli not

- M2Y'ye özgü yönetim ekranları (yetkili danışmanlar listesi, bekleyen destek talepleri, oturum raporu + Excel/PDF, kuruluş atama, MAC sütunu) için **`rustdesk-api-web` fork'u gerekir**. Alternatif: M2Y sayfalarını fork'taki API imajından servis edilen küçük bir bağımsız statik yönetim sayfası olarak yazmak; fakat panelin `api-token`'ı nerede tuttuğu (çerez/localStorage) doğrulanmadı, bu yüzden Vue fork'u daha öngörülebilir.
- İlk aşamada yönetim işleri panelsiz yürütülebilir: yetkili liste/rapor uçları `curl` ile, rapor Excel'i yerel betikle.

---

## 9. Yan bulgular (güvenlik ve dayanıklılık)

| # | Bulgu | Etki | Öneri |
|---|---|---|---|
| G1 | `heartbeat`, `sysinfo`, `sysinfo_ver`, `audit/conn`, `audit/file` **kimliksiz** ([API:http/router/api.go#L31-L74](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/router/api.go#L31-L74)) | Sahte cihaz/denetim kaydı, kayıt şişirme, sahte "çevrimiçi" | Hız sınırı (nginx `limit_req`), `audit/*` için cihaz belirteci (§4.3), `heartbeat` yalnızca UUID'nin **boş olmadığına** bakar, kayıtlı UUID ile **karşılaştırmaz** ([API:http/controller/api/index.go#L132-L138](https://github.com/lejianwen/rustdesk-api/blob/c5687e1/http/controller/api/index.go#L132-L138)); fork'ta `peer.Uuid == info.Uuid` kontrolü eklensin |
| G2 | MD5 tabanlı belirteç: `jwt.key` boşken belirteç = `MD5(kullanıcıAdı + zaman)` | Düşük entropi (kullanıcı adı bilinirse, giriş anı tahminiyle zorlanabilir) | Fork'ta `crypto/rand` 32 bayt kullan **veya** en azından `RUSTDESK_API_JWT_KEY` ayarla (RustAuth hem JWT hem tablo ister) |
| G3 | OIDC e-posta eşleştirmesi `email_verified` kontrol etmez | Özel OIDC sağlayıcıda hesap devralma | Yalnızca Google (doğrulamalı) kullan; fork'ta `VerifiedEmail` zorunlu kıl |
| G4 | İlk `admin` parolası günlüğe yazılır, yönetici paneli herkese açık `/_admin/` | İlk kurulumda sızıntı | nginx'te `/_admin` zaten IP kısıtlı (mevcut kurulum); parola değiştirilmeli |
| G5 | `token-expire` boşsa belirteç anında süresi dolar (§1.1) | Beklenmeyen oturum düşmesi | Yapılandırmayı sabitle |
| G6 | OIDC bekleme durumu bellekte | API yeniden başlamasında yarım girişler düşer | Önemsiz; kod girişi veritabanı kullanır |

---

## 10. Önerilen yol ve iş kırılımı

**Karar: (a) rustdesk-api fork'u + yalıtılmış `m2y` paketi, tek imaj.** Gerekçe: kullanıcı, belirteç, grup, cihaz, denetim ve yönetici kimlik doğrulaması zaten orada; (b) şemaya bağımlı/hacky; upstream bir yıldır durağan olduğundan fork bakımı gerçekçi bir ek yük değil. Çakışmayı en aza indirmek için tüm eklemeler `m2y_*.go` dosyalarında ve router/migrate dosyalarında **tek satırlık** eklerle yapılır; `LICENSE` (MIT) korunur; fork **özel depoda** `mehmetmesut` altında tutulur.

| Sıra | İş | Gün | Model* | Bağımlılık |
|---|---|---|---|---|
| 1 | Fork + derleme/imaj hattı (Docker, mevcut kompozeye eklenir), `jwt.key`, `token-expire=168h`, `crypto/rand` belirteç yaması (G2), `IsProtected` yönetici koruması (§3) | 1 | Opus (güvenlik) | – |
| 2 | **SMTP + kod girişi**: `m2y_mail`, `m2y_code`, `kod-gonder`/`kod-dogrula`, hız sınırı, testler (§2a) | 3 | Opus yaz, Sonnet testleri | SMTP bilgisi (kullanıcı `.env`'e girer) |
| 3 | `POST /api/currentUser` tabanlı oturum doğrulama + istemcide `m2y-last-auth-ok` (7 gün kayan çevrimdışı tolerans) | 0,5 (+istemci) | Sonnet | 2 |
| 4 | **Yetkili belirteç**: tablo `m2y_authorized(email, role, added_by)` (tohum: iki e-posta), `POST /api/m2y/yetki-belirteci {hedef_id}` Ed25519, anahtar `.env`; proto alanı `m2y_auth=100`; istemcide ekleme ve doğrulama; reddetme iletisi | 2 API + 2 istemci | Opus | 2, anahtar çifti (kullanıcı üretir) |
| 5 | **Denetim yamaları**: `authed_at`, denetleyen e-posta alanı, `audit/*` için cihaz belirteci, heartbeat `conns` ile kapanış, 90/365 gün saklama işi (KVKK), kısa not tablosu/ucu | 2 | Opus (bütünlük), Sonnet (CRUD) | 4 |
| 6 | **Destek iste**: tablo + uçlar + e-posta bildirimi + yetkili listesi uç (§5) | 1 API (+istemci) | Sonnet | 2, 4 |
| 7 | **Aylık rapor** uçları (JSON + `.xlsx`, PDF) ve kuruluş=Group eşlemesi | 1,5 | Sonnet | 5 |
| 8 | **MAC alanı** (API) (§7) | 0,5 | Haiku/Sonnet | – |
| 9 | **Vue panel fork'u**: "Yetkili danışmanlar", "Bekleyen talepler", "Oturumlar/rapor", MAC sütunu | 3 | Sonnet | 4–8 |
| 10 | Google OIDC yapılandırması: OAuth istemcisi, `auto_register`, önceden oluşturulmuş yönetici kullanıcı (küçük harf e-posta) | 0,5 | Sonnet | 2 |
| | **Toplam (API/panel)** | **≈ 15–16** | | istemci işleri ayrı |

*Model: `~/.claude/rules/common/model-secimi.md`'e göre; kimlik/yetki/belirteç/denetim bütünlüğü Opus.

**Sıralama notu:** 1 → 2 → (3, 10) → 4 → 5 → (6, 7, 8) → 9. Tasarım belgesindeki "SMTP ve hesap API'si hazır olmadan 1.0.2 dağıtılmaz" kuralı korunur.

### Doğrulanmadı / kullanıcı kararı gerekenler
1. `rustdesk-api-web` içindeki cihaz listesinin sütun/durum mantığı ve dosya yolları (kaynak okunmadı).
2. `share_record` modelinin tam kapsamı ("Destek iste" ile ilgisiz görünüyor, okunmadı).
3. Heartbeat `disconnect` ile kontrol edilen cihazda oturum kesilmesinin gerçek davranışı (istemci kodu var; uçtan uca deneme yapılmadı).
4. `/api/devices/*` ve `/api/record` çağrılarının yokluğunda istemcinin sessiz kalması (tüm çağrı yolları okunmadı).
5. **Karar:** belirteç **bağlantı başına, hedefe bağlı, ≤5 dk** (öneri) mi, yoksa tasarım belgesindeki **12 saatlik genel** belirteç mi? Birincisi daha güvenli ama kontrol edenin bağlantı anında çevrimiçi olmasını gerektirir.
6. **Karar:** M2Y yönetim ekranları için Vue fork'u (öneri) mi, panelsiz `curl`/betik mi (ilk sürüm)?
