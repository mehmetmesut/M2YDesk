# Güvenlik ve destek özellikleri (kararlar, 04.10.2026)

**Durum:** Kullanıcı kararları; kodlanmadı. Uygulayıcı: bulut oturumu (istemci/API/CI kodu), yerel oturum (sunucu kurulumu, izleme, imza anahtarları). Tüm özellikler tek "gerçek doğrulama derlemesi"nde (1.0.2) birleşir.

## 1. Gözetimsiz erişim için otomatik başlatma (Hızlı Destek)
- Sürekli erişim açıkken Hızlı Destek **Windows oturum açılışında arka planda** (tepsi simgesiyle) başlar; kapatılınca tepsiye iner. Sürekli erişim kapatılınca otomatik başlatma da kaldırılır.
- Uygulama: kullanıcı başlangıcı (`HKCU\...\Run` veya Başlangıç klasörü, yönetici izni gerekmez). ❓ Oturum açılmamış Windows ekranında (kilit/giriş ekranı) erişim hizmet (service) gerektirir; Hızlı Destek taşınabilir olduğundan **kullanıcı oturumu açıkken** çalışır. Kilit ekranı erişimi gerekirse "tam M2YDesk kurulumu" önerilir (bilinçli sınır, kullanıcıya bildirildi).

## 2. Yalnızca yetkili hesaplardan gelen bağlantıyı kabul et
- **Kural:** Hızlı Destek (ve gözetimsiz erişimde M2YDesk) gelen bağlantıyı **yalnızca** oturumu şu e-postalardan biriyle açılmış bir denetleyiciden kabul eder: `mehmetmesut@gmail.com`, `mehmetmesut.yilmaz@antalya.edu.tr` + süper adminin panelden **sonradan ekleyeceği danışmanlar**.
- RustDesk'te denetleyicinin hesabı kriptografik olarak doğrulanmaz (`LoginRequest` ad/ID taşır, taklit edilebilir) → **imzalı yetki belirteci** gerekir:
  1. API, oturum açmış ve yetkili listede olan kullanıcıya kısa ömürlü (ör. 12 sa) **Ed25519 imzalı belirteç** verir: `{email, rol, exp}`.
  2. Denetleyici istemci bunu `LoginRequest`'e ek alan/seçenek olarak koyar.
  3. Kontrol edilen taraf, istemciye **gömülü sunucu açık anahtarıyla** imzayı ve süreyi doğrular; yetki listesi belirtecin içindeki role dayanır (liste API'de tutulur, istemciye gömülmez → yeni danışman eklemek yeni sürüm gerektirmez).
  4. Belirteç yoksa/geçersizse bağlantı reddedilir ("Bu cihaza yalnızca yetkili danışmanlar bağlanabilir").
- İmza anahtarının özel kısmı **yalnızca API sunucusunda** (ortam değişkeni/dosya, 600); depoya/sohbete girmez. Açık anahtar derlemede gömülür (`M2Y_AUTH_PUBKEY` değişkeni).
- Panelde süper admin: "Yetkili danışmanlar" listesi (ekle/kaldır), her değişiklik denetim günlüğüne.
- ❓ Kaynak açık: değiştirilmiş bir **kontrol edilen** istemci kuralı atlayabilir ama bu yalnızca kendi cihazını açar (danışanı korumak amaçlı; saldırganın işine yaramaz). Denetleyici tarafında taklit imzasız belirteçle mümkün değil.

## 3. Sunucu izleme ve alarm
- Sunucuda 5 dk'da bir çalışan betik (`server/scripts/izleme.sh`, cron/systemd timer): hbbs/hbbr/API kapsayıcıları çalışıyor mu, TCP 21116/21117 ve HTTPS yanıt veriyor mu, SSL bitişine **<14 gün** mü, disk >%85 mi, aylık relay trafiği eşiği.
- Bildirim: **e-posta** (e-posta+kod girişiyle aynı SMTP) ve **WhatsApp**. WhatsApp için ücretsiz seçenek: CallMeBot kişisel API (yalnızca kendi numaranıza mesaj; kullanıcı kendi numarasından kayıt olup **API anahtarını sunucu `.env`'ine kendisi girer**). Resmî alternatif: WhatsApp Cloud API (Meta işletme hesabı, ücretli olabilir).
- Aynı alarm tekrarlanmaz (durum değişince bildir: düştü → düzeldi).

## 4. SmartScreen / kod imzalama — ücretsiz seçenekler (araştırma 04.10.2026)
| Seçenek | Ücret | Engel / not |
|---|---|---|
| **Microsoft Store (MSIX)** | Ücretsiz (bireysel geliştirici kaydı 2025'ten beri ücretsiz; Store MSIX'i Microsoft imzalar, SmartScreen uyarısı çıkmaz) | Uzaktan erişim uygulaması Store incelemesinden geçmeli; MSIX'te **hizmet ve sürücüler** (sanal ekran, yazıcı) sınırlı → tam M2YDesk zor. **Hızlı Destek** (taşınabilir, hizmetsiz) MSIX'e en uygun aday; kilit ekranı/yönetici pencereleri sınırlı kalır. İndirme Store üzerinden olur |
| **SignPath Foundation** | Ücretsiz (açık kaynak) | OSI lisansı (AGPL ✓), **kaynak herkese açık olmalı** (depo özel kalmak istendi ✗), sitede "Kod imzalama politikası" sayfası + roller; yayıncı adı **"SignPath Foundation"** görünür (M2Y değil) |
| Azure Artifact Signing | ~9,99 $/ay | Bireysel yalnız ABD/Kanada; kuruluş ABD/Kanada/AB/İngiltere (3 yıllık geçmiş) → **Türkiye'den uygun değil** |
| Microsoft'a dosya gönderimi (WDSI, "yanlış tespit") | Ücretsiz | Her sürüm dosyası için ayrı; itibar kalıcı değil, yalnızca geçici rahatlama |
| Kendinden imzalı sertifika | Ücretsiz | SmartScreen uyarısını **kaldırmaz** (yararsız) |
- **Öneri:** (a) Kısa vadede: her sürümde WDSI gönderimi + indirme sayfasında "Yine de çalıştır" görselli yönerge (zaten var). (b) Orta vadede: Hızlı Destek'i **Microsoft Store MSIX** olarak yayınla (ücretsiz, uyarısız). (c) Depo açılırsa SignPath. Ücretli tek kesin çözüm: OV/EV sertifika (yıllık ~200–400 $).

## 5. İmzalı güncelleme bilgisi
- `surum.json` (ve `engel.json`) **Ed25519 ile imzalanır**: `surum.json` + `surum.json.sig`. İstemci gömülü açık anahtarla doğrular; imza yoksa/bozuksa güncelleme ve engel listesi **reddedilir**.
- İmzalama **sunucuda değil**, kullanıcının bilgisayarında veya GitHub Actions'ta (Secret `M2Y_UPDATE_SIGNING_KEY`) yapılır → sunucu ele geçirilse bile sahte güncelleme imzalanamaz. Anahtar çiftini kullanıcı kendi bilgisayarında üretir; özel anahtar depoya/sohbete girmez, yedeği güvenli yerde.
- Anahtar dönüşümü için istemcide birden fazla açık anahtar desteklenir.

## 6. "Destek iste" düğmesi
- Hızlı Destek'te büyük "Destek iste" düğmesi (WhatsApp düğmesi **kalır**). Tıklanınca isteğe bağlı kısa açıklama → API'ye talep: kullanıcı (ad, e-posta), kuruluş, cihaz ID, zaman.
- Bildirim: süper admin + yetkili danışmanlara e-posta/WhatsApp ("**X kuruluşundan Ayşe destek bekliyor**") ve panelde/M2YDesk'te "Bekleyen talepler" listesi → **tek tıkla bağlan**.
- Danışan ekranında talep durumu: "Talebiniz iletildi — danışmanınız bağlanacak".
- Kuruluş bilgisi: kullanıcı profiline "Kuruluş adı" alanı (ilk girişte sorulur, isteğe bağlı).

## 7. Oturum kaydı ve aylık rapor
- Her bağlantıda API'ye kayıt: denetleyen (e-posta), danışan (ad, e-posta, kuruluş), cihaz ID, başlangıç/bitiş, **süre (dk)**, bağlantı türü; bitişte denetleyiciye **kısa not** penceresi (isteğe bağlı).
- Panel: danışan/kuruluş/ay filtreli liste; **aylık danışan bazlı rapor Excel (.xlsx) ve PDF** dışa aktarma (toplam oturum, toplam süre, notlar).
- Ekran içeriği kaydedilmez; KVKK aydınlatma metnine "bağlantı kayıtları ve notlar" eklenir, saklama süresi tanımlanır.

## 8. Ekranda görünür bağlantı çerçevesi
- Bağlantı süresince danışan ekranının kenarında belirgin renkli **çerçeve** ve üstte sabit şerit: "**Danışmanınız bağlı** — <danışman adı>" + "**Bağlantıyı kes**" düğmesi.
- "Bağlantıyı kes" → **"Bağlantıyı kesmek istediğinize emin misiniz?"** onayı (Vazgeç solda, "Evet, kes" sağda; yanlışlıkla kesmeyi önler).
- Çerçeve ekran paylaşımına/kayda dahil edilmez (yalnızca danışan görür) ❓ uygulanabilirlik Windows'ta doğrulanmalı (katmanlı pencere, `WDA_EXCLUDEFROMCAPTURE`).

## Bağımlılıklar
Hesap/API (Y2) + e-posta+kod girişi + SMTP → 2, 6, 7 bunlara bağlı. 5 ve 4 bağımsız. 3 SMTP ve WhatsApp anahtarına bağlı.
