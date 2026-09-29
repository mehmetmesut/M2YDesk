# Android ve iOS (Görev 6)

## Android — `m2y-build.yml` `build-android` incelemesi
- Tek hedef: `aarch64` (arm64-v8a), çıktı `M2YDesk-<sürüm>-aarch64.apk`; `build_android` girişi açıkken çalışır (Ubuntu → Windows'a göre çok daha ucuz dakika).
- İmza: iş akışı `signingConfigs.release` → `debug` olarak değiştirir; ardından **`ANDROID_SIGNING_KEY` Secret'ı varsa** `r0adkll/sign-android-release` ile imzalar, yoksa debug imzalı APK'yı toplar (`Collect apk`).
- **Sorun:** Secret yoksa her derleme, CI koşucusunun rastgele debug anahtarıyla imzalanır. Kullanıcı yeni sürümü eskisinin üstüne kuramaz ("imza uyuşmuyor"), Play Protect uyarısı daha sert olur. **Kalıcı bir anahtar üretip Secret olarak eklemek gerekir.**

### Gerekli GitHub Secrets (Settings → Secrets and variables → Actions → *Secrets*)
| Secret | İçerik |
|---|---|
| `ANDROID_SIGNING_KEY` | Keystore dosyasının base64'ü |
| `ANDROID_ALIAS` | Anahtar takma adı (örn. `m2ydesk`) |
| `ANDROID_KEY_STORE_PASSWORD` | Keystore parolası |
| `ANDROID_KEY_PASSWORD` | Anahtar parolası |

Keystore'u **kendi bilgisayarınızda** üretin (parolaları sohbete/depoya yazmayın, yedeği güvenli yerde tutun — kaybederseniz güncelleme zinciri kopar):
```bash
keytool -genkeypair -v -keystore m2ydesk.jks -alias m2ydesk -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 m2ydesk.jks   # çıktıyı ANDROID_SIGNING_KEY Secret'ına yapıştırın
```

## Mobil sınırları (dürüst not)
- Cihaz bilgisi **onay ekranı yalnızca masaüstü ana sayfasındadır** (`desktop_home_page.dart`); Android'de onay sorulmadığı için `m2y-report-consent` hiç `Y` olmaz → Android'den cihaz raporu gönderilmez. İstenirse mobil ana sayfaya aynı onay eklenir (ayrı iş).
- Üye olmayan süre kuralı Rust katmanında (`io_loop`) olduğundan Android'de de geçerlidir (`m2y-nonmember-limit=Y` yapıldığında).
- Güncelleme: Android'de sessiz güncelleme yok; `surum.json` `android` girdisi yalnızca "Yeni sürüm" kartını gösterir (indirme sayfasına yönlendirir). Bilinmeyen kaynaktan kurulum izni gerekir.
- Android uygulama kimliği `com.m2y.m2ydesk`; Play Store'da yayın planlanmıyor (Google Play politikası uzaktan erişim uygulamalarında ek denetim uygular).

## iOS
- Kendi iOS istemcimiz **yok** (Apple imza/dağıtım maliyeti ve mağaza kuralları). Resmi **RustDesk** uygulaması App Store'dan kurulur, sunucu ayarı indirme sayfasındaki QR ile yapılır (`config={"host":…,"relay":"","api":"","key":…}`); sayfa bunu zaten gösteriyor.
- Sayfadaki iOS metni: "App Store'dan kur" düğmesi + QR ("Ayarlar → ID/Relay Sunucusu → QR tara"). Ek metin gerekmez; iOS'ta resmi uygulama **yalnızca kontrol eden** (uzaktan bağlanan) taraf olarak kullanılabilir, ekranı paylaşamaz — sayfaya kısa not önerilir (aşağıda).
- Bu sayfada iOS'ta üye/üye olmayan kuralları ve KVKK cihaz raporu **uygulanmaz** (resmi uygulama değişmez). Sunucu tarafı denetim (relay :21127) tek koruma olur.
