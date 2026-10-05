// M2YDesk: macOS Ekran Kaydı ve Erişilebilirlik izinleri için adım adım rehber.
// İzinleri uygulama VERMEZ; kullanıcı macOS Sistem Ayarları'nda kendisi etkinleştirir.
// Rehber: neden gerektiği, adımlar, örnek görünüm, ilgili ayar sayfasını açan düğme,
// ayrı ayrı durum, uygulamaya dönüşte yeniden denetim ve gerekirse yeniden başlatma.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/utils/platform_channel.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/platform_model.dart';

const _kScreenUrl =
    'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture';
const _kAccessibilityUrl =
    'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility';

bool m2yMacEkranKaydiVar() => bind.mainIsCanScreenRecording(prompt: false);
bool m2yMacErisilebilirlikVar() => bind.mainIsProcessTrusted(prompt: false);

/// Gelen bağlantıya yanıt veren kurulumda izinlerden biri eksik mi?
bool m2yMacIzinEksik() =>
    !bind.isOutgoingOnly() &&
    (!m2yMacEkranKaydiVar() || !m2yMacErisilebilirlikVar());

bool _otomatikAcildi = false;

void m2yMacIzinleriniAc(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: 640),
        child: M2yMacIzinleri(),
      ),
    ),
  );
}

/// Uygulama açılışında izin eksikse rehberi bir kez kendiliğinden açar.
void m2yMacIzinleriniBirKezAc(BuildContext context) {
  if (_otomatikAcildi) return;
  _otomatikAcildi = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) m2yMacIzinleriniAc(context);
  });
}

class _Izin {
  final String baslik;
  final String neden;
  final String ayarAdi;
  final String url;
  final String yol;
  final bool Function() verildi;
  final void Function() kaydet; // uygulamayı sistem listesine ekleyen istek
  const _Izin({
    required this.baslik,
    required this.neden,
    required this.ayarAdi,
    required this.url,
    required this.yol,
    required this.verildi,
    required this.kaydet,
  });
}

class M2yMacIzinleri extends StatefulWidget {
  const M2yMacIzinleri({Key? key}) : super(key: key);

  @override
  State<M2yMacIzinleri> createState() => _M2yMacIzinleriState();
}

