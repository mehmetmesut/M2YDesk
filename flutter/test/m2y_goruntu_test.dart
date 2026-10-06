// M2YDesk: Hızlı Destek ekranlarının görüntüsünü PNG olarak üretir (yerel ön izleme; derleme/oturum gerekmez).
// Çıktı: <depo>/yerel-onizleme/goruntuler/*.png  (git'e girmez). Çalıştırma:
//   flutter test --no-pub test/m2y_goruntu_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_auth.dart';
import 'package:flutter_hbb/common/widgets/m2y_login_gate.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/main.dart' show m2yTextScale;
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sahte extends Fake implements RustdeskImpl {
  @override
  String translate({required String name, required String locale, dynamic hint}) => name;
  @override
  bool isIncomingOnly({dynamic hint}) => true;
  @override
  String mainGetLocalOption({required String key, dynamic hint}) => '';
  @override
  String mainGetAppNameSync({dynamic hint}) => 'M2YDeskQS';
}

Future<void> _yaziTipi() async {
  for (final aile in ['Carlito', 'Calibri']) {
    final y = FontLoader(aile)
      ..addFont(rootBundle.load('assets/fonts/carlito/Carlito-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/carlito/Carlito-Bold.ttf'));
    await y.load();
  }
}

Future<void> _kaydet(WidgetTester tester, GlobalKey key, String ad) async {
  await tester.runAsync(() async {
    final RenderRepaintBoundary sinir =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image img = await sinir.toImage(pixelRatio: 3);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = Directory('../yerel-onizleme/goruntuler')..createSync(recursive: true);
    File('${dir.path}/$ad.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    platformFFI.ffiBind = _Sahte();
    await _yaziTipi();
  });

  setUp(() {
    m2yOidcYukleyici = () async => [
          {'name': 'google', 'icon': null},
          {'name': 'webauth', 'icon': null},
        ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), (_) async => null);
  });

  for (final asama in [M2yAuthStage.login, M2yAuthStage.setPassword]) {
    testWidgets('Hızlı Destek ekran görüntüsü: ${asama.name}', (tester) async {
      final key = GlobalKey();
      M2yAuth.instance.stage.value = asama;
      await tester.pumpWidget(MaterialApp(
        theme: MyTheme.darkTheme.copyWith(
          textTheme: MyTheme.darkTheme.textTheme.apply(fontFamily: 'Carlito'),
        ),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(m2yTextScale(m2yQsIcerikGenisligi()))),
          child: c!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              // Pencere içerik genişliği; yükseklik içeriğe göre (kaydırmasız).
              child: SizedBox(width: m2yQsIcerikGenisligi(), child: const M2yAuthGate()),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await _kaydet(tester, key, 'qs-${asama.name}');
    });
  }
}
