# M2YDesk

[RustDesk](https://github.com/rustdesk/rustdesk) 1.4.9 tabanlı, kendi sunucusunda barındırılan uzaktan erişim ve teknik destek sistemi.

| Bileşen | Konum | Açıklama |
|---|---|---|
| **M2YDesk** istemcisi | depo kökü (`src/`, `flutter/`, `libs/`) | Tam özellikli, kurulabilir + taşınabilir istemci |
| **M2YDesk QS** | aynı kaynak, `incoming` yapılandırması | Yalnızca ID + şifre gösteren mini destek istemcisi |
| Sunucu (hbbs/hbbr) ve indirme sayfası | [`server/`](server/README.md) | Docker kurulumu, yedekleme, `rustdesk.mehmetmesut.com` sayfası |

Sürüm: **M2YDesk 1.0.0** (taban: RustDesk 1.4.9, `6c57829`, tek commit olarak içe aktarıldı). Üst kaynak README: [`docs/README.upstream.md`](docs/README.upstream.md).

Lisans: AGPL-3.0 (üst kaynakla aynı; dağıtılan istemcilerin kaynağı bu depodur).

## Derleme (GitHub Actions)

Yerel derleme gerekmez; `Actions → M2YDesk build → Run workflow` ile tetiklenir (`.github/workflows/m2y-build.yml`).

| Girdi | Varsayılan | Açıklama |
|---|---|---|
| `tag` | `m2y-test` | Ön sürüm (prerelease) etiketi; çıktılar bu release'e yüklenir |
| `build_windows` | açık | M2YDesk (taşınabilir + kurulum + MSI) ve M2YDesk QS |
| `build_android` / `build_linux` / `build_macos` | kapalı | İsteğe bağlı platformlar |

**Repository variables** (Settings → Secrets and variables → Actions → Variables):

| Değişken | Değer |
|---|---|
| `M2Y_SERVER_HOST` | `rustdesk.mehmetmesut.com` (varsayılan; boş bırakılabilir) |
| `M2Y_SERVER_KEY` | Sunucudaki `server/data/id_ed25519.pub` içeriği (**zorunlu**; yoksa istemciler `-k` anahtarlı sunucuya bağlanamaz) |

Varyantlar tek kaynaktan üretilir: `res/m2y/m2ydesk.json` (M2YDesk) ve `res/m2y/m2ydesk-qs.json` (QS, Cargo özelliği `m2y_qs`). Ayrıntı: [`res/m2y/README.md`](res/m2y/README.md), [`docs/gelistirme-plani.md`](docs/gelistirme-plani.md), [`docs/tasarim-dili.md`](docs/tasarim-dili.md).

> Depo özel (private) kaldığı sürece GitHub Actions dakikaları sınırlıdır (Windows 2×, macOS 10× sayılır). Herkese açık depoda sınırsızdır; AGPL-3.0 kaynak sunma yükümlülüğü de bunu gerektirir.

---

<p align="center"><a href="https://mehmetmesut.com">Yeşil Dönüşüm Mühendisi © Creator M2Y</a></p>
