// M2YDesk: sol panelin altındaki üyelik kartı (yalnız tam M2YDesk).
// M2YDesk: Türkçe sabit metin (çeviri anahtarı kullanılmaz).
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/m2y_auth.dart';
import 'package:flutter_hbb/common/widgets/m2y_destek.dart';
import 'package:get/get.dart';

class M2yUyelikKarti extends StatefulWidget {
  const M2yUyelikKarti({Key? key}) : super(key: key);

  @override
  State<M2yUyelikKarti> createState() => _M2yUyelikKartiState();
}

class _M2yUyelikKartiState extends State<M2yUyelikKarti> {
  String _email = '';
  String _kurulus = '';
  bool _isAdmin = false;
  bool _isDanisman = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await M2yApi.currentUser();
    if (user == null || !mounted) return;
    final email = (user['email'] ?? '').toString();
    setState(() {
      _email = email;
      _kurulus = (user['m2y_kurulus'] ?? '').toString();
      _isAdmin = user['is_admin'] == true;
      // Yetkili danışman yalnız sistem sahibidir (sunucuda da aynı kural; m2y-api M2ySistemSahibiEposta).
      _isDanisman = m2yNormalizeEmail(email) == kM2ySistemSahibiEposta;
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => m2yCompactDialog(ctx, AlertDialog(
        title: const Text('Çıkış yap'),
        content: const Text(
            'Çıkış yapılırsa bağlantı kapısı kapanır ve yeniden giriş gerekir.'),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çıkış yap'),
          ),
        ],
      )),
    );
    if (ok == true) await M2yAuth.instance.logout();
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    return Obx(() {
      final name = gFFI.userModel.userName.value;
      if (name.isEmpty) return const Offstage();
      final display = gFFI.userModel.displayName.value.trim();
      final title = display.isNotEmpty ? display : name;
      // Sol paneldeki diğer öğelerle aynı iç boşluk; rozetler ve çıkış tek satırda.
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: _email.isNotEmpty ? _email : title,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ).marginOnly(right: 6),
            if (_email.isNotEmpty && _email != title)
              Text(_email,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
            if (_kurulus.isNotEmpty)
              Text(_kurulus,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Wrap(spacing: 4, runSpacing: 4, children: [
                  _badge('Üye', MyTheme.accent),
                  if (_isAdmin) _badge('Yönetici', Colors.deepOrange),
                  if (_isDanisman) _badge('Danışman', Colors.amber.shade700),
                ]),
              ),
              IconButton(
                tooltip: 'Çıkış yap',
                onPressed: _confirmLogout,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                iconSize: 16,
                icon: const Icon(Icons.logout),
              ),
            ]),
          ],
        ),
      );
    });
  }
}
