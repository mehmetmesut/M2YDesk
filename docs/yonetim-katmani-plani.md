# M2YDesk Yönetim Katmanı Planı (Pro özelliklerinin kendi çözümümüzle karşılanması)

Amaç: RustDesk Server Pro'da lisansla gelen özellikleri, yalnızca kendi danışmanlık iş sürecimiz için, kendi sunucumuzda (`desk.mehmetmesut.com`) karşılamak. Durum: **plan**, henüz kodlanmadı. Üst belge: [`gelistirme-plani.md`](gelistirme-plani.md). Devir/durum: [`DEVIR.md`](DEVIR.md).

## Kararlar (kullanıcıdan)
- Üye olan: sınırsız süre ve sınırsız eş zamanlı bağlantı.
- Üye olmayan (oturum açmamış) kullanıcı: toplamda en fazla **5 eş zamanlı** oturum; her oturum **5 dk**, kopunca **2 dk** bekleme. Amaç, programı keşfedenleri üyeliğe teşvik etmek. Kural, kullanıcı adı+parola veya Google ile oturum açmamış herkese uygulanır.
- Ürün yalnızca kullanıcının kendi danışmanlık verdiği kişi/kurumlar için kullanılır.

## Hedef özellikler ve karşılıkları

| # | İstenen | Yaklaşım | Bileşen | Risk |
|---|---|---|---|---|
| 1 | Hesap girişi, adres defteri | Topluluk API sunucusu (istemcinin `api-server` ayarı). Aday: `lejianwen/rustdesk-api` (Go). **Lisans/güncellik/uyumluluk ön kontrol şart** | Sunucuda Docker | Orta |
| 2 | Denetim günlüğü | API sunucusunun bağlantı/oturum kayıtları; eksikse istemci `audit` uçlarına kendi kayıt servisimizi ekleriz | API + gerekirse küçük servis | Orta |
| 3 | Web yönetim konsolu | API sunucusunun yönetim paneli (varsa), yoksa küçük panel | API | Düşük |
| 4 | Cihaz/grup ve rol yönetimi | API sunucusundaki kullanıcı/grup/cihaz modeli; eksik roller için ekleme | API | Orta |
| 5 | SSO / LDAP / 2FA | OIDC ve 2FA'yı API sunucusu destekliyorsa etkinleştir; LDAP desteklenmiyorsa OIDC + 2FA ile başla | API | Orta |
| 6 | Web istemcisi | hbbs WebSocket (21118/21119) zaten açık. Web istemcisi kodunun açık kaynak durumu **araştırılacak**; yoksa ertelenir | Statik site + WS | Yüksek |
| 7 | Yeni sürümü cihazlara gönderme (otomatik güncelleme) | Fork'ta güncelleme denetimini `https://desk.mehmetmesut.com/guncelleme/surum.json` adresine çevir; Windows kurulum sürümünde sessiz güncelleme; imza/sağlama toplamı kontrolü | İstemci kodu + site | Orta |
| 8 | iOS | Resmî RustDesk iOS uygulaması özel sunucu + API adresi + anahtarla çalışır. Kendi iOS derlemesi Apple geliştirici hesabı (TestFlight) gerektirir; **başlangıçta resmî uygulama + QR ile ayar** | Site (QR var) | Düşük |
| 9 | Üye olmayana 5 eş zamanlı + 5 dk / 2 dk kuralı | İki relay (üye: 21117 sınırsız, üye olmayan: 21127) + `ALWAYS_USE_RELAY=Y` + iptables `connlimit` (5 oturum ≈ 10 TCP); süre/bekleme kuralı istemcide | Sunucu + istemci | Orta |

## Aşamalar

**Aşama 0 — Zemin (sürüyor).** 1.0.0 derlemesi, dosyaların `indir/` altına konması, anahtarsız ayar gerektirmeyen ilk bağlantı testi. Bitmeden Aşama 1'e geçilmez.

**Aşama 1 — Hesap/API sunucusu (öncelikli, 1–3 gün).**
1. Aday projeyi değerlendir: lisans (AGPL/MIT?), son güncelleme, OIDC/2FA/LDAP, denetim günlüğü, adres defteri, rol modeli, Docker desteği. Sonucu kısa rapor olarak yaz.
2. `desk.mehmetmesut.com/panel` (veya `panel.` alt alanı) altında Docker ile kur; Plesk ters vekil + Let's Encrypt.
3. Yönetici hesabı (Sabit Yönetici Hesabı kuralı), yedekleme (`yedekleme.sh` kapsamına), KVKK: kayıt saklama süresi ve aydınlatma metni.
4. `res/m2y/m2ydesk.json` içine `api-server` eklenir (yalnızca tam istemci; Hızlı Destek'te hesap kapalı kalır).

**Aşama 2 — Güncelleme mekanizması (2–3 gün).** Fork'ta sürüm denetimi ve sessiz güncelleme; `istemci-hazirla.sh` sürüm dosyasını üretir; imza yokluğunda SHA-256 doğrulaması. İlk sürümden önce mevcut kurulumlar bunu bilemez, bu yüzden Aşama 2 **ilk dağıtılan sürüme dahil edilmelidir**.

**Aşama 3 — Üye/üye olmayan sınırları (3–5 gün).**
1. İkinci hbbr konteyneri (`21127`), hbbs `ALWAYS_USE_RELAY=Y`.
2. iptables `connlimit` kuralları (kalıcı, `netfilter-persistent`).
3. İstemci: giriş yoksa relay `:21127`, 5. dakikada oturumu kapat, 2 dk yeniden bağlanma engeli; giriş varsa `:21117`, sınırsız. Kullanıcıya açık mesaj.
4. Sınırlar: süre kuralı istemcide (kaynak açık olduğundan atlatılabilir); 5 oturum sınırı sunucuda. Gerekirse sonradan hbbr çatalı ile sunucu tarafı süre kesme.

**Aşama 4 — Denetim, roller, 2FA/OIDC ince ayar (2–4 gün).** Panel yapılandırması, rol matrisi, kayıt dışa aktarma (Excel/CSV).

**Aşama 5 — Web istemcisi ve iOS (araştırma sonrası).** Açık kaynak web istemcisi bulunursa 21118/21119 üzerinden yayınla; iOS için TestFlight kararı.

## Bağımlılıklar
Aşama 0 → 1 → (2, 3 paralel) → 4 → 5. Aşama 3'ün istemci kısmı ve Aşama 2 tek yeni derleme ile çıkabilir.

## Hukuki not (AGPL-3.0)
Ürün ticari olarak satılmıyor, ancak danışanlar istemciyi sitemizden indiriyor; bu, dağıtım sayılır. AGPL, istemcinin (değiştirilmiş) kaynağının bu kullanıcılara sunulmasını ister. Depo özel kaldıkça bu yükümlülük ayrıca ele alınmalıdır (kaynak talep üzerine verilir ya da depo açılır). Kesin hukuki görüş için bir avukata danışın.

## Açık sorular
1. Aday API sunucusu lisansı ve OIDC/LDAP kapsamı (Aşama 1'de netleşir).
2. Web istemcisi için açık kaynak seçenek var mı.
3. KARAR: LDAP şart değil. Kayıt ve giriş: e-posta+parola ve Google (OIDC); 2FA (TOTP) isteğe bağlı. Amaç kolaylık ve üyeliğe teşvik. LDAP/Entra ID, kurumsal talep gelirse OIDC üzerine eklenir.
4. Apple geliştirici hesabı alınacak mı.
