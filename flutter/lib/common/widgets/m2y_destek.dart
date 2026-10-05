// M2YDesk: "Destek iste" düğmesi ve diyaloğu (Aşama 2: POST /api/m2y/talep).
// M2YDesk: Türkçe sabit metin (çeviri anahtarı kullanılmaz).
import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:http/http.dart' as http;

const kM2yAciklamaMax = 500;
const kM2yKurulusMax = 120;
const _kApiTimeout = Duration(seconds: 15);
final _controlRe = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

/// Oturum belirteciyle M2Y API çağrıları (Dart'tan doğrudan HTTP).
class M2yApi {
  M2yApi._();

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final url = await bind.mainGetApiServer();
    final headers = getHttpHeaders()..['Content-Type'] = 'application/json';
    return http
        .post(Uri.parse('$url$path'), headers: headers, body: jsonEncode(body))
        .timeout(_kApiTimeout);
  }

  static Future<http.Response> get(String path) async {
    final url = await bind.mainGetApiServer();
    return http
        .get(Uri.parse('$url$path'), headers: getHttpHeaders())
        .timeout(_kApiTimeout);
  }

  /// Sunucudaki profil (`POST /api/currentUser`); başarısızsa null.
  static Future<Map<String, dynamic>?> currentUser() async {
    try {
      final resp = await post('/api/currentUser', {
        'id': await bind.mainGetMyId(),
        'uuid': await bind.mainGetUuid(),
      });
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(decode_http_response(resp));
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      debugPrint('M2YDesk: profil alınamadı: $e');
      return null;
    }
  }

  /// Gövdedeki Türkçe `error` iletisi (yoksa boş).
  static String errorOf(http.Response resp) {
    try {
      final body = jsonDecode(decode_http_response(resp));
      if (body is Map && body['error'] != null) return body['error'].toString();
    } catch (_) {
      // Gövde JSON değil; çağıran HTTP koduna göre ileti seçer.
    }
    return '';
  }
}

/// Sol paneldeki sıkı, tam genişlikte düğme: yazı tek satırda kalır (sığmazsa küçülür).
Widget m2ySideButton({
  required String tooltip,
  required Widget icon,
  required String label,
  required VoidCallback onPressed,
}) {
  return Container(
    margin: const EdgeInsets.only(left: 20, right: 16, bottom: 6),
    width: double.infinity,
    child: Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 32),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        icon: IconTheme.merge(
            data: const IconThemeData(size: 16), child: icon),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, maxLines: 1, softWrap: false),
        ),
      ),
    ),
  );
}

/// Sol paneldeki "Destek iste" düğmesi.
class M2yDestekButton extends StatelessWidget {
  const M2yDestekButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return m2ySideButton(
      tooltip: 'Danışmanınızdan bağlanmasını isteyin',
      icon: const Icon(Icons.support_agent),
      label: 'Destek iste',
      onPressed: () => showDialog(
          context: context,
          builder: (ctx) => m2yCompactDialog(ctx, const _M2yDestekDialog())),
    );
  }
}

/// Diyaloglar için sıkı görünüm: küçük başlık, yoğun alanlar ve düğmeler.
Widget m2yCompactDialog(BuildContext context, Widget child) {
  final t = Theme.of(context);
  final buttonStyle = ButtonStyle(
    padding: const MaterialStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
    minimumSize: const MaterialStatePropertyAll(Size(0, 32)),
    textStyle: const MaterialStatePropertyAll(TextStyle(fontSize: 13)),
    visualDensity: VisualDensity.compact,
  );
  return Theme(
    data: t.copyWith(
      visualDensity: VisualDensity.compact,
      iconTheme: t.iconTheme.copyWith(size: 18),
      inputDecorationTheme: t.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
      dialogTheme: t.dialogTheme.copyWith(
        titleTextStyle: t.textTheme.titleMedium
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        contentTextStyle: t.textTheme.bodyMedium?.copyWith(fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: buttonStyle.merge(t.elevatedButtonTheme.style)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: buttonStyle.merge(t.outlinedButtonTheme.style)),
      textButtonTheme: TextButtonThemeData(
          style: buttonStyle.merge(t.textButtonTheme.style)),
    ),
    child: child,
  );
}

class _M2yDestekDialog extends StatefulWidget {
  const _M2yDestekDialog({Key? key}) : super(key: key);

  @override
  State<_M2yDestekDialog> createState() => _M2yDestekDialogState();
}

class _M2yDestekDialogState extends State<_M2yDestekDialog> {
  final _aciklama = TextEditingController();
  final _kurulus = TextEditingController();
  String _profilKurulus = '';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _aciklama.dispose();
    _kurulus.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = await M2yApi.currentUser();
    final kurulus = (user?['m2y_kurulus'] ?? '').toString();
    if (!mounted || kurulus.isEmpty) return;
    _profilKurulus = kurulus;
    if (_kurulus.text.isEmpty) _kurulus.text = kurulus;
  }

  String _errorText(http.Response resp) {
    final msg = M2yApi.errorOf(resp);
    switch (resp.statusCode) {
      case 429:
        return 'Kısa sürede çok fazla talep gönderdiniz, birkaç dakika sonra tekrar deneyin';
      case 401:
        return 'Oturumunuz sona ermiş. Lütfen yeniden giriş yapın.';
      case 400:
        return msg.isNotEmpty ? msg : 'Girilen bilgiler geçersiz.';
      default:
        return msg.isNotEmpty
            ? msg
            : 'Talep gönderilemedi (HTTP ${resp.statusCode}).';
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final aciklama = _aciklama.text.trim();
    final kurulus = _kurulus.text.trim();
    if (_controlRe.hasMatch(aciklama) || _controlRe.hasMatch(kurulus)) {
      setState(() => _error = 'Metinde geçersiz karakter var.');
      return;
    }
    if (kurulus.contains('\n') || kurulus.contains('\r')) {
      setState(() => _error = 'Kuruluş adı tek satır olmalıdır.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (kurulus.isNotEmpty && kurulus != _profilKurulus) {
        // Profil kaydı başarısız olsa da talep kuruluşu kendi gövdesinde taşır.
        try {
          await M2yApi.post('/api/m2y/profil', {'kurulus': kurulus});
        } catch (e) {
          debugPrint('M2YDesk: profil kaydedilemedi: $e');
        }
      }
      final myId = (await bind.mainGetMyId()).replaceAll(RegExp(r'\s'), '');
      final resp = await M2yApi.post('/api/m2y/talep', {
        'cihaz_id': myId,
        'aciklama': aciklama,
        'kurulus': kurulus,
      });
      if (resp.statusCode == 200) {
        if (!mounted) return;
        Navigator.of(context).pop();
        BotToast.showText(
            contentColor: Colors.green.shade700,
            text: 'Talebiniz iletildi — danışmanınız size bağlanacak');
        return;
      }
      _error = _errorText(resp);
    } catch (e) {
      debugPrint('M2YDesk: destek talebi gönderilemedi: $e');
      _error = 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Destek iste'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _aciklama,
                enabled: !_busy,
                maxLength: kM2yAciklamaMax,
                maxLines: 4,
                minLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Kısa açıklama (isteğe bağlı, en çok 500 karakter)',
                  alignLabelWithHint: true,
                ),
              ).workaroundFreezeLinuxMint(),
              const SizedBox(height: 8),
              TextField(
                controller: _kurulus,
                enabled: !_busy,
                maxLength: kM2yKurulusMax,
                decoration: const InputDecoration(labelText: 'Kuruluş'),
              ).workaroundFreezeLinuxMint(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error ?? '',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Gönder'),
        ),
      ],
    );
  }
}
