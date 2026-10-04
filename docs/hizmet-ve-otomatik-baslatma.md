# Hizmet sorunu ve Hızlı Destek otomatik başlatma (04.10.2026)

**Durum:** Kod yazıldı, derlenmedi (yerelde Rust yok). Dart: `dart analyze` yeni satırlarda hata yok. Doğrulama 1.0.2 "gerçek doğrulama derlemesi"nde.

## A. "Servis çalışmıyor" (tam M2YDesk, kurulu Windows)

### Olay günlüğündeki 7009/7000'in kaynağı (bulgu)
`7045 → 7009 (30000 ms) → 7000 → 7045` deseni **hatanın kendisi değil, kurulum betiğinin bilinen bir yan etkisi**dir:
`get_import_config()` (`src/platform/windows.rs`) yapılandırmayı SYSTEM olarak içe aktarmak için geçici bir hizmet oluşturur
(`sc create <ad> ... --import-config`) ve `sc start` ile çalıştırır. `--import-config` işi yapıp çıkar, hizmet dağıtıcısına
(`StartServiceCtrlDispatcher`) **hiç bağlanmaz** → SCM 30 sn bekler (7009) → "başlatılamadı" (7000). Ardından geçici hizmet silinir ve
asıl hizmet oluşturulur (ikinci 7045) ve çalışır. "Servisi başlat"a basmak da `install_service()`'i (aynı betik) çalıştırdığı için aynı desen tekrarlanır.
Asıl `--service` yolu dağıtıcıya hemen bağlanıyor (`core_main` → `start_os_service`, öncesinde ağır iş yok).

### Açılışta başlamama — kök neden bulunamadı (varsayımlar)
- Hizmet `start= auto` idi; açılışta erken başlatma + imzasız büyük DLL'in (`librustdesk.dll`) Defender taramasıyla 30 sn aşımı olası (❓ doğrulanmadı; bu durumda olay günlüğünde açılışta 7009/7000 görünmeliydi).
- "O arada hizmet günlüğü yok" → hizmet o sırada hiç yoktu/silinmişti de olabilir (❓).
- Arayüzdeki "Servis çalışmıyor" yazısı aslında **`stop-service` = "Y"** seçeneğine bağlıdır (gerçek hizmet durumuna değil). Hizmet kapalıyken `stop-service` boşsa arayüz uyarı göstermeden **kendi süreç içi sunucusunu** açar.

### Değişenler
1. `src/platform/windows.rs`
   - `m2y_service_tuning_cmds()`: hizmet oluşturulduktan sonra
     `sc config <ad> start= delayed-auto`, `sc failure <ad> reset= 86400 actions= restart/5000/restart/10000/restart/30000` ve
     `sc sdset` (varsayılan tanımlayıcı + etkileşimli kullanıcıya yalnızca **başlatma** (RP) izni; durdurma/silme yok).
     Hem kurulumda (`get_create_service`, MSI dahil) hem güncellemede (`update_me`) uygulanır. Hizmet adı `crate::get_app_name()`.
   - `m2y_try_start_service_on_launch()`: kurulu exe, hizmet kapalı ve `stop-service` != "Y" ise SCM `StartService` ile **bir kez**, UAC'siz başlatır;
     başarılıysa sunucu IPC'si hazır olana dek ≤15 sn bekler. Başarısızsa bayrak tutulur. Tekrar deneme yok.
2. `src/core_main.rs`: ana pencere açılışında, arayüz kendi sunucusunu açmadan **önce** (arka plan iş parçacığında) yukarıdaki deneme
   → hizmetin `--server`'ı ile IPC çakışması (ana pencerenin kapanması) önlenir.
3. `src/flutter_ffi.rs`: `mainGetCommon(key: 'm2y-service-autostart-failed')` → "true"/"false".
4. `flutter/lib/desktop/pages/connection_page.dart`: deneme başarısızsa "Servis çalışmıyor" + "Servisi başlat" bağlantısı görünür
   (bağlantı eskisi gibi `install_service()` → UAC ile yeniden kurar; yeni kurulumda yeni ayarlar gelir).
   `stop-service` = "Y" iken mevcut davranış aynı.

