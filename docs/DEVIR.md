# Devir Notu (bulut oturumu → yerel oturum)

Bu dosya iki Claude oturumu arasındaki ortak hafızadır. **Yerel oturum ilk iş bunu okusun**, her önemli adımdan sonra "Durum" bölümünü güncelleyip commit/push etsin; bulut oturumu `git pull` ile okur.

## Proje
M2YDesk: RustDesk 1.4.9 tabanlı, kendi sunucuda barındırılan uzaktan destek sistemi. Sürüm **1.0.0**.
- Sunucu/alan adı: **desk.mehmetmesut.com** (Plesk, IP `217.195.207.159`, Plesk paneli `https://217.195.207.159:8443`)
- Depo: `mehmetmesut/RustDesk` (özel), dal `claude/tender-darwin-l1fq1r`
- Ürünler: **M2YDesk** (tam istemci), **M2YDesk QS** (yalnızca ID + şifre, danışanlar için)
- Kullanıcı tercihleri: Türkçe, kısa/net yanıt; Plesk (Linux) + FTP/SFTP; footer kredisi "Yeşil Dönüşüm Mühendisi © Creator M2Y" → https://mehmetmesut.com

## Durum (güncel)
| İş | Durum |
|---|---|
| Sunucu altyapısı (`server/`: docker-compose hbbs/hbbr) | ✅ **sunucuda çalışıyor** (`/opt/m2ydesk/server`, Docker, hbbs+hbbr `-k _`; eski systemd RustDesk servisleri ve birim dosyaları kaldırıldı). TCP 21115-21119 dışarıdan erişilebilir. Depo özel olduğundan `kurulum.sh` yerine eşdeğer komutlar elle uygulandı |
| İstemci kaynağı, markalama, gömülü yapılandırma (`res/m2y/*.json`), ikonlar | ✅ |
| GitHub Actions `m2y-build.yml` — Windows desk+qs, MSI | ✅ ilk derleme geçti (release `m2y-test`, eski adlı 1.4.9 dosyalarıyla) |
| Alt alan adı `desk.mehmetmesut.com` + DNS A kaydı | ✅ yayında |
| **Let's Encrypt SSL** | ✅ yalnızca ana alan adı, 28.12.2026'ya kadar, otomatik yenilenir |
| **İndirme sayfası yayında** | ✅ https://desk.mehmetmesut.com (docroot `/var/www/vhosts/mehmetmesut.com/desk.mehmetmesut.com`). `ayar.js` 1.0.0 adlarıyla; **`indir/` boş, 1.0.0 derlemesi bitince dosyalar konacak**. Mobilde taşma yok, `/indir/` 403. "QS" etiketi sayfada "Hızlı Destek" oldu |
| GitHub variable `M2Y_SERVER_KEY` | ✅ eklendi (açık anahtar) |
| 1.0.0 derlemesi (anahtar gömülü) | ⏳ Actions run #4 (`v1.0.0`) çalışıyor, ~65 dk |
| Android/Linux/macOS derlemeleri, Liquid Glass Flutter teması, kod imzalama | ⏳ sonraki tur |

## Yerel oturumda sırayla yapılacaklar
1. Chrome ile Plesk → `desk.mehmetmesut.com` → SSL/TLS → Let's Encrypt (yalnızca ana alan adı). Sonra `https://desk.mehmetmesut.com` sertifikasını doğrula.
2. SSH ile sunucuda:
   ```bash
   sudo git clone https://github.com/mehmetmesut/RustDesk.git -b claude/tender-darwin-l1fq1r /opt/m2ydesk
   cd /opt/m2ydesk/server && sudo bash scripts/kurulum.sh
   ```
   (Depo özel: GitHub kullanıcı adı + PAT gerekir.) Çıktıdaki **Anahtar** satırını not al.
3. Sağlayıcı/bulut güvenlik duvarında TCP 21115-21119 + UDP 21116 açık mı doğrula.
4. GitHub → Settings → Secrets and variables → Actions → Variables → `M2Y_SERVER_KEY` = anahtar.
5. Actions → "M2YDesk build" → Run workflow: `tag` = `v1.0.0`, `build_windows` açık.
6. Sunucuda `GITHUB_TOKEN=... sudo -E bash scripts/istemci-hazirla.sh` (SITE_DIZINI = Plesk'te desk alt alanının httpdocs yolu) → indirme sayfası dosyaları sunar.
7. Gerçek cihazda M2YDesk QS'i çalıştırıp ID+şifre ile bağlantı testi.

## Bilinen notlar
- Depo özel: Actions dakikaları sınırlı (Windows 2×, macOS 10×). Public yapmak önerildi (AGPL-3.0 zaten kaynak sunmayı gerektirir).
- Windows derlemesi ~65 dk; vcpkg adımı ~21 dk.
- İmzasız exe: SmartScreen uyarısı beklenir.
- Gizli bilgi (PAT, root şifresi, özel anahtar `id_ed25519`) ASLA depoya/sohbete yazılmaz.

## Sorunlar / açık işler (yerel oturum, 29.09.2026)
- **indir/ dosyaları**: depo özel olduğundan release dosyaları sunucuya otomatik inemiyor; Plesk yükleme aracı ~10 MB ile sınırlı (exe'ler ~23 MB). Çözüm: depoyu public yapmak ya da sunucuda `GITHUB_TOKEN` ortam değişkeniyle `istemci-hazirla.sh` çalıştırmak (PAT ayrıca istenecek).
- Eski `m2y-test` 1.4.9 dosyaları anahtarsız derlendi; bu sunucuya bağlanamaz, sayfaya konmadı.
- **Bulut oturumundan istenen iş**: "QS" = "Hızlı Destek". `index.html`'de etiketler yerelde değişti (push edildi); ürün/istemci arayüzündeki adlandırma da gözden geçirilmeli. `kurulum.sh` Docker'ı kendisi kurmuyor; Ubuntu 22.04'te `apt install docker.io docker-compose-v2` yeterli.

## Yeni plan (29.09.2026)
- Pro özelliklerinin kendi çözümümüzle karşılanması planı: [`yonetim-katmani-plani.md`](yonetim-katmani-plani.md). Sıra: Aşama 0 (1.0.0 derleme + dosyalar + ilk bağlantı testi) → 1 (hesap/API sunucusu) → 2/3 (güncelleme, üye/üye olmayan sınırları).
- **Bulut oturumundan istenen iş (Aşama 2/3 istemci kodu):** güncelleme denetimini `desk.mehmetmesut.com/guncelleme/surum.json`'a yönlendirme + sessiz güncelleme; girişsiz kullanıcı için relay `:21127`, 5 dk oturum kesme, 2 dk bekleme; girişli kullanıcı için sınırsız. Ayrıntı planda.
- Derleme #4 `Cargo.lock` uyuşmazlığıyla düştü (portable-packer 1.4.9→1.0.0), düzeltildi (`2b9dcd4`), run #5 çalışıyor.
