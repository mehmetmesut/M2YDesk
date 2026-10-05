// M2YDesk: zorunlu oturum açma ekranı (ana pencere içeriği yerine gösterilir).
// Ekran 1: e-posta + KVKK onayı → kod gönder (+ Google ile giriş).
// Ekran 2: 6 haneli kod, yeniden gönder (60 sn), e-postayı değiştir.
// Ekran 3: sabit parola (yoksa; atlanamaz).
// M2YDesk: Türkçe sabit metin (çeviri anahtarı kullanılmaz).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/common/widgets/m2y_auth.dart';
import 'package:flutter_hbb/common/widgets/m2y_fixed_password.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

const _kResendSeconds = 60;
const _kQuickSupportWidth = 360.0;
const _kFullWidth = 380.0;

class M2yAuthGate extends StatefulWidget {
  const M2yAuthGate({Key? key}) : super(key: key);

  @override
  State<M2yAuthGate> createState() => _M2yAuthGateState();
}

class _M2yAuthGateState extends State<M2yAuthGate> {
  final _contentKey = GlobalKey();

  bool get _qs => M2yAuth.instance.isQuickSupport;

  /// Hızlı Destek penceresi içeriğe göre boyutlanır (ana sayfadaki gibi).
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
    final content = Obx(() {
      switch (M2yAuth.instance.stage.value) {
        case M2yAuthStage.checking:
        case M2yAuthStage.ready:
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        case M2yAuthStage.login:
          return const _M2yLoginForm();
        case M2yAuthStage.setPassword:
          return _section(
            context,
            'Sabit parola belirleyin',
            'Danışmanınızın bağlanabilmesi için 6 haneli, yalnızca rakamlardan '
                'oluşan bir sabit parola belirleyin. Bu adım atlanamaz.',
            M2yFixedPasswordForm(
              showAccessToggle: _qs,
              onSaved: M2yAuth.instance.onFixedPasswordSaved,
            ),
          );
      }
    });
    final framed = Container(
      key: _contentKey,
      width: _qs ? _kQuickSupportWidth : null,
      padding: const EdgeInsets.all(16),
      child: content,
    );
    final page = Container(
      color: Theme.of(context).colorScheme.background,
      alignment: _qs ? Alignment.topLeft : Alignment.center,
      child: SingleChildScrollView(
        child: _qs
            ? framed
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kFullWidth),
                child: framed,
              ),
      ),
    );
    return _qs ? m2yCompact(context, page) : page;
  }
}

/// Hızlı Destek'in dar penceresi için sıkı görünüm: küçük yazı, yoğun giriş alanları ve düğmeler.
Widget m2yCompact(BuildContext context, Widget child) {
  // Yazı ölçeği pencere genişliğine göre genel olarak ayarlanır (main.dart m2yTextScale);
  // burada yalnız yoğunluk: sıkı giriş alanları ve düğmeler, biraz küçük başlıklar.
  final t = Theme.of(context);
  return Theme(
    data: t.copyWith(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      inputDecorationTheme: t.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
      textTheme: t.textTheme.copyWith(
        titleLarge: t.textTheme.titleLarge?.copyWith(fontSize: 18),
        titleMedium: t.textTheme.titleMedium?.copyWith(fontSize: 15),
      ),
    ),
    child: child,
  );
}

Widget _section(
    BuildContext context, String title, String subtitle, Widget child) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _M2yLoginForm extends StatefulWidget {
  const _M2yLoginForm({Key? key}) : super(key: key);

  @override
  State<_M2yLoginForm> createState() => _M2yLoginFormState();
}

