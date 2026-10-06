// M2YDesk: Android ana sayfası eklentileri — cihaz bilgisi paylaşım onayı (KVKK), üyelik kartı ve "Destek iste".
// Masaüstündeki akışla aynı seçenekleri kullanır (`m2y-report-device`, `m2y-report-consent`).
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_auth.dart';
import 'package:flutter_hbb/common/widgets/m2y_destek.dart';
import 'package:flutter_hbb/common/widgets/m2y_uyelik_karti.dart';
import 'package:flutter_hbb/models/platform_model.dart';

/// Cihaz bilgisi paylaşımı için açık rıza (KVKK). Oturum hazır olana kadar bekler; onay yoksa hiçbir
/// bilgi gönderilmez. Reddedilirse bağlantı yine çalışır (bağlı rıza değildir).
Future<void> m2yMobilCihazOnayiSor(bool Function() mounted) async {
  if (!mounted()) return;
  if (bind.mainGetOptionSync(key: 'm2y-report-device') != 'Y') return;
  if (bind.mainGetOptionSync(key: 'm2y-report-consent') == 'Y') return;
  if (M2yAuth.instance.stage.value != M2yAuthStage.ready) {
    Future.delayed(const Duration(seconds: 3), () => m2yMobilCihazOnayiSor(mounted));
    return;
  }
  await gFFI.dialogManager.show((setState, close, context) {
    accept() async {
      await bind.mainSetOption(key: 'm2y-report-consent', value: 'Y');
      close();
    }

    return CustomAlertDialog(
      title: Text(translate('m2y-consent-title')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(child: Text(translate('m2y-consent-text'))),
      ),
      actions: [
        dialogButton('m2y-consent-decline', onPressed: close, isOutline: true),
        dialogButton('m2y-consent-accept', onPressed: accept),
      ],
      onSubmit: accept,
      onCancel: close,
    );
  }, tag: 'm2y-consent');
}

/// Ekran paylaşımı sayfasının üstündeki M2YDesk bölümü: üyelik kartı ve "Destek iste".
class M2yMobilUstBolum extends StatelessWidget {
  const M2yMobilUstBolum({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 8),
          M2yDestekButton(),
          M2yUyelikKarti(),
        ],
      ),
    );
  }
}
