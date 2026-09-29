# Hesap ve Google ile giriş (kurulum + kullanım)

**Durum:** İstemci tarafı hazır (kod + yapılandırma). Sunucu tarafı (API) **henüz kurulu değil**; aşağıdaki adımlar yerel oturum/kullanıcı içindir. Yeni sürüm dağıtılmadan önce API çalışıyor olmalı.

## Ne değişti (istemci)
| Öğe | Değişiklik |
|---|---|
| `res/m2y/m2ydesk.json` | `disable-account` ve `disable-ab` **kaldırıldı** → Ayarlar'da **Hesap** (e-posta/parola + **Google**) ve **Adres Defteri** açıldı |
| `api-server` | `https://desk.mehmetmesut.com` (istemci `/api/login-options`, `/api/oidc/auth`, `/api/login` çağırır) |
| `m2y-nonmember-limit` | `Y`: girişsiz kullanıcı 5 dk oturum + 2 dk bekleme + relay :21127; **giriş yapan = üye = sınırsız** |
| Hızlı Destek | Giriş/ayar yok (`disable-account` duruyor); danışan hesap açmaz |

> ⚠️ Bu sürümü kurup API çalışmazsa **siz de** üye olamayacağınız için 5 dk sınırına takılırsınız. Sıra: API'yi kur → giriş dene → sonra sürümü dağıt.

## Sunucuda kurulum (yerel oturum, SSH)
```bash
cd /opt/m2ydesk && sudo git pull
cd server
# API + Google girişi
sudo docker compose --profile api up -d
sudo docker logs m2y-api | head -30      # ilk açılışta 'admin' parolası burada yazar → HEMEN değiştirin
```
1. Plesk → `desk.mehmetmesut.com` → Apache ve nginx Ayarları → **Ek nginx yönergeleri**: `server/plesk-nginx.conf.example` içeriği. `/_admin/` için kendi IP'nizi `allow` edin.
2. `https://desk.mehmetmesut.com/_admin/` → `admin` ile giriş → parolayı değiştir.
3. Doğrula: `curl -s https://desk.mehmetmesut.com/api/login-options` → JSON dönmeli (Google eklenince `oidc/…` görünür).

> ❓ Ortam değişkeni adları (`RUSTDESK_API_*`) imajın README'sinden hatırlanarak yazıldı, doğrulanmadı. Hata olursa `docker logs m2y-api` ve https://github.com/lejianwen/rustdesk-api README'sine bakın.

## Google ile giriş (OIDC) — sizin yapacağınız
1. https://console.cloud.google.com → proje oluştur → **APIs & Services → OAuth consent screen**: Kullanıcı türü **External**, uygulama adı `M2YDesk`, destek e-postası `mehmetmesut@gmail.com`. Yayın durumu:
   - **Testing** + Test users'a yalnızca izin vereceğiniz Gmail hesaplarını ekleyin (en fazla 100) → giriş yalnızca onlara açık, **Google doğrulaması gerekmez**; ya da
   - **In production** (herkes girebilir; temel kapsamlar `openid email profile` için genelde doğrulama gerekmez).
2. **Credentials → Create credentials → OAuth client ID** → Web application. **Authorized redirect URI:** yönetim panelinde OAuth/OIDC ekranında gösterilen adres (❓ büyük olasılıkla `https://desk.mehmetmesut.com/api/oidc/callback`; panelde yazan adresi aynen kullanın).
3. `Client ID` ve `Client secret`'ı **yalnızca yönetim paneline** girin (`/_admin/` → OAuth → Google/OIDC: Issuer `https://accounts.google.com`). **Bana veya depoya yazmayın.**
4. Panelde otomatik kayıt açık olsun (yeni Google kullanıcısı otomatik hesap açsın). İlk giriş yaptıktan sonra `mehmetmesut@gmail.com` kullanıcısını panelde **yönetici (admin)** yapın → süper admin.
5. **2FA:** Google hesabının kendi 2 adımlı doğrulaması yeterli kabul edildi (karar 29.09.2026).

## Kullanıcı akışı (istemci)
Ayarlar → **Hesap** → *Giriş yap* → **Google** düğmesi → tarayıcıda Google onayı → istemci otomatik giriş yapar (`access_token` + `user_info` saklanır) → artık **üye**: süre/bekleme sınırı yok, adres defteri açık.

## İkinci relay ve sınır (dışa dönük, ayrı onay)
```bash
sudo docker compose --profile limit up -d        # hbbr2 :21127 (güvenlik duvarında TCP 21127 açın)
sudo bash scripts/relay-siniri.sh ekle           # connlimit: 10 bağlantı = 5 oturum (kullanıcı onayıyla)
```
Doğrulama: gerçek bir bağlantıda `docker logs hbbs` içinde hangi relay adresinin verildiğine ve `docker logs hbbr2` içinde bağlantı olup olmadığına bakın. Girişsiz bir istemciyle bağlanınca `hbbr2`'de bağlantı görünmüyorsa relay'i karşı taraf seçiyor demektir (bkz. `uye-kurallari.md` §Relay).

## Bilinen sınırlar
- Web istemci kapalı (`RUSTDESK_API_APP_WEB_CLIENT=0`): lisans/AGPL kapsamı doğrulanana kadar.
- API'de MAC alanı yok (fork yapılmadı); MAC yalnızca istemciden gönderilir, API bilinmeyen alanı yok sayar → envanterde MAC görünmez.
- Engelleme: `guncelleme/engel.json` (hash listesi) elle yönetilir.
