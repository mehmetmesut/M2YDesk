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