Not: Görevde istenen "mevcut bind fonksiyonuyla sessiz başlatma" kullanılmadı: o yol (`mainSetBoolOption(stop-service)` → `install_service`) UAC ister ve süreci `exit(0)` ile kapatır, sessiz olamaz.

### Test
1. Temiz kurulum (exe ve MSI): `sc qc M2YDesk` → `START_TYPE: 2 AUTO_START (DELAYED)`; `sc qfailure M2YDesk` → 3 restart; `sc sdshow M2YDesk` → IU girdisinde `RP`.
2. Yeniden başlat → ~2 dk sonra `sc query M2YDesk` RUNNING.
3. Yönetici olarak `sc stop M2YDesk` (stop-service boş kalır) → M2YDesk'i normal kullanıcıyla aç → UAC çıkmadan hizmet RUNNING olur, uyarı görünmez.
4. Eski (1.0.0) kurulumda hizmet kapalıyken aç → deneme reddedilir (eski DACL) → "Servisi başlat" görünür → tıklayınca UAC ile yeniden kurulur.
5. Ayarlar'dan hizmeti durdur (`stop-service` = Y) → açılışta başlatma denenmez.
6. Hizmeti `taskkill /F` ile öldür → 5 sn sonra SCM yeniden başlatır.

### Doğrulanmamış varsayımlar / riskler
- `windows-service` 0.6 `ServiceManager`/`ServiceAccess::START` API'si yerelde derlenmeden yazıldı (derleme kırılma riski düşük ama var).
- Gecikmeli başlangıçta kullanıcı açılıştan sonraki ~2 dk içinde M2YDesk'i açarsa uygulama hizmeti kendisi başlatır (yukarıdaki deneme); yine de hizmet daha sonra SCM tarafından başlatılırsa sorun yok (zaten çalışıyor).
- Hizmet başlatma 30 sn askıda kalırsa arayüzün sunucusu o kadar gecikir (en kötü ~45 sn "bağlanıyor").
- Kurulum sonunda hizmetin çalıştığının ayrıca doğrulanması (DEVIR madde 3) bu turda yapılmadı.

## B. Hızlı Destek'in Windows açılışında başlaması

- `m2y_sync_autostart()` (`src/platform/windows.rs`, yalnızca `m2y_qs` özelliği + `incoming-only`), her ana pencere açılışında `core_main`'den çağrılır.
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → değer adı uygulama adı (`M2YDeskQS`), değer `"<mevcut exe yolu>"`. Değer farklıysa güncellenir (exe taşındıysa düzelir). Yönetici izni gerekmez.
- Seçenek: `LocalConfig` `m2y-autostart`; varsayılan (boş) = açık; `"N"` → Run değeri silinir. Bu turda arayüz yok (Hızlı Destek'te ayarlar kapalı); "Sürekli erişim" akışı yazıldığında bu seçeneğe bağlanacak.
- Argüman: depoda Hızlı Destek'i gizli/tepside başlatan bir argüman yok (`--tray` yalnızca tepsi simgesini açar, sunucu başlatmaz) → **normal başlatılır** (pencere açılır).
- **Sınır:** Run kaydı yalnızca kullanıcı oturum açtığında çalışır; kilit/giriş ekranında (oturum açılmadan) erişim için hizmet gerekir → tam M2YDesk kurulumu.

### Test
1. Hızlı Destek'i aç → `reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Run /v M2YDeskQS` → exe yolu.
2. Exe'yi başka klasöre taşı, oradan aç → değer yeni yola güncellenir.
3. Oturumu kapat/aç → Hızlı Destek kendiliğinden açılır, ID görünür.
4. `%APPDATA%\M2YDeskQS\config\M2YDeskQS_local.toml` içine `[options]` altında `m2y-autostart = 'N'` → aç → Run değeri silinir.

### Doğrulanmamış varsayımlar
- Taşınabilir Hızlı Destek açılışta `start_portable_service` ile yükseltme isteyebilir (mevcut davranış); oturum açılışında UAC penceresi çıkabilir (❓).
- Pencere açık başlar; kapatınca uygulama kapanır (tepsiye inme bu turda yok).
