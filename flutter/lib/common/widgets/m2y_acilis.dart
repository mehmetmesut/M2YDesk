// M2YDesk Hızlı Destek: "Bilgisayar açılınca arka planda çalıştır" anahtarı (aç/kapat).
// Windows oturum açılışında başlatma, HKCU\...\Run kaydıyla yapılır (yönetici izni gerekmez). Kayıt
// değeri `--m2y-arkaplan` bağımsız değişkenini taşır; bu bağımsız değişkenle açılan uygulama, oturum
// hazır olunca pencereyi görev çubuğuna küçültür (arka planda çalışır). Çekirdek (Rust) de açılışta aynı
// değeri yazar (`m2y_sync_autostart`); `m2y-autostart` = "N" ise kaydı siler.
// M2YDesk: Türkçe sabit metin (çeviri anahtarı kullanılmaz).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_auth.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// Uygulamanın açılışta arka planda başlatıldığını belirten bağımsız değişken.
const kM2yArkaPlanArg = '--m2y-arkaplan';

const _kRunAnahtari = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';

/// Açılışta başlatma kaydını yazar/siler. Testte sahtesi takılabilir.
@visibleForTesting
Future<bool> Function(bool ac) m2yAcilisKaydedici = _kayitYaz;

Future<bool> _kayitYaz(bool ac) async {
  if (!Platform.isWindows) return false;
  final ad = bind.mainGetAppNameSync().replaceAll("'", "''");
  final exe = Platform.resolvedExecutable.replaceAll("'", "''");
  final komut = ac
      ? "Set-ItemProperty -Path '$_kRunAnahtari' -Name '$ad' -Value '\"$exe\" $kM2yArkaPlanArg'"
      : "Remove-ItemProperty -Path '$_kRunAnahtari' -Name '$ad' -ErrorAction SilentlyContinue";
  try {
    final r = await Process.run(
        'powershell', ['-NoProfile', '-NonInteractive', '-Command', komut]);
    return r.exitCode == 0;
  } catch (e) {
    debugPrint('M2YDesk: açılış kaydı güncellenemedi: $e');
    return false;
  }
}

class M2yAcilisAnahtari extends StatefulWidget {
  const M2yAcilisAnahtari({Key? key}) : super(key: key);

  @override
  State<M2yAcilisAnahtari> createState() => _M2yAcilisAnahtariState();
}

class _M2yAcilisAnahtariState extends State<M2yAcilisAnahtari> {
  bool _acik = bind.mainGetLocalOption(key: kM2yOptAutostart) != 'N';
  bool _mesgul = false;

  Future<void> _degistir(bool ac) async {
    if (_mesgul) return;
    setState(() {
      _acik = ac;
      _mesgul = true;
    });
    await bind.mainSetLocalOption(key: kM2yOptAutostart, value: ac ? '' : 'N');
    final ok = await m2yAcilisKaydedici(ac);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (!ok) showToast('Açılış ayarı kaydedilemedi');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: 'Bilgisayar her açıldığında Hızlı Destek arka planda kendiliğinden çalışsın',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: _mesgul ? null : () => _degistir(!_acik),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Küçültülmüş anahtar: FittedBox yerleşimdeki boyutu da küçültür (Transform küçültmez).
            SizedBox(
              width: 38,
              height: 24,
              child: FittedBox(
                child: Switch(
                  value: _acik,
                  onChanged: _mesgul ? null : _degistir,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                'Açılışta başlat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
