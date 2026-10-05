# Bağlantı göstergesi ve onaylı bağlantı kesme (danışan tarafı)

## Ne değişti
Dosya: `flutter/lib/desktop/pages/server_page.dart` (bağlantı yöneticisi / "cm" penceresi).
- Bağlantı yetkilendirilmiş ve sürüyorsa her bağlantı kartının en üstünde kırmızı sabit şerit: "Danışmanınız bağlı — <ad>" (ad boşsa ID) ve beyaz "Bağlantıyı kes" düğmesi.
- "Bağlantıyı kes" (şerit düğmesi ve mevcut "Disconnect" düğmesi, tek ortak işlev) önce onay sorar: başlık "Bağlantıyı kes", metin "Bağlantıyı kesmek istediğinize emin misiniz?". "Vazgeç" solda, "Evet, kes" sağda. Enter ve Esc = Vazgeç.
- Bağlantı isteği reddi ("Cancel", henüz kabul edilmemiş) onaysız kalır.
- Metinler Türkçe sabit (`translate()` anahtarı eklenmedi).

## Kapsam dışı
Ekran kenarı çerçevesi (Windows) eklendi: `src/platform/m2y_frame.rs` — katmanlı, tıklanmayan, her zaman üstte kırmızı kenar halkası (5 px, tüm sanal masaüstü), `WDA_EXCLUDEFROMCAPTURE` ile danışmanın görüntüsüne girmez. Bağlantı yöneticisindeki "Danışmanınız bağlı" şeridi görünürken Dart `bind.mainM2ySetFrame` ile açılır/kapanır (sayaçlı). Derlenmedi; Linux/macOS'ta işlem yok. Güvenli masaüstü (UAC) gösterilmez.

## Nasıl test edilir
1. İki cihazda uygulamayı çalıştır, danışan tarafında bağlantıyı kabul et.
2. Danışan tarafındaki bağlantı yöneticisinde kırmızı şeridi gör.
3. "Bağlantıyı kes" -> iletişim kutusu; Enter/Esc/"Vazgeç" bağlantıyı korur; "Evet, kes" bağlantıyı düşürür.
4. Alttaki "Disconnect" düğmesi de aynı onayı sormalı.
