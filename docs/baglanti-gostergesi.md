# Bağlantı göstergesi ve onaylı bağlantı kesme (danışan tarafı)

## Ne değişti
Dosya: `flutter/lib/desktop/pages/server_page.dart` (bağlantı yöneticisi / "cm" penceresi).
- Bağlantı yetkilendirilmiş ve sürüyorsa her bağlantı kartının en üstünde kırmızı sabit şerit: "Danışmanınız bağlı — <ad>" (ad boşsa ID) ve beyaz "Bağlantıyı kes" düğmesi.
- "Bağlantıyı kes" (şerit düğmesi ve mevcut "Disconnect" düğmesi, tek ortak işlev) önce onay sorar: başlık "Bağlantıyı kes", metin "Bağlantıyı kesmek istediğinize emin misiniz?". "Vazgeç" solda, "Evet, kes" sağda. Enter ve Esc = Vazgeç.
- Bağlantı isteği reddi ("Cancel", henüz kabul edilmemiş) onaysız kalır.
- Metinler Türkçe sabit (`translate()` anahtarı eklenmedi).

## Kapsam dışı
Ekran kenarı renkli çerçeve uygulanmadı: cm penceresi normal bir pencere; ekran kenarına çizen, tıklanmayan ve yakalamadan hariç tutulan katmanlı pencere yerel (src/platform, Windows `WDA_EXCLUDEFROMCAPTURE`) kod gerektirir. Yalnızca şerit vardır.

## Nasıl test edilir
1. İki cihazda uygulamayı çalıştır, danışan tarafında bağlantıyı kabul et.
2. Danışan tarafındaki bağlantı yöneticisinde kırmızı şeridi gör.
3. "Bağlantıyı kes" -> iletişim kutusu; Enter/Esc/"Vazgeç" bağlantıyı korur; "Evet, kes" bağlantıyı düşürür.
4. Alttaki "Disconnect" düğmesi de aynı onayı sormalı.
