# API sunucusu değerlendirmesi: `lejianwen/rustdesk-api` (Görev 7)

Tarih: 29.09.2026. Kaynak: depo README'si (GitHub sayfası + `README_EN.md`) ve `model/peer.go` (ham dosya). Doğrulanamayan maddeler **❓** ile işaretlidir; GitHub API (release/tarih) bu ortamdan 403 döndüğü için etkinlik verisi eksiktir.

## Özet karar
**Aday olarak uygun, tek başına yeterli değil.** Cihaz envanteri, adres defteri, OIDC/Google, rol, günlük ve web istemci hazır; ancak **MAC alanı yok**, **2FA belgelenmemiş**, **cihaz/UUID/MAC engelleme yok** (yalnızca giriş IP'si yasağı). Bunlar için ya küçük bir yama (Go, MIT lisans → serbest) ya da yanında bizim yazacağımız ince bir servis gerekir.

## Bulgular
| Konu | Durum | Not |
|---|---|---|
| Lisans | ✅ MIT | AGPL istemciyle uyumlu; yama ve dağıtım serbest |
| Etkinlik | ⚠️ ❓ | ~409 commit, 3.1k yıldız, 750 fork (README). Son commit/sürüm tarihi doğrulanamadı → kurulumdan önce `github.com/lejianwen/rustdesk-api/releases` elle kontrol edin |
| Teknoloji | ✅ Go, SQLite (varsayılan) / MySQL, Docker + compose, Swagger | MySQL/MariaDB Plesk'te mevcut; SQLite tek sunucu için yeterli |
| Google / OIDC girişi | ✅ GitHub, Google, OIDC (OAuth2) | Süper admin = doğrulanmış `mehmetmesut@gmail.com` kuralı **❓ elle yapılandırma**: ilk kullanıcıyı admin yapma/e-posta eşleştirme kodu incelenmeli |
| E-posta+parola | ✅ (kapatılabilir) | LDAP/AD de var (bizde gerekmiyor) |
| 2FA (TOTP) | ❌ belgelenmemiş | README'de yok; `Discussions`/kodda arama gerekir **❓**. Alternatif: Google girişinde Google'ın kendi 2FA'sı |
| Cihaz envanteri | ✅ ID, cpu, hostname, memory, os, username, uuid, version, last_online_time, last_online_ip, alias, group_id, user_id | **MAC alanı YOK** (`model/peer.go`). İstemcimiz sysinfo'da `mac` gönderiyor (Görev 2); API bilinmeyen alanı yok sayar → **Peer modeline `Mac` alanı + sysinfo işleyicisi yaması gerekir** |
| Çevrimiçi durum / heartbeat | ✅ heartbeat, online tracking (`v2 magic query` seçeneği) | İstemci `/api/heartbeat`, `/api/sysinfo` çağırır (bkz. `cihaz-bilgisi.md`) ❓ sürüm uyumu: 1.4.9 istemciyle test edilmeli |
| Adres defteri / takma ad | ✅ paylaşımlı + kişisel, etiketler, otomatik senkron | İstemcide `disable-ab=Y` kaldırılmalı |
| Denetim günlüğü | ✅ giriş, bağlantı, dosya aktarım günlükleri | Bağlantı günlükleri istemci bildirimine bağlı ❓ |
| Roller | ✅ admin / normal kullanıcı | "Üye / üye olmayan" için: kayıtlı kullanıcı = üye |
| Engelleme | ⚠️ yalnızca giriş IP yasağı (`RUSTDESK_API_APP_BAN_THRESHOLD`) | ID/UUID/MAC/hesap engeli **yok**. Şimdilik bizim `engel.json` (Görev 3) kullanılır; ileride API'den üretilebilir |
| Canlı panel | ⚠️ ❓ | Çevrimiçi liste var; "şu an kaç oturum/kim kime bağlı" paneli için bağlantı günlüğü + hbbs verisi gerekir |
| Web yönetim paneli | ✅ `/_admin/` | Plesk'te ters vekil (nginx) arkasında `/api` ve `/_admin` |
| Web istemci | ✅ v1 + v2 önizleme dahil, otomatik yapılandırma, misafir geçici bağlantı | Aşağıya bakın |
| Güvenlik notu | ⚠️ | İlk admin parolası konsola yazılır → hemen değiştirin; `/api` yalnızca HTTPS; güvenilir vekil IP'si ayarlanmalı |

## Web istemci
- Bu API sunucusu web istemciyi (v1, v2 önizleme) kendi içinde sunuyor; RustDesk web istemcisi WebSocket portlarını kullanır: hbbs/hbbr **21118/21119** (HTTPS için ters vekil gerekir) — [RustDesk belgeleri](https://rustdesk.com/docs/en/self-host/client-configuration/).
- Lisans: web istemci kodunun lisansı **❓ doğrulanmadı** (RustDesk istemcisi AGPL-3.0; türevi ise AGPL yükümlülüğü taşır). Kullanmadan önce depodaki LICENSE dosyaları elle kontrol edilmeli.
- Web istemci kısıtı: tarayıcıdan gelen bağlantılar da üye/üye olmayan kurallarını **atlar** (Görev 3 yalnızca yerel istemcide).

## Önerilen entegrasyon (yerel oturum için)
1. Docker ile `lejianwen/rustdesk-api` (SQLite başlangıçta; MySQL sonra) `127.0.0.1:21114`; Plesk nginx: `desk.mehmetmesut.com/api/` ve `/_admin/` → 21114 (HTTPS). `ID server` = `desk.mehmetmesut.com`, `Relay` = aynı, anahtar `id_ed25519.pub` (açık anahtar).
2. Admin parolasını hemen değiştir; Google OIDC istemcisi oluştur (Google Cloud Console; yalnızca `mehmetmesut@gmail.com` yönetici).
3. İstemci 1.0.x ile `POST /api/sysinfo` + `/api/heartbeat` uçtan uca dene (Görev 2 onayı verilmiş cihazda) → envanterde cihaz görünmeli.
4. **Yama (bulut oturumu yazabilir):** `Peer.Mac` alanı + sysinfo/heartbeat işleyicisinde `mac` okuma + admin listesinde sütun. Fork'u `mehmetmesut` altında tut (özel).
5. `m2y-nonmember-limit=Y` ve `disable-account` kaldırma yalnızca 1–3 doğrulandıktan sonra.
6. hbbs/hbbr ile API arasında ek hbbs ayarı gerekmez (ayrı süreç); yalnızca istemci `api-server` ayarı.

## Karar bekleyen noktalar
- API kodunda MAC yaması yapılsın mı (fork bakımı gerektirir) yoksa MAC yalnızca istemci tarafında/bizim ince servisimizde mi tutulsun?
- 2FA: Google girişinin 2FA'sına güvenmek yeterli mi?

Kaynaklar: [lejianwen/rustdesk-api](https://github.com/lejianwen/rustdesk-api), [README_EN](https://github.com/lejianwen/rustdesk-api/blob/master/README_EN.md), [model/peer.go](https://github.com/lejianwen/rustdesk-api/blob/master/model/peer.go), [RustDesk client configuration](https://rustdesk.com/docs/en/self-host/client-configuration/).
