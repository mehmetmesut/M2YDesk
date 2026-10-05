// M2YDesk: uzak oturum bitişinde isteğe bağlı oturum notu
// (POST /api/m2y/oturum/:uuid/not). M2YDesk: Türkçe sabit metin.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_destek.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const kM2yOturumNotMax = 1000;
// Bu süreden kısa oturumlarda not sorulmaz (sn).
const kM2yOturumNotMinSure = 60;
const _kNotTimeout = Duration(seconds: 5);

// Aynı oturum için pencere en çok 1 kez sorulur.
final _asked = <String>{};

/// Uygulama kuralı: yalnız uzak masaüstü türü ve en az 1 dk süren oturum.
bool m2yOturumNotuGerekli(String tur, int sureSn) =>
    tur == 'uzak_masaustu' && sureSn >= kM2yOturumNotMinSure;

/// Pencere kapanış onayından SONRA, oturum kapanmadan önce çağrılır
/// (oturum bilgisi Rust'ta kapanışla birlikte silinir). Hata/ağ yokluğu
/// kullanıcıyı engellemez; "Atla" ya da "Kaydet" ile biter.
Future<void> m2yOturumNotuSor(FFI ffi) async {
  try {
    final raw = bind.sessionM2yInfo(sessionId: ffi.sessionId);
    if (raw.isEmpty) return;
    final info = jsonDecode(raw);
    if (info is! Map) return;
    final uuid = (info['uuid'] ?? '').toString();
    final tur = (info['tur'] ?? '').toString();
    final sure = info['sure_sn'] is num ? (info['sure_sn'] as num).toInt() : 0;
    if (uuid.isEmpty || !m2yOturumNotuGerekli(tur, sure)) return;
    if (!_asked.add(uuid)) return;
    await _showNotDialog(ffi, uuid);
  } catch (e) {
    debugPrint('M2YDesk: oturum notu penceresi açılamadı: $e');
  }
}

Future<void> _showNotDialog(FFI ffi, String uuid) async {
  final controller = TextEditingController();
  var busy = false;
  await ffi.dialogManager.show<void>((setState, close, context) {
    Future<void> kaydet() async {
      final text = controller.text.trim();
      if (text.isEmpty || busy) {
        close();
        return;
      }
      setState(() => busy = true);
      try {
        // Yetkisiz hesapta (403) ya da ağ yokken sessizce vazgeçilir.
        await M2yApi.post('/api/m2y/oturum/$uuid/not', {'not': text})
            .timeout(_kNotTimeout);
      } catch (e) {
        debugPrint('M2YDesk: oturum notu gönderilemedi: $e');
      }
      close();
    }

    return CustomAlertDialog(
      title: const Text('Oturum notu (isteğe bağlı)'),
      content: SizedBox(
        width: 340,
        child: TextField(
          controller: controller,
          enabled: !busy,
          autofocus: true,
          maxLength: kM2yOturumNotMax,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Bu oturumla ilgili kısa not',
            border: OutlineInputBorder(),
          ),
        ).workaroundFreezeLinuxMint(),
      ),
      // Olumsuz/geri alan işlem solda, kaydeden sağda.
      actions: [
        dialogButton('Atla', onPressed: busy ? null : close, isOutline: true),
        dialogButton('Kaydet', onPressed: busy ? null : kaydet),
      ],
      onCancel: busy ? null : close,
    );
  });
  controller.dispose();
}
