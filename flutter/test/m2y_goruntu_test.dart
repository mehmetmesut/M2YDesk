// M2YDesk: giriş ve güncelleme ekranlarının görüntüsünü PNG olarak üretir (yerel ön izleme; derleme/oturum gerekmez).
// Kapsam: Hızlı Destek (210 px pencere), tam sürüm (masaüstü), Android telefon (360x640), açık ve koyu tema.
// Çıktı: <depo>/yerel-onizleme/goruntuler/*.png  (git'e girmez). Çalıştırma:
//   flutter test --no-pub test/m2y_goruntu_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_auth.dart';
import 'package:flutter_hbb/common/widgets/m2y_bilgi_karti.dart';
import 'package:flutter_hbb/common/widgets/m2y_login_gate.dart';
import 'package:flutter_hbb/common/widgets/m2y_zorunlu_guncelleme.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/main.dart' show m2yTextScale;
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sahte extends Fake implements RustdeskImpl {
  bool hizli = true;
  @override
  String translate({required String name, required String locale, dynamic hint}) => name;
  @override
  bool isIncomingOnly({dynamic hint}) => hizli;
  @override
  String mainGetLocalOption({required String key, dynamic hint}) => '';
  @override
  String mainGetAppNameSync({dynamic hint}) => hizli ? 'M2YDeskQS' : 'M2YDesk';
}

final _kopru = _Sahte();

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
    final ui.Image img = await sinir.toImage(pixelRatio: 2);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = Directory('../yerel-onizleme/goruntuler')..createSync(recursive: true);
    File('${dir.path}/$ad.png').writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

ThemeData _tema(bool koyu) {
  final t = koyu ? MyTheme.darkTheme : MyTheme.lightTheme;
  return t.copyWith(textTheme: t.textTheme.apply(fontFamily: 'Carlito'));
}

/// [genislik] x [yukseklik] mantıksal piksellik bir "pencere" içinde [icerik] çizer ve kaydeder.
Future<void> _ciz(WidgetTester tester, String ad,
    {required double genislik,
    required double yukseklik,
    required Widget icerik,
    bool koyu = false}) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(genislik, yukseklik);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _tema(koyu),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(m2yTextScale(genislik))),
        child: c!,
      ),
      home: Scaffold(body: SafeArea(child: icerik)),
    ),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '$ad taşmamalı');
  await _kaydet(tester, key, ad);
}

void main() {
  setUpAll(() async {
    platformFFI.ffiBind = _kopru;
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

  // Hızlı Destek: pencere içeriğe göre boyutlanır; önce ölçülür, sonra o yükseklikte çizilir.
  for (final koyu in [false, true]) {
    for (final asama in [M2yAuthStage.login, M2yAuthStage.setPassword]) {
      final ad = '1-hizli-destek-${asama == M2yAuthStage.login ? 'giris' : 'sabit-parola'}-${koyu ? 'koyu' : 'acik'}';
      testWidgets(ad, (tester) async {
        _kopru.hizli = true;
        M2yAuth.instance.stage.value = asama;
        final w = m2yQsIcerikGenisligi();
        await _ciz(tester, '_olcum', genislik: w, yukseklik: 1200, icerik: const M2yAuthGate(), koyu: koyu);
        final h = imcomingOnlyHomeSize.height;
        await _ciz(tester, ad, genislik: w, yukseklik: h, icerik: const M2yAuthGate(), koyu: koyu);
      });
    }
  }

  testWidgets('2-tam-surum-giris-acik', (tester) async {
    _kopru.hizli = false;
    M2yAuth.instance.stage.value = M2yAuthStage.login;
    await _ciz(tester, '2-tam-surum-giris-acik', genislik: 800, yukseklik: 600, icerik: const M2yAuthGate());
  });

  testWidgets('2-tam-surum-sabit-parola-acik', (tester) async {
    _kopru.hizli = false;
    M2yAuth.instance.stage.value = M2yAuthStage.setPassword;
    await _ciz(tester, '2-tam-surum-sabit-parola-acik', genislik: 800, yukseklik: 600, icerik: const M2yAuthGate());
  });

  testWidgets('3-android-giris-acik', (tester) async {
    _kopru.hizli = false;
    M2yAuth.instance.stage.value = M2yAuthStage.login;
    await _ciz(tester, '3-android-giris-acik', genislik: 360, yukseklik: 640, icerik: const M2yAuthGate());
  });

  testWidgets('3-android-giris-koyu', (tester) async {
    _kopru.hizli = false;
    M2yAuth.instance.stage.value = M2yAuthStage.login;
    await _ciz(tester, '3-android-giris-koyu', genislik: 360, yukseklik: 640, icerik: const M2yAuthGate(), koyu: true);
  });

  testWidgets('4-zorunlu-guncelleme-tam-surum', (tester) async {
    _kopru.hizli = false;
    M2yZorunluGuncelleme.instance
      ..current = '1.0.2'
      ..minimum = '1.0.3';
    await _ciz(tester, '4-zorunlu-guncelleme-tam-surum',
        genislik: 800, yukseklik: 600, icerik: const M2yZorunluGuncellemeKatmani());
  });

  for (final koyu in [true, false]) {
    testWidgets('5-bilgi-kartlari-${koyu ? 'koyu' : 'acik'}', (tester) async {
      _kopru.hizli = false;
      await _ciz(tester, '5-bilgi-kartlari-${koyu ? 'koyu' : 'acik'}',
          genislik: 260,
          yukseklik: 520,
          koyu: koyu,
          icerik: SingleChildScrollView(
            child: Column(children: [
              M2yBilgiKarti.rustdesk(title: '', content: 'install_tip', btnText: 'Install', onPressed: () {}),
              M2yBilgiKarti.rustdesk(
                  title: 'Status', content: 'Your installation is lower version.', btnText: 'Click to upgrade', onPressed: () {}),
              M2yBilgiKarti.rustdesk(
                  title: 'Warning', content: 'wayland_experiment_tip', btnText: '', help: 'Help', link: 'https://x', onKapat: () {}),
              M2yBilgiKarti.rustdesk(title: '', content: 'Hizmet başlatılamadı.', btnText: '', hata: true),
            ]),
          ));
    });
  }

  testWidgets('4-zorunlu-guncelleme-android', (tester) async {
    _kopru.hizli = false;
    M2yZorunluGuncelleme.instance
      ..current = '1.0.2'
      ..minimum = '1.0.3';
    await _ciz(tester, '4-zorunlu-guncelleme-android',
        genislik: 360, yukseklik: 640, icerik: const M2yZorunluGuncellemeKatmani());
  });
}
