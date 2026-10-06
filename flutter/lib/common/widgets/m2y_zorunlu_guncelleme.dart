// M2YDesk: zorunlu güncelleme — durum denetleyicisi ve kapatılamayan tam pencere katmanı.
//
// İmzası doğrulanmış `surum.json`'daki `asgari_surum` bu sürümden büyükse ana içerik yerine
// bu katman gösterilir; gelen bağlantı kapısı (`stop-service`) Rust tarafında kapatılır, giden
// bağlantı düğmesi devre dışıdır. Denetim açılışta ve 30 dakikada bir yapılır.
// Tasarım: docs/guncelleme.md "Zorunlu güncelleme". Türkçe sabit metin (çeviri anahtarı yok).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_login_gate.dart' show m2yCompact;
import 'package:flutter_hbb/common/widgets/m2y_pencere.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

const _kEvent = 'm2y_zorunlu_guncelleme';
const _kFullWidth = 380.0;

/// Güncelleme düğmesinin durumu. `method` (Rust `yontem`): kurulu (Windows kurulum),
/// tasinabilir (Windows taşınabilir/Hızlı Destek), sayfa (diğer platformlar: indirme sayfası).
enum M2yUpdateStage { idle, working, restarting, failed }

class M2yZorunluGuncelleme {
  M2yZorunluGuncelleme._();
  static final M2yZorunluGuncelleme instance = M2yZorunluGuncelleme._();

  static const _checkInterval = Duration(minutes: 30);

  final required = false.obs;
  final stage = M2yUpdateStage.idle.obs;
  String current = '';
  String minimum = '';
  String method = 'sayfa';
  String page = '';
  String error = '';
  Timer? _timer;
  bool _started = false;

  /// Ana pencere açılışında bir kez çağrılır.
  void start() {
    if (_started) return;
    _started = true;
    _refresh();
    platformFFI.registerEventHandler(_kEvent, _kEvent, (_) async => _refresh());
    bind.mainM2YCheckMandatoryUpdate();
    _timer = Timer.periodic(
        _checkInterval, (_) => bind.mainM2YCheckMandatoryUpdate());
  }

  void _refresh() {
    try {
      final m = jsonDecode(bind.mainM2YMandatoryUpdate());
      if (m is! Map<String, dynamic>) return;
      current = '${m['mevcut'] ?? ''}';
      minimum = '${m['gerekli'] ?? ''}';
      method = '${m['yontem'] ?? 'sayfa'}';
      page = '${m['sayfa'] ?? ''}';
      required.value = m['zorunlu'] == true;
    } catch (e) {
      debugPrint('M2YDesk: zorunlu güncelleme durumu okunamadı: $e');
    }
  }

  Future<void> openDownloadPage() async {
    if (page.isEmpty) return;
    await launchUrl(Uri.parse(page));
  }

  /// "Şimdi güncelle": Windows'ta indir + SHA-256 doğrula + kur/değiştir; başarısızlıkta ve
  /// diğer platformlarda indirme sayfası açılır.
  Future<void> updateNow() async {
    if (stage.value == M2yUpdateStage.working ||
        stage.value == M2yUpdateStage.restarting) {
      return;
    }
    if (!isWindows || method == 'sayfa') {
      await openDownloadPage();
      return;
    }
    error = '';
    stage.value = M2yUpdateStage.working;
    final err = await bind.mainM2YMandatoryUpdateNow();
    if (err.isNotEmpty) {
      error = err;
      stage.value = M2yUpdateStage.failed;
      await openDownloadPage();
      return;
    }
    stage.value = M2yUpdateStage.restarting;
    // Taşınabilir: yardımcı bu exe kapanınca üzerine yazıp yeni sürümü başlatır.
    // Kurulu: `--update` kurulumu çalışan süreçleri kendisi kapatır.
    if (method == 'tasinabilir') quit();
  }

  void quit() => exit(0);

  @visibleForTesting
  void dispose() {
    _timer?.cancel();
    platformFFI.unregisterEventHandler(_kEvent, _kEvent);
  }
}

class M2yZorunluGuncellemeKatmani extends StatefulWidget {
  const M2yZorunluGuncellemeKatmani({Key? key}) : super(key: key);

  @override
  State<M2yZorunluGuncellemeKatmani> createState() =>
      _M2yZorunluGuncellemeKatmaniState();
}

