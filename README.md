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

## Portlar

| Port | Protokol | Servis | Amaç |
|---|---|---|---|
| 21115 | TCP | hbbs | NAT tipi testi |
| 21116 | TCP + UDP | hbbs | ID kaydı, hole-punching |
| 21117 | TCP | hbbr | Relay |
| 21118 | TCP | hbbs | Web istemcisi (isteğe bağlı) |
| 21119 | TCP | hbbr | Web istemcisi (isteğe bağlı) |

## Yönetim

```bash
cd /opt/rustdesk
docker compose ps                         # Durum
docker compose logs -f hbbs               # Loglar
docker compose pull && docker compose up -d   # Güncelleme
```

---

<p align="center"><a href="https://mehmetmesut.com">Yeşil Dönüşüm Mühendisi © Creator M2Y</a></p>
