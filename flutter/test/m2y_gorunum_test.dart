// M2YDesk: arayüz yerleşim ve orantı testleri.
// Amaç: derlemeye (≈1 saat) girmeden düğme metninin kaymasını, taşmasını ve eylem sırasını yakalamak.
// Gerçek yazı tipi (Carlito, Calibri ile ölçü uyumlu) yüklenir; böylece genişlik ölçümleri gerçekçidir.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_destek.dart';
import 'package:flutter_hbb/common/widgets/m2y_login_gate.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sol panel genişlikleri: tam sürüm 224, Hızlı Destek 280.
const _panelWidths = [224.0, 280.0];

/// Uygulamanın `m2yTextScale` aralığı (0.80–0.88) ve kullanıcı erişilebilirlik ölçeği (1.3).
const _textScales = [0.80, 0.88, 1.0, 1.3];

/// Windows'ta uygulama sistem Calibri'sini kullanır (`kM2yFontFamily`); testte sistem yazı tipi yoktur.
/// Calibri ile ölçü uyumlu Carlito, hem 'Carlito' hem 'Calibri' adıyla yüklenir.
Future<void> _loadCarlito() async {
  for (final family in ['Carlito', 'Calibri']) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/carlito/Carlito-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/carlito/Carlito-Bold.ttf'));
    await loader.load();
  }
}

Widget _app(Widget child, {double textScale = 0.88}) {
  return MaterialApp(
    theme: MyTheme.darkTheme.copyWith(
      textTheme: MyTheme.darkTheme.textTheme.apply(fontFamily: 'Carlito'),
    ),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: c!,
    ),
    home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
  );
}

/// Rust çekirdeği olmadan çalışan sahte köprü: `translate` anahtarı olduğu gibi döndürür,
/// diğer çağrılar sessizce boş döner (test yalnız yerleşimi denetler).
class _SahteKopru extends Fake implements RustdeskImpl {
  @override
  String translate({required String name, required String locale, dynamic hint}) => name;
}

void main() {
  setUpAll(() async {
    platformFFI.ffiBind = _SahteKopru();
    await _loadCarlito();
  });

  group('Sol panel düğmesi (m2ySideButton)', () {
    for (final width in _panelWidths) {
      for (final scale in _textScales) {
        testWidgets('${width.toInt()} px panel, yazı ölçeği $scale: taşmaz, metin küçülmez',
            (tester) async {
          const label = 'WhatsApp ile gönder';
          await tester.pumpWidget(_app(
            SizedBox(
              width: width,
              child: m2ySideButton(
                tooltip: 'ipucu',
                icon: const Icon(Icons.chat),
                label: label,
                onPressed: () {},
              ),
            ),
            textScale: scale,
          ));
          await tester.pumpAndSettle();

          // Taşma (RenderFlex overflow) ya da başka bir çizim hatası yok.
          expect(tester.takeException(), isNull);

          // Düğme panelin sağ kenarını aşmıyor.
          final button = tester.getRect(find.bySubtype<OutlinedButton>());
          expect(button.right, lessThanOrEqualTo(width));

          // Metin tek satır: yüksekliği yazı boyutunun ~1,6 katını aşmaz.
          final text = tester.getSize(find.text(label));
          expect(text.height, lessThan(13 * scale * 1.6 + 1));

          // FittedBox metni küçültmüyor: gerçek ölçeklerde (≤ 1.0) sığıyor. Erişilebilirlik ölçeği 1.3'te
          // en çok %15 küçültmeye izin verilir (taşmak yerine küçülür).
          final fitted = tester.getSize(find.byType(FittedBox)).width;
          final tolerance = scale > 1.0 ? 1.15 : 1.0;
          expect(text.width, lessThanOrEqualTo(fitted * tolerance + 0.5),
              reason: 'metin düğmeye sığmıyor, küçültülüyor ($width px, ölçek $scale)');
        });
      }
    }

    testWidgets('düğme yüksekliği kompakt (≤ 40 px)', (tester) async {
      await tester.pumpWidget(_app(
        SizedBox(
          width: 224,
          child: m2ySideButton(
            tooltip: 'ipucu',
            icon: const Icon(Icons.support_agent),
            label: 'Destek iste',
            onPressed: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.bySubtype<OutlinedButton>()).height, lessThanOrEqualTo(40));
    });
  });

  group('Diyalog düğmeleri (m2yCompactDialog)', () {
    testWidgets('Vazgeç solda, Gönder sağda; aynı satırda', (tester) async {
      await tester.pumpWidget(_app(
        Builder(
          builder: (context) => m2yCompactDialog(
            context,
            AlertDialog(
              title: const Text('Destek iste'),
              content: const SizedBox(width: 340, height: 60),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                OutlinedButton(onPressed: () {}, child: const Text('Vazgeç')),
                ElevatedButton(onPressed: () {}, child: const Text('Gönder')),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final iptal = tester.getRect(find.widgetWithText(OutlinedButton, 'Vazgeç'));
      final gonder = tester.getRect(find.widgetWithText(ElevatedButton, 'Gönder'));
      expect(gonder.left, greaterThan(iptal.right), reason: 'birincil eylem sağda olmalı');
      expect((gonder.center.dy - iptal.center.dy).abs(), lessThan(1), reason: 'aynı satırda');
      expect(gonder.height, lessThanOrEqualTo(40));
    });
  });

  group('Giriş ekranı harici düğmeleri (M2yOidcButtons)', () {
    final options = [
      {'name': 'google', 'icon': null},
      {'name': 'webauth', 'icon': null},
    ];

    for (final boxWidth in [324.0, 304.0, 360.0]) {
      testWidgets('iki düğme ${boxWidth.toInt()} px kutuda aynı satırda, eşit genişlikte ve ortalı',
          (tester) async {
        await tester.pumpWidget(_app(
          SizedBox(
            width: boxWidth,
            child: M2yOidcButtons(
              options: options,
              curOP: ''.obs,
              onLogin: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final buttons = find.byType(ElevatedButton);
        expect(buttons, findsNWidgets(2));
        final a = tester.getRect(buttons.at(0));
        final b = tester.getRect(buttons.at(1));

        expect((a.center.dy - b.center.dy).abs(), lessThan(1), reason: 'aynı satırda olmalı');
        expect((a.width - b.width).abs(), lessThan(1), reason: 'eşit genişlikte olmalı');
        // Kutuya göre ortalı: sol ve sağ boşluklar eşit.
        final solBosluk = a.left;
        final sagBosluk = boxWidth - b.right;
        expect((solBosluk - sagBosluk).abs(), lessThan(1), reason: 'ortalı olmalı');
        expect(b.right, lessThanOrEqualTo(boxWidth));
      });
    }

    testWidgets('tek seçenek ortalanır', (tester) async {
      await tester.pumpWidget(_app(
        SizedBox(
          width: 324,
          child: M2yOidcButtons(
            options: [options.first],
            curOP: ''.obs,
            onLogin: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final a = tester.getRect(find.byType(ElevatedButton));
      expect((a.left - (324 - a.right)).abs(), lessThan(1));
    });
  });
}
