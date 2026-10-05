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
  bool _isYetkili = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await M2yApi.currentUser();
    if (user == null || !mounted) return;
    final admin = user['is_admin'] == true;
    var yetkili = user['m2y_yetkili'] == true;
    if (!admin && !yetkili) {
      // Yetkili danışman bilgisi kullanıcı yanıtında yok: liste ucu yalnız
      // admin/yetkiliye açıktır (200 = yetkili, 403 = değil).
      try {
        yetkili = (await M2yApi.get('/api/m2y/talepler')).statusCode == 200;
      } catch (e) {
        debugPrint('M2YDesk: yetki denetlenemedi: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _email = (user['email'] ?? '').toString();
      _kurulus = (user['m2y_kurulus'] ?? '').toString();
      _isAdmin = admin;
      _isYetkili = yetkili;
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
      ),
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
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (_email.isNotEmpty && _email != title)
              Text(_email,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
            if (_kurulus.isNotEmpty)
              Text(_kurulus,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              _badge('Üye', MyTheme.accent),
              if (_isAdmin)
                _badge('Yönetici', Colors.deepOrange)
              else if (_isYetkili)
                _badge('Yetkili danışman', Colors.teal),
            ]),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _confirmLogout,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Çıkış yap'),
              ),
            ),
          ],
        ),
      );
    });
  }
}