class _M2yMacIzinleriState extends State<M2yMacIzinleri>
    with WidgetsBindingObserver {
  late final List<_Izin> _izinler;
  final Map<String, bool> _durum = {};
  final Set<String> _acilan = {}; // ayar sayfası açılan izinler
  final Set<String> _donulen = {}; // açıldıktan sonra uygulamaya dönülenler
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _izinler = [
      _Izin(
        baslik: 'Ekran Kaydı',
        neden:
            'Danışmanınızın ekranınızı görebilmesi için gerekir. Yalnızca siz bağlantıyı kabul ettiğinizde kullanılır.',
        ayarAdi: 'Ekran ve Sistem Sesi Kaydı',
        url: _kScreenUrl,
        yol:
            'macOS 15: Sistem Ayarları → Gizlilik ve Güvenlik → Ekran ve Sistem Sesi Kaydı\n'
            'macOS 13–14: Sistem Ayarları → Gizlilik ve Güvenlik → Ekran Kaydı\n'
            'macOS 12 ve öncesi: Sistem Tercihleri → Güvenlik ve Gizlilik → Gizlilik → Ekran Kaydı',
        verildi: m2yMacEkranKaydiVar,
        kaydet: () => bind.mainIsCanScreenRecording(prompt: true),
      ),
      _Izin(
        baslik: 'Erişilebilirlik',
        neden:
            'Danışmanınız, siz izin verdiğinizde fare ve klavyeyi kullanarak size yardım edebilsin diye gerekir. Bağlantı bitince kullanılmaz.',
        ayarAdi: 'Erişilebilirlik',
        url: _kAccessibilityUrl,
        yol:
            'macOS 13 ve sonrası: Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik\n'
            'macOS 12 ve öncesi: Sistem Tercihleri → Güvenlik ve Gizlilik → Gizlilik → Erişilebilirlik',
        verildi: m2yMacErisilebilirlikVar,
        kaydet: () => bind.mainIsProcessTrusted(prompt: true),
      ),
    ];
    WidgetsBinding.instance.addObserver(this);
    _denetle();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _denetle());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Kullanıcı sistem ayarlarından uygulamaya döndüğünde durumu hemen yeniden denetle.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      for (final i in _izinler) {
        if (_acilan.contains(i.baslik)) _donulen.add(i.baslik);
      }
      _denetle();
    }
  }

  void _denetle() {
    var degisti = false;
    for (final i in _izinler) {
      final v = i.verildi();
      if (_durum[i.baslik] != v) {
        _durum[i.baslik] = v;
        degisti = true;
      }
    }
    if (degisti && mounted) setState(() {});
  }

  Future<void> _ayarlariAc(_Izin i) async {
    _acilan.add(i.baslik);
    i.kaydet(); // uygulamayı ilgili izin listesine ekletir
    await Future.delayed(const Duration(milliseconds: 700));
    try {
      await launchUrlString(i.url);
    } catch (_) {
      // Açılamazsa kullanıcı aşağıdaki yolu izler.
    }
    if (mounted) setState(() {});
  }

  Future<void> _yenidenBaslat() async {
    try {
      final exe = Platform.resolvedExecutable; // ….app/Contents/MacOS/<ad>
      final k = exe.indexOf('.app/');
      if (k > 0) {
        final app = exe.substring(0, k + 4);
        await Process.start(
            '/bin/sh', ['-c', 'sleep 2; open "\$1"', 'sh', app],
            mode: ProcessStartMode.detached);
      }
    } catch (_) {
      // Yeniden açma başarısızsa kullanıcı uygulamayı kendisi açar.
    }
    await RdPlatformChannel.instance.terminate();
  }

  @override
  Widget build(BuildContext context) {
    final verilen = _izinler.where((i) => _durum[i.baslik] == true).length;
    final hepsi = verilen == _izinler.length;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Uzaktan destek için 2 izin gerekli',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'macOS, bu izinleri yalnızca sizin vermenize izin verir. Aşağıdaki düğme ilgili ayar sayfasını açar; '
              'listede M2YDesk\'i bulup anahtarı kendiniz açın. $verilen / ${_izinler.length} izin verildi.',
              style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 14),
            for (final i in _izinler) _izinKarti(i),
            if (hepsi) _basari(),
          ],
        ),
      ),
    );
  }

  Widget _basari() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Tüm izinler verildi. M2YDesk kullanıma hazır.')),
          FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Tamam')),
        ],
      ),
    );
  }

  Widget _izinKarti(_Izin i) {
    final tamam = _durum[i.baslik] == true;
    final scheme = Theme.of(context).colorScheme;
    if (tamam) {
      // Verilmiş izin için adımlar tekrarlanmaz.
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Text('${i.baslik} izni verildi',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
    }
    final dondu = _donulen.contains(i.baslik);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(i.baslik,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            _etiket('Eksik', Colors.orange),
          ]),
          const SizedBox(height: 8),
          Text(i.neden),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            final adimlar = _adimlar(i);
            final cizim = _AyarlarCizimi(ayarAdi: i.ayarAdi);
            if (c.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [adimlar, const SizedBox(height: 10), cizim],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: adimlar),
                const SizedBox(width: 14),
                cizim,
              ],
            );
          }),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton.icon(
              onPressed: () => _ayarlariAc(i),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('${i.baslik} ayarlarını aç'),
            ),
          ]),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text('Sayfa açılmazsa buradan ulaşın',
                  style: TextStyle(fontSize: 13)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(i.yol,
                      style: const TextStyle(fontSize: 12.5, height: 1.5)),
                ),
              ],
            ),
          ),
          if (dondu) _yenidenBaslatUyarisi(i),
        ],
      ),
    );
  }

  Widget _yenidenBaslatUyarisi(_Izin i) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${i.baslik} izni henüz görünmüyor. Anahtarı açtıysanız macOS izni '
              'yeni oturumda tanır: M2YDesk\'i yeniden başlatın. Açmadıysanız '
              'yukarıdaki düğmeyle ayarlara dönüp "M2YDesk" anahtarını açın.',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _yenidenBaslat,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('M2YDesk\'i yeniden başlat'),
          ),
        ],
      ),
    );
  }

  Widget _adimlar(_Izin i) {
    final adimlar = [
      '"${i.baslik} ayarlarını aç" düğmesine basın. Sistem Ayarları\'nda "${i.ayarAdi}" sayfası açılır.',
      'Listede "M2YDesk"\'i bulun ve yanındaki anahtarı açın. Listede yoksa alttaki "+" ile ekleyebilirsiniz.',
      'macOS "Çıkış yap ve yeniden aç" ya da parolanızı isterse onaylayın; ardından M2YDesk\'e dönün.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var n = 0; n < adimlar.length; n++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text('${n + 1}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(adimlar[n])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _etiket(String metin, Color renk) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: renk.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(metin,
            style: TextStyle(
                fontSize: 12, color: renk, fontWeight: FontWeight.w600)),
      );
}

/// Örnek Sistem Ayarları görünümü (görsel anlatım). Ekrandaki sürüm macOS'a göre biraz farklı olabilir.
class _AyarlarCizimi extends StatelessWidget {
  final String ayarAdi;
  const _AyarlarCizimi({Key? key, required this.ayarAdi}) : super(key: key);

  Widget _satir(String ad, {required bool acik, bool vurgu = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: vurgu ? const Color(0xffe8f0fe) : Colors.transparent,
        border: Border.all(
            color: vurgu ? const Color(0xff1a73e8) : Colors.transparent,
            width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: vurgu ? const Color(0xff1a73e8) : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(ad,
              style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.black87,
                  fontWeight: vurgu ? FontWeight.bold : FontWeight.normal)),
        ),
        // Anahtar
        Container(
          width: 28,
          height: 16,
          padding: const EdgeInsets.all(2),
          alignment: acik ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: acik ? const Color(0xff34c759) : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            width: 12,
            height: 12,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: const Color(0xfff5f5f7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xffe3e3e8),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              for (final c in const [
                Color(0xffff5f57),
                Color(0xffffbd2e),
                Color(0xff28c840)
              ])
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(ayarAdi,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _satir('Başka bir uygulama', acik: true),
                const SizedBox(height: 4),
                _satir('M2YDesk', acik: true, vurgu: true),
                const SizedBox(height: 4),
                _satir('Diğer uygulama', acik: false),
                const SizedBox(height: 6),
                Row(children: const [
                  Icon(Icons.arrow_upward, size: 14, color: Color(0xff1a73e8)),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text('Bu satırdaki anahtarı açın',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff1a73e8),
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
