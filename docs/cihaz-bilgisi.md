# Cihaz bilgisi raporlama (Görev 2)

| Öğe | Karar |
|---|---|
| Gönderilen | ID, UUID, **MAC**, bilgisayar adı, etkin oturum kullanıcısı, işletim sistemi, CPU/RAM, sürüm, çevrimiçi durum (heartbeat). IP adresini sunucu kendi görür |
| Hedef | `api-server = https://<M2Y_SERVER_HOST>` → `/api/heartbeat`, `/api/sysinfo` (**API sunucusu kurulana kadar 404**, istemci sessizce yeniden dener: dakikada ~4 istek) |
| Kod | `src/common.rs::get_sysinfo` (+`mac`), `src/hbbs_http/sync.rs::heartbeat_url` (kapı), `hbb_common::m2y::device_report_allowed` |
| Kapı | Gönderim yalnızca `m2y-report-device=Y` (derleme, JSON) **ve** `m2y-report-consent=Y` (kullanıcı onayı) ise. Onay yoksa `heartbeat_url()` boş döner → hiçbir istek atılmaz |
| Onay ekranı | Ana pencere açıldıktan 2 sn sonra (`desktop_home_page.dart::_m2yAskDeviceReportConsent`); Hızlı Destek dahil. **"Şimdi değil"** seçeneği vardır: reddedilirse bağlantı yine çalışır, bilgi gönderilmez; sonraki açılışta yeniden sorulur (reddetme kaydedilmez) |
| Plandan sapma | Plan "reddedilirse kapanır" diyordu. Hizmetin ön koşulu olarak rıza istemek KVKK'da "bağlı rıza" riskidir; bağlantı için cihaz bilgisi teknik olarak gerekmediğinden onay isteğe bağlı bırakıldı |
| Hesap | Hızlı Destek'te giriş/ayar arayüzü yok (`disable-account`, `disable-settings`); yalnızca raporlama |
| `register-device=N` | Kaldırıldı (API çağrılarını kapatıyordu). Yan etki: `--assign/--deploy` komutları açılır (root + token gerekir) |

## Uyarılar
- **API sunucusu hazır olmadan** bu sürüm dağıtılırsa kullanıcılar onay verir ama sunucuda görünen bir şey olmaz. Dağıtım sırası: API sunucusu → sürüm.
- KVKK: aydınlatma metni indirme sayfasında da bulunmalı (Görev 5). Saklama süresi ve silme talebi API tarafında tanımlanmalı.
- MAC adresi ilk uygun ağ arayüzünden alınır (`mac_address` crate); sanal adaptörlerde değişebilir → engelleme için tek başına güvenilmez.
