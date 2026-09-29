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
| Sunucu altyapısı (`server/`: docker-compose hbbs/hbbr, kurulum/yedekleme betikleri, indirme sayfası) | ✅ hazır, **sunucuya kurulmadı** |
| İstemci kaynağı, markalama, gömülü yapılandırma (`res/m2y/*.json`), ikonlar | ✅ |
| GitHub Actions `m2y-build.yml` — Windows desk+qs, MSI | ✅ ilk derleme geçti (release `m2y-test`, eski adlı 1.4.9 dosyalarıyla) |
| Alt alan adı `desk.mehmetmesut.com` + DNS A kaydı | ✅ yayında |
| **Let's Encrypt SSL** | ⏳ Plesk formunda yalnızca ana alan adı işaretli olmalı (www ve joker KAPALI); www/joker TXT/NXDOMAIN hatası verdi |
| **Sunucuda hbbs/hbbr kurulumu** | ⏳ bekliyor |
| GitHub variable `M2Y_SERVER_KEY` | ⏳ sunucu kurulunca `server/data/id_ed25519.pub` içeriği |
| 1.0.0 derlemesi (anahtar gömülü) | ⏳ anahtardan sonra |
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
