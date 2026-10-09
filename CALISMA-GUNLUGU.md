# Çalışma Günlüğü — M2YDesk

## 08.10.2026 17:45 — "Failed to secure tcp: deadline has elapsed" bağlantı hatası (%50: düzeltme kodda, derleme/yayın bekliyor)
- Belirti: Oturum açık M2YDesk'ten herhangi bir cihaza bağlanırken 18 sn sonra "Bağlantı Hatası — Failed to secure tcp".
- Kök neden: İstemci, oturum jetonu doluyken hbbs'den şifreli el sıkışma (KeyExchange) bekliyor; açık kaynak hbbs bunu hiç göndermiyor. Sunucunun kendi içinden (127.0.0.1:21116) yapılan testte de 20 sn veri gelmedi → ağ (üniversite) kaynaklı değil.
- Düzeltme: `src/ui_session_interface.rs` io_loop'ta hbbs'ye giden jeton boş; API jetonu artık hbbs'ye taşınmıyor. Bağlantı yetkisi `m2y_auth` ile sürüyor.
- Kalan: Çekirdeğin yeniden derlenmesi (GitHub Actions kotası/bütçe), yayın, gerçek cihazda doğrulama.

## 09.10.2026 — Yayın öncesi kod denetimi ve herkese açık depo (%70: düzeltmeler gönderildi, derleme sırada)
- Denetim: Rust/güvenlik (Opus ajanı) + Flutter (Sonnet ajanı); bulgular doğrulanıp düzeltildi (commit a778891 ve devamı).
- Düzeltilen: vekil/WS istemcide secure_tcp takılması, API ham TCP geri dönüşü, m2y_auth yalnız şifreli kanalda, belirteç süre üst sınırı, engel listesi zaman aşımı, taşınabilir/Hızlı Destek zorunlu güncelleme döngüsü, Ayarlar'dan giriş kapısı atlatma, Google girişinde KVKK rızası, Hızlı Destek kod adımı taşması, form kilitlenmesi, zorunlu güncellemede giden bağlantı, geçersiz belirteçte parola yoluna düşme (karar: Fable, kullanıcı yetkisiyle).
- Doğrulama: flutter analyze hata yok; 56/56 test geçti. Rust yerelde derlenemedi (cargo yok) — CI'da derlenecek.
- Herkese açık depo (AGPL gereği + sınırsız ücretsiz Actions): tüm geçmiş gizli bilgi için tarandı; tek bulgu yönetici parolası varsayılanı → `git filter-repo --replace-text` ile geçmişten silindi, zorla gönderildi (commit kimlikleri değişti).
- Kalan: depo görünürlüğü → derleme → yayın (asgari sürüm 1.0.5) → cihaz testi.

## 09.10.2026 10:55 — 1.0.5 Windows yayında (%85: Android/Linux/macOS derleniyor)
- Depo herkese açık yapıldı (kullanıcı); eski Actions kayıtları silindi.
- Derleme #18: 1. deneme GitHub önbellek kesintisi yüzünden düştü (kod hatası değil; windows qs başarılıydı), 2. deneme başarılı. Yalnız Windows işaretliydi (form varsayılanı) → release v1.0.5: exe, install, msi, QS exe, QS msix.
- Site: `istemci-hazirla.sh` (M2Y_SURUM=v1.0.5, asgari 1.0.4 — diğer platformlar henüz yok), özetler GitHub ile birebir (`ozet-karsilastir.sh` HEPSİ EŞLEŞİYOR), `surum.json` yerel anahtarla imzalandı ve yüklendi, `dogrula.sh` ✔.
- Derleme #19 başlatıldı: Android + Linux + macOS, aynı v1.0.5 etiketine eklenecek.
- Kalan: #19 bitince istemci-hazirla.sh yeniden (asgari 1.0.5) → imza → doğrulama → kullanıcı cihaz testi listesi.
