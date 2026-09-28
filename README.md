# M2YDesk

[RustDesk](https://github.com/rustdesk/rustdesk) 1.4.9 tabanlı, kendi sunucusunda barındırılan uzaktan erişim ve teknik destek sistemi.

| Bileşen | Konum | Açıklama |
|---|---|---|
| **M2YDesk** istemcisi | depo kökü (`src/`, `flutter/`, `libs/`) | Tam özellikli, kurulabilir + taşınabilir istemci |
| **M2YDesk QS** | aynı kaynak, `incoming` yapılandırması | Yalnızca ID + şifre gösteren mini destek istemcisi |
| Sunucu (hbbs/hbbr) ve indirme sayfası | [`server/`](server/README.md) | Docker kurulumu, yedekleme, `rustdesk.mehmetmesut.com` sayfası |

Kaynak: RustDesk 1.4.9 (`6c57829`), tek commit olarak içe aktarıldı. Üst kaynak README: [`docs/README.upstream.md`](docs/README.upstream.md).

Lisans: AGPL-3.0 (üst kaynakla aynı; dağıtılan istemcilerin kaynağı bu depodur).

---

<p align="center"><a href="https://mehmetmesut.com">Yeşil Dönüşüm Mühendisi © Creator M2Y</a></p>
