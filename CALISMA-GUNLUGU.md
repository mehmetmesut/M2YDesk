# Çalışma Günlüğü — M2YDesk

## 08.10.2026 17:45 — "Failed to secure tcp: deadline has elapsed" bağlantı hatası (%50: düzeltme kodda, derleme/yayın bekliyor)
- Belirti: Oturum açık M2YDesk'ten herhangi bir cihaza bağlanırken 18 sn sonra "Bağlantı Hatası — Failed to secure tcp".
- Kök neden: İstemci, oturum jetonu doluyken hbbs'den şifreli el sıkışma (KeyExchange) bekliyor; açık kaynak hbbs bunu hiç göndermiyor. Sunucunun kendi içinden (127.0.0.1:21116) yapılan testte de 20 sn veri gelmedi → ağ (üniversite) kaynaklı değil.
- Düzeltme: `src/ui_session_interface.rs` io_loop'ta hbbs'ye giden jeton boş; API jetonu artık hbbs'ye taşınmıyor. Bağlantı yetkisi `m2y_auth` ile sürüyor.
- Kalan: Çekirdeğin yeniden derlenmesi (GitHub Actions kotası/bütçe), yayın, gerçek cihazda doğrulama.
