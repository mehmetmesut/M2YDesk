# Oturum kaydı (denetleyen taraf)

Bağlanan danışman istemcisi, oturumunu m2y-api'ye kaydeder (`docs/guvenlik-ve-destek-ozellikleri.md` §7,
API: `m2y-api/docs/m2y.md` "Aşama 2"). Yalnızca oturum açıksa (`access_token`) çalışır; admin ya da
`m2y_yetkili` olmayan hesapta sunucu `403` döner ve istemci sessizce vazgeçer.

## Akış

- **Başlangıç:** `src/client/io_loop.rs` içinde giriş yanıtındaki `PeerInfo` işlenince (`handle_peer_info`
  sonrası) `client::m2y_oturum_baslat` çağrılır. Oturum başına bir `oturum_uuid` (UUIDv4) üretilir,
  `POST /api/m2y/oturum {olay:"baslangic", oturum_uuid, hedef_id, tur}` arka planda (`tokio::spawn`) gönderilir.
- **Bitiş:** `io_loop` her çıkış yolunda (kullanıcı kapatır, karşı taraf keser, ağ hatası) `handle_disconnected`
  sonrasında `client::m2y_oturum_bitir` ile `olay:"bitis"` gönderir.
- `tur`: `uzak_masaustu`, `dosya`, `port`, `kamera` (`hbb_common::m2y::oturum_tur`). Terminal oturumu kaydedilmez.
  Port yönlendirme (`--port-forward`) `Remote` kullanmadığından şimdilik kaydedilmez.
- `hedef_id`: kimlikteki `@sunucu` ve `/r` atılır; `[A-Za-z0-9_-]{1,64}` dışı (ör. doğrudan IP) ise kayıt tutulmaz.
- Çağrı: doğrulanan TLS (Rustls, sonra NativeTLS), `Authorization: Bearer`, 5 sn zaman aşımı; hata yalnızca günlüğe
  (e-posta yazılmaz), kullanıcıyı engellemez, tekrar denenmez.

## Bitiş notu (Flutter)

- Rust, açık oturumları uuid anahtarıyla bellekte tutar; `session_m2y_info(session_id)` →
  `bind.sessionM2yInfo(sessionId:)` `{"uuid","tur","sure_sn"}` JSON'u döndürür (kayıt yoksa boş).
- `remote_tab_page.dart` sekme/pencere kapanış onayından sonra, oturum kapanmadan önce
  `m2yOturumNotuSor` (`flutter/lib/common/widgets/m2y_oturum_notu.dart`) çağırır. Yalnız `uzak_masaustu` ve
  süre >= 60 sn ise "Oturum notu (isteğe bağlı)" penceresi açılır (<= 1000 karakter; "Atla" solda, "Kaydet" sağda).
  Aynı oturum için en çok 1 kez sorulur.
- Kaydet: `POST /api/m2y/oturum/:uuid/not {not}` (en çok 5 sn beklenir; hata günlüğe). Boş not gönderilmez.

## Derleme notu

`session_m2y_info` için `flutter_rust_bridge` kodu yeniden üretilmelidir (`generated_bridge.dart` depoda yok).
