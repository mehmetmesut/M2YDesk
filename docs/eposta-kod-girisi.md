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
- Tam M2YDesk'te Google ile giriş **ek seçenek** olarak aynı ekranda kalabilir (❓ kullanıcı onayı); e-posta+kod birincil.

## Sunucu (yeni ince servis veya API eki)
- Uçlar: `POST /api/m2y/kod-gonder {email}` → her zaman 200 (hesap var/yok sızdırmaz); `POST /api/m2y/kod-dogrula {email, kod}` → `access_token` + `user` (rustdesk-api kullanıcısıyla eşleşmiş/oluşturulmuş).
- ❓ `lejianwen/rustdesk-api` e-posta kodu ile girişi destekliyor mu → bulut araştırsın. Desteklemiyorsa: ayrı Go/Rust ince servis (`m2y-auth`) kodu doğrular, rustdesk-api'de kullanıcıyı bulur/oluşturur ve onun token'ını döndürür; ya da rustdesk-api'ye MIT yaması.
- Kod: 6 hane, **10 dk** geçerli, tek kullanımlık; sunucuda yalnızca **hash** saklanır; sabit zamanlı karşılaştırma; e-posta başına **5 hatalı deneme** → kod iptal.
- Hız sınırı: e-posta başına 15 dk'da 3 gönderim, IP başına saatte 10; aşımda 429.
- Kod ve token **günlüğe yazılmaz**.
- E-posta gönderimi: Plesk posta (ör. `noreply@mehmetmesut.com`), SMTP 587 + STARTTLS. **SMTP parolası yalnızca sunucu `.env`'inde** (depoya/sohbete yazılmaz; kullanıcı kendisi girer). SPF/DKIM/DMARC `mehmetmesut.com` için doğrulanmalı (spam'e düşmesin).
- E-posta içeriği (Türkçe, sade): "M2YDesk doğrulama kodunuz: 123456 — 10 dakika geçerlidir. Bu isteği siz yapmadıysanız dikkate almayın." + footer kredisi.

## Sonuçlar ve riskler (dürüst not)
1. **Üye olmayan kuralları (5 dk / 2 dk, 5 eşzamanlı) fiilen devre dışı kalır:** giriş zorunlu olunca herkes üye olur. Kuralın amacı (üyeliğe teşvik) zaten zorunlulukla karşılanmış olur. ❓ Kullanıcı: kurallar kaldırılsın mı, yoksa ileride "onaylanmamış üye" gibi bir ara statüye mi uygulansın?
2. **Sunucu erişilemezse kimse ilk girişi yapamaz** → destek alamaz. Öneri: daha önce oturum açmış cihazda token önbellekte geçerli kalır (çevrimdışı tolerans, ör. 30 gün); yalnızca ilk giriş sunucu ister.
3. **E-posta teslimi:** kod spam'e düşerse danışan bağlanamaz → SPF/DKIM şart; ekranda "spam klasörünü kontrol edin" notu.
4. **KVKK:** e-posta kişisel veridir; aydınlatma metni + açık rıza; saklama süresi ve silme talebi panelde.
5. Kaynak açık olduğundan değiştirilmiş istemci giriş ekranını atlayabilir; asıl zorlama sunucuda olmalı (ör. hbbs/relay'de token doğrulaması — ileri aşama). Şimdilik istemci tarafı zorlama + API'de cihaz kaydı.
6. Bağımlılık: hesap API'si (Y2) ve SMTP kurulmadan bu sürüm **dağıtılmaz**; aksi hâlde kimse programı kullanamaz.