class _M2yLoginFormState extends State<_M2yLoginForm> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _curOP = ''.obs;
  final _oidcOptions = [].obs;
  String _remembered = '';
  String _sentTo = '';
  bool _consent = false;
  bool _codeStep = false;
  bool _busy = false;
  String? _emailError;
  String? _codeError;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remembered = bind.mainGetLocalOption(key: kM2yOptLastEmail);
    _email.text = _remembered;
    // Hatırlanan e-posta daha önce verilmiş açık rızayı gösterir.
    _consent = _remembered.isNotEmpty;
    Future.microtask(() async {
      _oidcOptions.value = await UserModel.queryOidcLoginOptions();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _kResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  String _sendError(RequestException e) {
    if (e.cause.isNotEmpty) return e.cause;
    switch (e.statusCode) {
      case 0:
        return 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
      case 400:
        return 'Geçerli bir e-posta adresi girin.';
      case 429:
        return 'Çok fazla deneme yapıldı. Lütfen biraz sonra yeniden deneyin.';
      case 503:
        return 'E-posta gönderimi şu an kullanılamıyor. Lütfen daha sonra deneyin.';
      default:
        return 'Kod gönderilemedi (HTTP ${e.statusCode}).';
    }
  }

  String _verifyError(RequestException e) {
    if (e.cause.isNotEmpty) return e.cause;
    switch (e.statusCode) {
      case 0:
        return 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
      case 400:
        return 'Kod hatalı ya da süresi dolmuş. Yeni kod isteyebilirsiniz.';
      case 403:
        return 'Hesabınız pasif. Danışmanınızla iletişime geçin.';
      case 429:
        return 'Çok fazla deneme yapıldı. Lütfen biraz sonra yeniden deneyin.';
      case -1:
        return 'Sunucudan beklenmeyen yanıt alındı.';
      default:
        return 'Doğrulama başarısız (HTTP ${e.statusCode}).';
    }
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    final email = m2yNormalizeEmail(_email.text);
    String? err;
    if (!m2yIsValidEmail(email)) {
      err = 'Geçerli bir e-posta adresi girin.';
    } else if (!_consent) {
      err = 'Devam etmek için açık rıza kutusunu işaretleyin.';
    }
    if (err != null) {
      setState(() => _emailError = err);
      return;
    }
    setState(() {
      _email.text = email;
      _emailError = null;
      _busy = true;
    });
    try {
      await gFFI.userModel.m2ySendCode(email);
      if (!mounted) return;
      _sentTo = email;
      _code.clear();
      _codeError = null;
      _codeStep = true;
      _startCooldown();
    } on RequestException catch (e) {
      _emailError = _sendError(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resend() async {
    if (_busy || _cooldown > 0) return;
    setState(() => _busy = true);
    try {
      await gFFI.userModel.m2ySendCode(_sentTo);
      _codeError = null;
      if (mounted) _startCooldown();
      showToast('Yeni kod gönderildi');
    } on RequestException catch (e) {
      _codeError = _sendError(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (!m2yIsCode(code)) {
      setState(() => _codeError = 'Kod 6 haneli rakamlardan oluşmalıdır.');
      return;
    }
    setState(() {
      _codeError = null;
      _busy = true;
    });
    try {
      await gFFI.userModel.m2yVerifyCode(_sentTo, code);
      await bind.mainSetLocalOption(key: kM2yOptLastEmail, value: _sentTo);
      await M2yAuth.instance.onLoggedIn();
      return;
    } on RequestException catch (e) {
      _codeError = _verifyError(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _useOtherEmail() {
    setState(() {
      _email.clear();
      _remembered = '';
      _consent = false;
      _emailError = null;
    });
  }

  Future<void> _forgetEmail() async {
    await bind.mainSetLocalOption(key: kM2yOptLastEmail, value: '');
    _useOtherEmail();
    showToast('E-posta adresiniz bu cihazdan silindi');
  }

  void _changeEmail() {
    _timer?.cancel();
    setState(() {
      _codeStep = false;
      _cooldown = 0;
      _codeError = null;
    });
  }

  Future<void> _onOidcLogin(Map<String, dynamic> authBody) async {
    // access_token Rust tarafında (remember_me) zaten yazıldı.
    try {
      final resp = gFFI.userModel.getLoginResponseFromAuthBody(authBody);
      if (resp.type == HttpType.kAuthResTypeToken &&
          resp.access_token != null) {
        await M2yAuth.instance.onLoggedIn();
        return;
      }
    } catch (e) {
      debugPrint('M2YDesk: Google girişi yanıtı çözülemedi: $e');
    }
    if (mounted) {
      setState(() => _emailError = 'Google ile giriş tamamlanamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _codeStep ? _buildCodeStep(context) : _buildEmailStep(context);
  }

  Widget _buildEmailStep(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return _section(
      context,
      'Oturum açın',
      'Devam etmek için e-posta adresinize gönderilecek doğrulama kodunu '
          'girmeniz gerekir.',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            autofocus: _remembered.isEmpty,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'E-posta',
              prefixIcon: const Icon(Icons.email_outlined),
              errorText: _emailError,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _sendCode(),
          ).workaroundFreezeLinuxMint(),
          if (_remembered.isNotEmpty)
            Wrap(children: [
              TextButton(
                onPressed: _busy ? null : _useOtherEmail,
                child: const Text('Başka e-posta kullan'),
              ),
              TextButton(
                onPressed: _busy ? null : _forgetEmail,
                child: const Text('Bu cihazdan e-postamı unut'),
              ),
            ]),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _consent,
                onChanged:
                    _busy ? null : (v) => setState(() => _consent = v ?? false),
              ),
              Expanded(
                child: Text(
                  'Aydınlatma metnini okudum; e-posta adresimin oturum açma '
                  'amacıyla işlenmesine açık rıza veriyorum.',
                  style: small,
                ).marginOnly(top: 6),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => launchUrl(Uri.parse(kM2yKvkkUrl),
                  mode: LaunchMode.externalApplication),
              child: const Text('KVKK aydınlatma metni'),
            ),
          ),
          const SizedBox(height: 8),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _busy ? null : _sendCode,
              child: const Text('Doğrulama kodu gönder'),
            ),
          ),
          Obx(() => _oidcOptions.isEmpty
              ? const Offstage()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    const Text('veya'),
                    const SizedBox(height: 8),
                    ..._oidcOptions.map((e) {
                      final op = (e['name'] ?? '').toString();
                      return WidgetOP(
                        config: ConfigOP(op: op, icon: e['icon']),
                        curOP: _curOP,
                        cbLogin: _onOidcLogin,
                        label: op.toLowerCase() == 'google'
                            ? 'Google ile giriş yap'
                            : null,
                      ).marginOnly(bottom: 6);
                    }),
                  ],
                )),
        ],
      ),
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return _section(
      context,
      'Doğrulama kodu',
      '$_sentTo adresine 6 haneli bir kod gönderdik. Kod 10 dakika geçerlidir.',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            autofocus: true,
            enabled: !_busy,
            maxLength: kM2yCodeLength,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, letterSpacing: 4),
            decoration: InputDecoration(
              labelText: 'Kod',
              errorText: _codeError,
              errorMaxLines: 3,
            ),
            onChanged: (v) {
              if (m2yIsCode(v.trim())) _verify();
            },
            onSubmitted: (_) => _verify(),
          ).workaroundFreezeLinuxMint(),
          Text('E-posta gelmediyse spam (gereksiz) klasörünü kontrol edin.',
              style: small),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: (_busy || _cooldown > 0) ? null : _resend,
              child: Text(_cooldown > 0
                  ? 'Kodu yeniden gönder ($_cooldown sn)'
                  : 'Kodu yeniden gönder'),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          // Birincil sağda, geri dönüş solda.
          Row(children: [
            OutlinedButton(
              onPressed: _busy ? null : _changeEmail,
              child: const Text('E-postayı değiştir'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _busy ? null : _verify,
              child: const Text('Doğrula'),
            ),
          ]),
        ],
      ),
    );
  }
}