class _M2yZorunluGuncellemeKatmaniState
    extends State<M2yZorunluGuncellemeKatmani> {
  final _contentKey = GlobalKey();

  bool get _qs => bind.isIncomingOnly();

  /// Hızlı Destek penceresi içeriğe göre boyutlanır (giriş ekranındaki gibi).
  void _fitWindow() {
    if (!_qs || !mounted) return;
    final box = _contentKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if (box.size != imcomingOnlyHomeSize) {
      imcomingOnlyHomeSize = box.size;
      windowManager.setSize(getIncomingOnlyHomeSize());
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitWindow());
    final c = M2yZorunluGuncelleme.instance;
    final theme = Theme.of(context);
    final content = Obx(() {
      final stage = c.stage.value;
      final busy = stage == M2yUpdateStage.working ||
          stage == M2yUpdateStage.restarting;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.system_update_alt,
              size: _qs ? 28 : 40, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text('Yeni sürüm yayında', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Devam etmek için güncellemeniz gerekiyor '
            '(mevcut ${c.current}, gerekli ${c.minimum}).',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Güncelleme tamamlanana kadar bağlantı kabul edilmez ve kurulamaz.',
            style: theme.textTheme.bodySmall,
          ),
          if (stage != M2yUpdateStage.idle) ...[
            const SizedBox(height: 12),
            _status(context, stage),
          ],
          SizedBox(height: _qs ? 12 : 16),
          // Hızlı Destek'in dar penceresinde düğmeler yan yana sığmaz (taşıyordu): alt alta, tam genişlik,
          // birincil eylem üstte. Tam sürümde yan yana.
          if (_qs) ...[
            ElevatedButton(
              onPressed: busy ? null : c.updateNow,
              child: const Text('Şimdi güncelle'),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: stage == M2yUpdateStage.working ? null : c.quit,
              child: const Text('Programdan çık'),
            ),
          ] else
            Row(
              children: [
                OutlinedButton(
                  onPressed: stage == M2yUpdateStage.working ? null : c.quit,
                  child: const Text('Programdan çık'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: busy ? null : c.updateNow,
                  child: const Text('Şimdi güncelle'),
                ),
              ],
            ),
        ],
      );
    });
    final framed = Container(
      key: _contentKey,
      width: _qs ? m2yQsIcerikGenisligi() : null,
      padding: EdgeInsets.all(_qs ? 12 : 16),
      child: content,
    );
    // Kapatılamaz: arka plandaki içeriğin yerine geçer, geri/kapat eylemi yoktur.
    final sayfa = PopScope(
      canPop: false,
      child: Container(
        color: theme.colorScheme.background,
        alignment: _qs ? Alignment.topLeft : Alignment.center,
        // Hızlı Destek'te kaydırma YOK: pencere içeriğe göre büyür.
        child: _qs
            ? M2yBoyutIzleyici(onChanged: _fitWindow, child: framed)
            : SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kFullWidth),
                  child: framed,
                ),
              ),
      ),
    );
    // Hızlı Destek: giriş ekranlarıyla aynı sabit, kompakt yazı/düğme ölçeği.
    return _qs ? m2yCompact(context, sayfa) : sayfa;
  }

  Widget _status(BuildContext context, M2yUpdateStage stage) {
    final c = M2yZorunluGuncelleme.instance;
    final small = Theme.of(context).textTheme.bodySmall;
    switch (stage) {
      case M2yUpdateStage.working:
        return Row(children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Expanded(
              child: Text('İndiriliyor ve doğrulanıyor…', style: small)),
        ]);
      case M2yUpdateStage.restarting:
        return Text(
            c.method == 'tasinabilir'
                ? 'Yeni sürüm hazır; program yeniden başlatılıyor…'
                : 'Kurulum başlatıldı; tamamlanınca program yeniden açılır.',
            style: small);
      case M2yUpdateStage.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Güncelleme yapılamadı (${c.error}). İndirme sayfası açıldı; '
              'yeni sürümü oradan kurabilirsiniz.',
              style: small?.copyWith(color: Theme.of(context).colorScheme.error),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: c.openDownloadPage,
                child: const Text('İndirme sayfasını aç'),
              ),
            ),
          ],
        );
      case M2yUpdateStage.idle:
        return const SizedBox.shrink();
    }
  }
}
