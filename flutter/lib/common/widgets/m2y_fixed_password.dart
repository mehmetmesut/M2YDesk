// M2YDesk: sabit parola (6 hane, yalnızca rakam, iki kez) formu ve
// Hızlı Destek ana penceresindeki küçük erişim menüsü.
// M2YDesk: Türkçe sabit metin (çeviri anahtarı kullanılmaz).
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_auth.dart';
import 'package:flutter_hbb/common/widgets/m2y_pencere.dart';
import 'package:flutter_hbb/models/platform_model.dart';

const _kAccessInfo =
    'Bu parolayla danışmanınız siz bilgisayar başında olmasanız da '
    'bağlanabilir. İstediğiniz an kapatabilir veya değiştirebilirsiniz.';

class M2yFixedPasswordForm extends StatefulWidget {
  /// Hızlı Destek ilk kurulumunda "Sürekli erişime izin ver" kutusu gösterilir.
  final bool showAccessToggle;
  final VoidCallback onSaved;

  /// Verilirse solda "Vazgeç" düğmesi gösterilir (ilk açılışta atlanamaz).
  final VoidCallback? onCancel;

  const M2yFixedPasswordForm({
    Key? key,
    required this.showAccessToggle,
    required this.onSaved,
    this.onCancel,
  }) : super(key: key);

  @override
  State<M2yFixedPasswordForm> createState() => _M2yFixedPasswordFormState();
}

class _M2yFixedPasswordFormState extends State<M2yFixedPasswordForm> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String? _err1;
  String? _err2;
  bool _access = true;
  bool _busy = false;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    // Girdi temizlenmez; yalnızca hata gösterilir.
    final a = _p1.text;
    final b = _p2.text;
    String? e1;
    String? e2;
    if (!m2yIsFixedPassword(a)) {
      e1 = 'Parola tam 6 haneli olmalı ve yalnızca rakam içermelidir.';
    } else if (a != b) {
      e2 = 'Parolalar aynı değil.';
    }
    setState(() {
      _err1 = e1;
      _err2 = e2;
    });
    if (e1 != null || e2 != null) return;
    setState(() => _busy = true);
    final ok = await bind.mainSetPermanentPasswordWithResult(password: a);
    if (ok && widget.showAccessToggle) {
      await M2yAuth.instance.setPermanentAccess(_access);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _err1 = 'Parola kaydedilemedi. Lütfen yeniden deneyin.';
    });
    if (ok) widget.onSaved();
  }

  Widget _field(TextEditingController c, String label, String? err,
      {bool autofocus = false}) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      enabled: !_busy,
      decoration: InputDecoration(labelText: label, errorText: err, errorMaxLines: 3),
      onSubmitted: (_) => _submit(),
    ).workaroundFreezeLinuxMint();
  }

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(_p1, 'Sabit parola (6 rakam)', _err1, autofocus: true),
        const SizedBox(height: 8),
        _field(_p2, 'Sabit parola (tekrar)', _err2),
        if (widget.showAccessToggle) ...[
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _access,
            onChanged: _busy ? null : (v) => setState(() => _access = v ?? true),
            title: const Text('Sürekli erişime izin ver'),
          ),
          Text(_kAccessInfo, style: small),
        ],
        const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(),
        const SizedBox(height: 4),
        // Birincil sağda, Vazgeç solda.
        Row(
          children: [
            if (widget.onCancel != null)
              OutlinedButton(
                onPressed: _busy ? null : widget.onCancel,
                child: const Text('Vazgeç'),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dar (280 px) pencereye sığan sade iletişim kutusu.
Future<void> _m2yShowDialog(BuildContext context, String title,
    Widget Function(VoidCallback close) body) {
  // Hızlı Destek'te kaydırma yok: diyalog sığsın diye pencere geçici büyütülür.
  return m2yPencereBuyutup<void>(
      const Size(420, 420), () => _m2yShowDialogGoster(context, title, body));
}

Future<void> _m2yShowDialogGoster(BuildContext context, String title,
    Widget Function(VoidCallback close) body) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: !bind.isIncomingOnly(),
      insetPadding: const EdgeInsets.all(8),
      titlePadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      contentPadding: const EdgeInsets.all(12),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: body(() => Navigator.of(ctx).pop()),
      ),
    ),
  );
}

void m2yChangeFixedPasswordDialog(BuildContext context) {
  _m2yShowDialog(
    context,
    'Sabit parolayı değiştir',
    (close) => M2yFixedPasswordForm(
      showAccessToggle: false,
      onCancel: close,
      onSaved: () {
        close();
        showToast('Sabit parola değiştirildi');
      },
    ),
  );
}

void m2yLogoutConfirmDialog(BuildContext context) {
  _m2yShowDialog(
    context,
    'Oturumu kapat',
    (close) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Oturum kapatılınca danışmanınız bu bilgisayara '
            'bağlanamaz. Yeniden kullanmak için e-postanızla giriş yapmanız '
            'gerekir.'),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton(onPressed: close, child: const Text('Vazgeç')),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              close();
              M2yAuth.instance.logout();
            },
            child: const Text('Oturumu kapat'),
          ),
        ]),
      ],
    ),
  );
}

/// Hızlı Destek ana penceresinde (ayarlar kapalı) ID satırındaki küçük menü.
class M2yQuickSupportMenu extends StatelessWidget {
  const M2yQuickSupportMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.titleLarge?.color;
    return PopupMenuButton<String>(
      tooltip: 'Seçenekler',
      padding: EdgeInsets.zero,
      // `child` (ikon değil): 25 px yüksekliğindeki ID satırına sığar.
      child: Icon(Icons.more_vert_outlined,
          size: 20, color: textColor?.withOpacity(0.5)),
      onSelected: (v) async {
        switch (v) {
          case 'password':
            m2yChangeFixedPasswordDialog(context);
            break;
          case 'access':
            final accessOn = M2yAuth.instance.permanentAccessOn;
            await M2yAuth.instance.setPermanentAccess(!accessOn);
            showToast(accessOn
                ? 'Sürekli erişim kapatıldı: yalnızca tek kullanımlık parola geçerli'
                : 'Sürekli erişim açıldı');
            break;
          case 'logout':
            m2yLogoutConfirmDialog(context);
            break;
        }
      },
      itemBuilder: (_) => [
        // Durum her açılışta yeniden okunur.
        const PopupMenuItem(value: 'password', child: Text('Sabit parolayı değiştir')),
        PopupMenuItem(
            value: 'access',
            child: Text(M2yAuth.instance.permanentAccessOn
                ? 'Sürekli erişimi kapat' : 'Sürekli erişimi aç')),
        const PopupMenuItem(value: 'logout', child: Text('Oturumu kapat')),
      ],
    );
  }
}
