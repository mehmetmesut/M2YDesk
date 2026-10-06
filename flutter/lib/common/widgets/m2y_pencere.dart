// M2YDesk Hızlı Destek: pencere boyutlama yardımcıları.
// Kural: Hızlı Destek'te aydınlatma metni dışında hiçbir yerde kaydırma çubuğu olmaz; pencere içeriğe
// göre büyür/küçülür. Büyük diyaloglar açılırken pencere geçici olarak büyütülür, kapanınca geri döner.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

/// Çocuğun boyutu değişince (adım geçişi, hata iletisi…) [onChanged] çağrılır; dış widget yeniden
/// kurulmasa bile pencerenin içeriğe uydurulabilmesi için. Çocuk, penceredeki geçerli boyuttan BAĞIMSIZ
/// ölçülür (sınırsız kısıt): pencere bir kez dar kalırsa içerik de daralıp pencereyi geri
/// büyütememe kilidi oluşmaz.
class M2yBoyutIzleyici extends StatefulWidget {
  final VoidCallback onChanged;
  final Widget child;

  /// true: çocuk geçerli kısıtlardan bağımsız ölçülür (giriş ekranı). false: kısıtlar olduğu gibi
  /// geçer (sınırsız yükseklikli Column içinde kullanım).
  final bool bagimsizOlc;

  const M2yBoyutIzleyici(
      {Key? key,
      required this.onChanged,
      required this.child,
      this.bagimsizOlc = true})
      : super(key: key);

  @override
  State<M2yBoyutIzleyici> createState() => _M2yBoyutIzleyiciState();
}

class _M2yBoyutIzleyiciState extends State<M2yBoyutIzleyici> {
  @override
  void initState() {
    super.initState();
    // İlk çizimden sonra çerçeve payını öğren ve pencereyi uydur (boyut bildirimi ilk çizimde gelmez).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await m2yKenarPayiniOgren(context);
      widget.onChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged());
        return false;
      },
      child: widget.bagimsizOlc
          ? OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              child: SizeChangedLayoutNotifier(child: child),
            )
          : SizeChangedLayoutNotifier(child: child),
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

/// Pencere dış genişliği ile içerik (Flutter görünümü) genişliği arasındaki gerçek farkı öğrenir; fark
/// değiştiyse içerik genişliği yeniden hesaplansın diye arayüzü yeniden kurar ve pencereyi uydurur.
Future<void> m2yKenarPayiniOgren(BuildContext context) async {
  if (!bind.isIncomingOnly() || !context.mounted) return;
  final Size dis;
  try {
    dis = await windowManager.getSize();
  } catch (e) {
    debugPrint('M2YDesk: pencere boyutu okunamadı: $e');
    return;
  }
  if (!context.mounted) return;
  final view = View.of(context);
  final ic = view.physicalSize.width / view.devicePixelRatio;
  final pay = dis.width - ic;
  if (pay < 0 || pay > 40 || (pay - m2yKenarPayi).abs() < 0.5) return;
  m2yKenarPayi = pay;
  Get.forceAppUpdate();
  await windowManager.setSize(getIncomingOnlyHomeSize());
}
