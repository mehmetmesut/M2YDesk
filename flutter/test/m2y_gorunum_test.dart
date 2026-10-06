// M2YDesk: arayüz yerleşim ve orantı testleri.
// Amaç: derlemeye (≈1 saat) girmeden düğme metninin kaymasını, taşmasını ve eylem sırasını yakalamak.
// Gerçek yazı tipi (Carlito, Calibri ile ölçü uyumlu) yüklenir; böylece genişlik ölçümleri gerçekçidir.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_destek.dart';
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

void main() {
  setUpAll(_loadCarlito);

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
}
