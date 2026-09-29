# M2YDesk Geliştirme Planı

Taban: RustDesk 1.4.9 (`6c57829`). Hedef: `desk.mehmetmesut.com` üzerinden çalışan, tek kaynaktan üretilen iki ürün.

| Ürün | İç ad (`APP_NAME`) | Görünen ad | Amaç |
|---|---|---|---|
| **A** | `M2YDesk` | M2YDesk | Danışmanın ve kurumların kullandığı tam istemci (kurulabilir + taşınabilir) |
| **B** | `M2YDeskQS` | M2YDesk Hızlı Destek | Danışanın çalıştırdığı, yalnızca ID + şifre gösteren, gelen bağlantı kabul eden mini istemci |

## 1. Keşif bulgularına dayalı kararlar

| Konu | Bulgu (kaynak) | Karar |
|---|---|---|
| Özel istemci yapılandırması | `custom.txt` RustDesk'in özel anahtarıyla imzalı olmalı (`src/common.rs:2186`); özel anahtar bizde yok | Yapılandırma **derlemeye gömülür**: `res/m2y/m2ydesk.json` / `m2ydesk-qs.json`, `load_custom_client()` imzasız uygular. Android dahil tüm platformları kapsar |
| Varyant seçimi | `conn-type=incoming` yalnızca `HARD_SETTINGS`'ten okunur; Windows'ta `-qs` dosya adı UAC yardımcısını başlatır (`core_main.rs:139`) | Cargo özelliği `m2y_qs` (build.py `--m2y-qs`) + Windows QS dosya adı `-qs-` içerir |
| Sunucu/anahtar | `RENDEZVOUS_SERVERS` sabiti en düşük öncelikli yedek; asıl kaldıraç `override-settings` | `custom-rendezvous-server`, `relay-server`, `key` override; `register-device=N` ile API çağrıları kapanır. Host/anahtar CI değişkeni (`M2Y_SERVER_HOST`, `M2Y_SERVER_KEY`) |
| Otomatik güncelleme | Kurulu Windows servisinde `allow-auto-update` `is_custom_client`'a bakmaz; RustDesk sürümünü indirebilir | `allow-auto-update=N`, `enable-check-update=N` override |
| Marka adı | `APP_NAME` tek kaynak; servis adı tırnaksız `sc create` → boşluk olamaz | İç ad boşluksuz; görünen ad yalnızca Runner.rc / manifest / .desktop |
| İkili adı | Yarım yeniden adlandırma (yalnızca APP_NAME) taşınabilir modda süreç aramalarını bozar | Tutarlı: Windows `M2YDesk.exe` / `M2YDeskQS.exe`, Linux `m2ydesk` (CMake `M2Y_BINARY_NAME`) |
| Yan yana çalışma | Taşınabilir açılım klasörü, RuntimeBroker adı, staging klasörü "rustdesk" sabitti | Varyanta özel yapıldı (`libs/portable`, `win_topmost_window.rs`, `windows.rs`) |
| QS arayüzü | incoming-only sağ paneli kaldırır; ID kartındaki ⋮ menüsü koşulsuzdu | ⋮ menüsü incoming-only'de gizlendi; pencere 280 px, otomatik yükseklik |
| Şifre modeli | Geçici şifre her yetkili oturumdan sonra yenilenir (`connection.rs:1136`) | QS: `use-temporary-password`, 6 hane. Sabit şifre yok (danışan kontrolü) |
| Adres defteri / hesap | Yalnızca Pro API ile çalışır | A'da `disable-ab`, `disable-account`. Yerel adres defteri: 2. faz |
| Depo | Özel depo: macOS 10×, Windows 2× dakika çarpanı | Depo **herkese açık** yapılmalı (AGPL-3.0 kaynak sunma yükümlülüğü de bunu gerektirir) |

## 2. Dosya adlandırma

| Çıktı | Dosya adı |
|---|---|
| Windows A taşınabilir | `M2YDesk-<sürüm>-x86_64.exe` |
| Windows A kurulum | `M2YDesk-<sürüm>-x86_64-install.exe` (ad `install.exe` ile bitmeli) |
| Windows A MSI | `M2YDesk-<sürüm>-x86_64.msi` |
| Windows B (QS) | `M2YDesk-QS-<sürüm>-x86_64.exe` (`-qs-` kuralı) |
| Android A | `M2YDesk-<sürüm>-aarch64.apk` |
| Linux A | `m2ydesk-<sürüm>-x86_64.deb` |
| macOS A | `M2YDesk-<sürüm>-aarch64.dmg` (2. tur) |

## 3. Aşamalar

| # | Aşama | Durum |
|---|---|---|
| 1 | Sunucu altyapısı + indirme sayfası (`server/`) | ✅ |
| 2 | Kaynak keşfi (29 ajan, doğrulamalı) | ✅ |
| 3 | Çekirdek: gömülü yapılandırma, `m2y_qs`, varyant sabitleri, CMake ikili adı, QS menü gizleme | ✅ (bu commit) |
| 4 | Markalama: Windows Runner.rc, Android, macOS, Linux paket adları, ikonlar | ⏳ |
| 5 | CI: `m2y-build.yml` (Windows A+QS, Android, Linux) + sürüm yayını | ⏳ |
| 6 | Tasarım: Liquid Glass tema (Flutter) — ilk yeşil derlemeden sonra | ⏳ |
| 7 | İndirme sayfasını GitHub Release'lerden besleme | ⏳ |
| 8 | Uçtan uca test (sunucu + gerçek cihazlar) | ⏳ sizin tarafınız |

## 4. AnyDesk 9.7.16 ile dürüst karşılaştırma

**RustDesk tabanında hazır:** dosya aktarımı, pano (metin + dosya), ses/mikrofon, çoklu monitör, oturum kaydı (video), sohbet, TCP tünel, RDP, gizlilik modu, 2FA, uzaktan yazdırma, salt-görüntüleme, kamera, terminal, gözetimsiz erişim, çoklu oturum sekmeleri, VP8/VP9/AV1/H264/H265 + donanım hızlandırma, CAD/kilit, çözünürlük, bağlantı geçmişi, IP beyaz listesi, yeniden başlatma, LAN WoL.

**OSS'te olmayan ve M2YDesk 1.0'da olmayacak:** bulut adres defteri ve hesaplar, cihaz grupları, denetim kaydı, toplantı (AnyDesk One Meeting), kalıcı sohbet/topluluk, RMM/süreç görüntüleyici, ID tabanlı ACL, internet üzerinden WoL, gerçek beyaz tahta (yalnızca imleç paylaşımı), kayıtta ses izi, DeskRT codec performansı.

**Kolay kazanımlar (2. faz):** yerel adres defteri (orta), uzaktan kapatma (kolay), ID tabanlı ACL (kolay-orta), davet düğmesi (kolay).

## 5. Riskler
- **Kod imzası yok:** SmartScreen "bilinmeyen yayıncı" uyarısı; QS exe kendini `%LOCALAPPDATA%`'ya açıp UAC istediği için AV heuristikleri tetiklenebilir. Çözüm: OV/EV kod imzalama sertifikası (2. faz).
- **macOS:** notarization olmadan sağ tık → Aç gerekir.
- **UDP delme** kendi sunucuda varsayılan kapalı; sunucu testinden sonra `enable-udp-punch=Y` varsayılanı değerlendirilecek.
- **Yazıcı / sanal ekran sürücüleri** imzalıdır; yeniden adlandırılmaz.
