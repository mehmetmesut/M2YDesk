# RustDesk Kendi Sunucunuzda (Self-Hosted)

TeamViewer, AnyDesk ve Splashtop'a açık kaynaklı alternatif. Uzaktan erişim trafiği sizin sunucunuz üzerinden geçer.

- **Sunucu:** `rustdesk.mehmetmesut.com`
- **Sürüm:** RustDesk Server OSS (hbbs + hbbr), Docker

## Hızlı kurulum

1. **DNS:** Plesk > Web siteleri ve alan adları > `mehmetmesut.com` > DNS Ayarları bölümünde `rustdesk` için sunucu IP'sine bir **A kaydı** ekleyin.
   Bu kayıt Cloudflare kullanıyorsanız proxy **kapalı** (gri bulut) olmalıdır.
2. **Docker:** Plesk > Araçlar ve Ayarlar > Güncellemeler ve Yükseltmeler > **Docker** bileşenini kurun.
3. **Sunucuya kurulum (SSH):**
   ```bash
   sudo git clone https://github.com/mehmetmesut/RustDesk.git /opt/rustdesk
   cd /opt/rustdesk
   sudo bash scripts/kurulum.sh
   ```
4. Betiğin sonunda ekrana yazdırılan **Anahtar (Key)** değerini istemcilere girin.

> ⚠️ Projeyi `httpdocs` ya da başka bir web dizinine **kurmayın**. `data/id_ed25519` özel anahtarı internetten erişilebilir hale gelir.

## Danışanlar için indirme sayfası

`site/httpdocs/` klasörü, danışanların tek tıkla önceden yapılandırılmış istemciyi indirdiği sayfadır.
İstemci dosya adında sunucu ve açık anahtar taşır (`rustdesk-host=…,key=….exe`); danışan hiçbir ayar girmez.

1. Plesk'te `rustdesk.mehmetmesut.com` alt alan adını oluşturun, Let's Encrypt SSL alın.
2. `site/httpdocs/` içeriğini alt alan adının `httpdocs` klasörüne yükleyin (SFTP veya `cp`).
3. İstemcileri indirip yapılandırın (her sürüm güncellemesinde tekrar çalıştırın):
   ```bash
   cd /opt/rustdesk
   SITE_DIZINI=/var/www/vhosts/mehmetmesut.com/rustdesk.mehmetmesut.com \
   RUSTDESK_ISTEMCI_SURUM=1.4.9 sudo bash scripts/istemci-hazirla.sh
   ```
4. Danışan akışı: sayfaya girer → dosyayı indirip çalıştırır → ekrandaki **ID + şifreyi** size iletir → siz kendi RustDesk istemcinizden bağlanırsınız.

Alt alan adı hem web sayfasını (443) hem RustDesk portlarını (21115-21119) aynı IP'de taşır; Cloudflare proxy **kapalı** olmalıdır.

## Portlar

| Port | Protokol | Servis | Amaç |
|---|---|---|---|
| 21115 | TCP | hbbs | NAT tipi testi |
| 21116 | TCP + UDP | hbbs | ID kaydı, hole-punching |
| 21117 | TCP | hbbr | Relay |
| 21118 | TCP | hbbs | Web istemcisi (isteğe bağlı) |
| 21119 | TCP | hbbr | Web istemcisi (isteğe bağlı) |

## Yedekleme

Özel anahtar (`data/id_ed25519`) kaybolursa tüm istemcilerin yeniden yapılandırılması gerekir.

```bash
sudo bash scripts/yedekleme.sh                 # /opt/rustdesk/yedekler altına .tar.gz
sudo bash scripts/geri-yukleme.sh yedekler/rustdesk-yedek-XXXX.tar.gz
```

Otomatik gece yedeği için `sudo crontab -e`:

```
15 3 * * * /opt/rustdesk/scripts/yedekleme.sh >> /var/log/rustdesk-yedek.log 2>&1
```

Yedekler 30 gün saklanır (`SAKLAMA_GUNU` ile değiştirilebilir). Yedek klasörünü sunucu dışına da (Plesk Yedekleme Yöneticisi, S3 vb.) kopyalayın.

## Yönetim

```bash
cd /opt/rustdesk
docker compose ps                         # Durum
docker compose logs -f hbbs               # Loglar
docker compose pull && docker compose up -d   # Güncelleme
```

---

<p align="center"><a href="https://mehmetmesut.com">Yeşil Dönüşüm Mühendisi © Creator M2Y</a></p>
