// M2YDesk: sol paneldeki durum/öneri kartı (kurulum, güncelleme, izin, uyarı, hata).
// RustDesk'in pembe degrade kartı yerine temaya uyumlu, sade kart: solda ince renk şeridi, simge + başlık,
// kısa metin, kompakt düğme (kullanıcı isteği 06.10.2026: "daha profesyonel").
// M2YDesk: Türkçe sabit metin; bilinen RustDesk anahtarları kısa Türkçe karşılıklarıyla gösterilir.
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:url_launcher/url_launcher.dart';

enum M2yKartTuru { bilgi, uyari, hata, guncelleme }

/// Bilinen RustDesk kart anahtarlarının kısa M2YDesk metinleri: anahtar → (başlık, metin, düğme).
const Map<String, (String, String, String)> _kKisaMetinler = {
  'install_tip': (
    'Kurulum önerilir',
    'Yönetici izni isteyen ekranlarda da uzaktan destek alabilmek için M2YDesk’i bilgisayara kurun.',
    'Kur',
  ),
  'install_daemon_tip': (
    'Sistem hizmeti',
    'Bilgisayar açıldığında otomatik başlaması için sistem hizmetini kurun.',
    'Kur',
  ),
  'Your installation is lower version.': (
    'Güncelleme',
    'Kurulu sürüm bu programdan eski.',
    'Güncelle',
  ),
};

class M2yBilgiKarti extends StatelessWidget {
  final String baslik;
  final String metin;
  final String dugme;
  final VoidCallback? onPressed;
  final M2yKartTuru tur;
  final String? yardim;
  final String? baglanti;
  final VoidCallback? onKapat;
  final EdgeInsets margin;

  const M2yBilgiKarti({
    Key? key,
    required this.baslik,
    required this.metin,
    this.dugme = '',
    this.onPressed,
    this.tur = M2yKartTuru.bilgi,
    this.yardim,
    this.baglanti,
    this.onKapat,
    this.margin = const EdgeInsets.fromLTRB(12, 12, 12, 0),
  }) : super(key: key);

  /// RustDesk'in buildInstallCard parametrelerinden kart üretir (anahtarlar çevrilir, tür başlıktan çıkarılır).
  factory M2yBilgiKarti.rustdesk({
    required String title,
    required String content,
    required String btnText,
    VoidCallback? onPressed,
    String? help,
    String? link,
    VoidCallback? onKapat,
    bool hata = false,
    EdgeInsets margin = const EdgeInsets.fromLTRB(12, 12, 12, 0),
  }) {
    final kisa = _kKisaMetinler[content];
    final tur = hata
        ? M2yKartTuru.hata
        : (title == 'Warning' || title == 'Permissions' || title == 'İzinler')
            ? M2yKartTuru.uyari
            : (title == 'Status' || kisa?.$1 == 'Güncelleme')
                ? M2yKartTuru.guncelleme
                : M2yKartTuru.bilgi;
    String ceviri(String s) => s.isEmpty ? '' : translate(s);
    return M2yBilgiKarti(
      baslik: kisa?.$1 ?? (hata ? 'Hata' : ceviri(title)),
      metin: kisa?.$2 ?? ceviri(content),
      dugme: btnText.isEmpty ? '' : (kisa?.$3 ?? ceviri(btnText)),
      onPressed: onPressed,
      tur: tur,
      yardim: help == null ? null : ceviri(help),
      baglanti: link,
      onKapat: onKapat,
      margin: margin,
    );
  }

  (Color, IconData) _renkVeSimge(ThemeData t) {
    switch (tur) {
      case M2yKartTuru.uyari:
        return (Colors.amber.shade700, Icons.warning_amber_rounded);
      case M2yKartTuru.hata:
        return (t.colorScheme.error, Icons.error_outline);
      case M2yKartTuru.guncelleme:
        return (Colors.teal, Icons.system_update_alt);
      case M2yKartTuru.bilgi:
        return (MyTheme.accent, Icons.info_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final (renk, simge) = _renkVeSimge(t);
    final ikincil = t.textTheme.bodySmall?.color ?? t.hintColor;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Color.alphaBlend(renk.withOpacity(0.07), t.cardColor),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withOpacity(0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: renk),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 6, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Icon(simge, size: 16, color: renk),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          baslik,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (onKapat != null)
                        IconButton(
                          tooltip: 'Kapat',
                          onPressed: onKapat,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 22, height: 22),
                          iconSize: 14,
                          icon: Icon(Icons.close, color: ikincil),
                        ),
                    ]),
                    if (metin.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(metin, style: TextStyle(fontSize: 12, height: 1.35, color: ikincil)),
                    ],
                    if (dugme.isNotEmpty || yardim != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        if (yardim != null && baglanti != null)
                          InkWell(
                            onTap: () => launchUrl(Uri.parse(baglanti!)),
                            child: Text(yardim!,
                                style: TextStyle(fontSize: 12, color: renk, decoration: TextDecoration.underline)),
                          ),
                        const Spacer(),
                        if (dugme.isNotEmpty)
                          SizedBox(
                            height: 28,
                            child: ElevatedButton(
                              onPressed: onPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: renk,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: Text(dugme, maxLines: 1),
                            ),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
