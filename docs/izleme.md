# Sunucu izleme ve alarm

`server/scripts/izleme.sh` her 5 dakikada bir sunucuyu denetler ve **yalnızca durum değişince**
(DÜŞTÜ / DÜZELDİ) e-posta ve ntfy push bildirimi gönderir. Aynı alarm tekrarlanmaz.

## Neler denetlenir

| Kontrol | Alarm koşulu |
|---|---|
| `kapsayici_hbbs`, `kapsayici_hbbr` | Docker kapsayıcısı çalışmıyor |
| `kapsayici_m2y-api` | Yalnızca kapsayıcı varsa; çalışmıyorsa |
| `tcp_21116`, `tcp_21117` (api varsa `tcp_21114`) | 127.0.0.1 üzerinde bağlantı kabul edilmiyor |
| `site` | https://desk.mehmetmesut.com/ HTTP 200 dönmüyor |
| `ssl` | Sertifikanın bitişine 14 günden az (sürdükçe günde en fazla bir hatırlatma) |
| `disk` | `/` bölümü %85 üstü |
| `veri_izin` | `/opt/m2ydesk/server/data` izni 700 değil |

Durum dosyası: `/var/lib/m2y-izleme/durum`. Günlük (sır içermez): `/var/log/m2y-izleme.log`.

## Kurulum (sunucuda, root)

```
sudo bash /opt/m2ydesk/server/scripts/izleme-kur.sh
```

Betik systemd service + timer yazar, `.env.izleme` yoksa gizli bir `NTFY_KONU` üretir ve konu adını
**yalnızca bir kez** ekrana yazar. E-posta için `.env.smtp` kullanılır (alıcı varsayılan
`mehmetmesut@gmail.com`; `.env.izleme` içine `IZLEME_EPOSTA=...` yazarak değiştirilebilir).
Örnek dosya: `server/.env.izleme.example`. Kaldırmak için: `sudo bash izleme-kur.sh kaldir`.

## Telefonda ntfy aboneliği

1. ntfy uygulamasını yükleyin (Android: Google Play veya F-Droid, iOS: App Store).
2. "+" ile konu ekleyin. Konu adı, kurulumda ekrana yazılan `m2y-...` değeridir
   (kaybolursa sunucuda `.env.izleme` dosyasındadır). Sunucu varsayılan olarak `https://ntfy.sh`.
3. Konu adı parola gibidir; paylaşmayın.

## Test etme

Servisleri durdurmadan sahte alarm gönderir (DÜŞTÜ + DÜZELDİ; gerçek durum dosyasına dokunmaz):

```
sudo IZLEME_TEST=1 bash /opt/m2ydesk/server/scripts/izleme.sh
```

Bildirim gelmezse `/var/log/m2y-izleme.log` dosyasına bakın.
