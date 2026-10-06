// M2YDesk Hızlı Destek: pencere boyutlama yardımcıları.
// Kural: Hızlı Destek'te aydınlatma metni dışında hiçbir yerde kaydırma çubuğu olmaz; pencere içeriğe
// göre büyür/küçülür. Büyük diyaloglar açılırken pencere geçici olarak büyütülür, kapanınca geri döner.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:window_manager/window_manager.dart';

/// Çocuğun boyutu değişince (adım geçişi, hata iletisi…) [onChanged] çağrılır; dış widget yeniden
/// kurulmasa bile pencerenin içeriğe uydurulabilmesi için. Çocuk, penceredeki geçerli boyuttan BAĞIMSIZ
/// ölçülür (sınırsız kısıt): pencere bir kez dar kalırsa içerik de daralıp pencereyi geri
/// büyütememe kilidi oluşmaz.
class M2yBoyutIzleyici extends StatelessWidget {
  final VoidCallback onChanged;
  final Widget child;

  const M2yBoyutIzleyici({Key? key, required this.onChanged, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onChanged());
        return false;
      },
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        maxWidth: double.infinity,
        minHeight: 0,
        maxHeight: double.infinity,
        child: SizeChangedLayoutNotifier(child: child),
      ),
    );
  }
}

/// Hızlı Destek'te [goster] çalışırken pencereyi en az [enAz] boyuta büyütür, bitince ana boyuta
/// döndürür. Hızlı Destek değilse doğrudan çalıştırır.
Future<T> m2yPencereBuyutup<T>(Size enAz, Future<T> Function() goster) async {
  if (!bind.isIncomingOnly()) return goster();
  final cur = await windowManager.getSize();
  await windowManager.setSize(
      Size(max(cur.width, enAz.width), max(cur.height, enAz.height)));
  try {
    return await goster();
  } finally {
    await windowManager.setSize(getIncomingOnlyHomeSize());
  }
}

/// Hızlı Destek'te kaydırma yoktur (pencere büyür); diğer sürümde küçük pencerede taşmayı önlemek için sarar.
Widget m2yKaydirmaGerekirse(Widget child) =>
    bind.isIncomingOnly() ? child : SingleChildScrollView(child: child);
