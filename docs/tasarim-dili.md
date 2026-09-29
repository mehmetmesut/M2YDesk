# M2YDesk Tasarım Dili

**İlke:** TeamViewer'ın minimalist modernliği + Apple Liquid Glass. Sıkıştırılmış, zarif, **yazıların kaymadığı** düzen. Aynı token'lar web sayfası (`server/site/httpdocs/index.html`) ve Flutter istemcisi (`flutter/lib/common.dart` → `MyTheme`) için geçerlidir.

## Token'lar

| Token | Açık tema | Koyu tema | Flutter karşılığı |
|---|---|---|---|
| Arka plan | `#EEF3F9` → `#F7F9FC` degrade | `#0B1220` → `#0F172A` | `scaffoldBackgroundColor` |
| Metin | `#0F172A` | `#F1F5F9` | `textTheme` |
| İkincil metin | `#5B6B82` | `#A0AEC0` | `MyTheme.darkGray` yerine |
| Vurgu (birincil) | `#0E7CFF` | `#3B9DFF` | `MyTheme.accent`, `MyTheme.button` |
| Vurgu (basılı) | `#0862D1` | `#1D7FE6` | `accent80` |
| Cam yüzey | `rgba(255,255,255,.58)` | `rgba(30,41,59,.55)` | `Card`/`Container` + `BackdropFilter(blur 26)` |
| Cam çerçeve | `rgba(255,255,255,.75)` | `rgba(255,255,255,.12)` | `Border.all(width: 1)` |
| Gölge | `0 10px 40px rgba(15,23,42,.10)` | `0 10px 40px rgba(0,0,0,.45)` | `BoxShadow(blurRadius: 40, offset: (0,10))` |
| Işık lekeleri | `#9FC6FF` `#B8F0E4` `#E2D4FF` | `#1E4FA3` `#0F6B5C` `#4B2F9E` | Arka planda 3 bulanık daire (`ImageFilter.blur(70)`) |

## Biçim

- **Yuvarlatma:** panel 22 px, hap/düğme 999 px (tam yuvarlak), giriş alanı 14 px, küçük rozet 10 px. RustDesk'teki 8 px yerine.
- **Boşluk:** 4 tabanlı; panel içi 16–18 px, paneller arası 12 px. Fazla boşluk yok, sıkıştırılmış.
- **Yazı:** sistem fontu (SF Pro / Segoe UI / Inter). Başlık 700, `letter-spacing: -0.02em`; gövde 400; etiket 600 / 0.93 rem.
- **Yükselti:** hover'da 2 px yukarı + gölge artışı, 180 ms `ease`. `prefers-reduced-motion` → animasyon yok.

## Kaymayan metin kuralları (zorunlu)

1. Etiket, düğme ve hap metinleri **tek satır**: `white-space: nowrap` / Flutter `maxLines: 1, overflow: TextOverflow.ellipsis`, `softWrap: false`.
2. Genişlik bilinmeyen yerde metin değil, kap küçülür: `min-width: 0` / `Flexible` + `FittedBox(fit: scaleDown)`.
3. Sabit genişlikli ID/şifre alanları: monospace, sabit karakter genişliği (`FontFeature.tabularFigures()`), kopyala düğmesi sağda sabit.
4. Uzun cümleler yalnızca açıklama paragraflarında; `text-wrap: pretty` / Flutter `TextAlign.start`.
5. Türkçe karakter ve uzun çeviriler için her metin 360 px genişlikte test edilir (web: Playwright; Flutter: 360 px pencere).

## M2YDesk Hızlı Destek (mini istemci) penceresi

- Boyut: **360 × 440** sabit, yeniden boyutlandırılamaz, her zaman ortada açılır.
- İçerik: logo + "Bağlantıya hazır" durumu · **ID** (büyük, 9 haneli, boşluklu: `123 456 789`) · **Şifre** (görünür, kopyala) · bağlantı durumu satırı · altta ince metin: "Bu bilgileri yalnızca danışmanınızla paylaşın".
- Gizli: sekmeler, adres defteri, ayarlar dişlisi, "bağlan" alanı, hesap, güncelleme uyarısı.
- Tepsi simgesi ve "kapatınca tepsiye küçült" **açık**; kapatma tuşu uygulamayı sonlandırır (danışan kontrolü).

## M2YDesk (tam istemci) penceresi

- RustDesk düzeni korunur (sol: kendi ID/şifre; sağ: bağlan + son bağlantılar), ancak paneller cam yüzey, hap düğmeler, 22 px yuvarlatma.
- Sekme çubuğu daha ince (36 px), aktif sekme cam vurgulu.
- Ayar sayfaları: kategori listesi solda sabit 200 px, içerik sağda; başlıklar tek satır.
