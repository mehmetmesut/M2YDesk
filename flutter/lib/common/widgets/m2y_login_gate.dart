// M2YDesk: zorunlu oturum açma ekranı (ana pencere içeriği yerine gösterilir).
// Ekran 1: e-posta + KVKK onayı → kod gönder (+ Google ile giriş).
// Ekran 2: 6 haneli kod, yeniden gönder (60 sn), e-postayı değiştir.
// Ekran 3: sabit parola (yoksa; atlanamaz).
// M2YDesk: Türkçe sabit metin (çeviri anahtarı kullanılmaz).
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/common/widgets/m2y_auth.dart';
import 'package:flutter_hbb/common/widgets/m2y_destek.dart';
import 'package:flutter_hbb/common/widgets/m2y_pencere.dart';
import 'package:flutter_hbb/common/widgets/m2y_fixed_password.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

const _kResendSeconds = 60;

/// Harici giriş seçeneklerini (Google…) sunucudan okur; testte sahtesi takılabilir.
@visibleForTesting
Future<List<dynamic>> Function() m2yOidcYukleyici = UserModel.queryOidcLoginOptions;
const _kFullWidth = 380.0;

/// Hızlı Destek giriş/sabit parola kutusunun en az içerik yüksekliği: giriş ve sabit parola
/// ekranları aynı pencere ölçüsünü kullanır (kullanıcı isteği; ölçü sabit parola ekranından alındı).
const double kM2yQsGirisYuksekligi = 281.0;

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
    final theme = Theme.of(context);
    // Tam sürümde ortalanmış, çerçeveli kutu; Hızlı Destek'te pencereyi dolduran sade içerik.
    final framed = Container(
      key: _contentKey,
      // Dar ekranlarda (telefon) kutu ekrana sığacak kadar daralır (380 dp'yi aşmaz; 24 dp kenar boşluğu).
      width: _qs
          ? m2yQsIcerikGenisligi()
          : math.min(_kFullWidth, MediaQuery.of(context).size.width - 48),
      padding: _qs
          ? const EdgeInsets.all(12)
          : EdgeInsets.all(MediaQuery.of(context).size.width < 420 ? 18 : 28),
      constraints: _qs ? const BoxConstraints(minHeight: kM2yQsGirisYuksekligi) : null,
      decoration: _qs
          ? null
          : BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor),
            ),
      child: content,
    );
    // Hızlı Destek penceresi içeriğe göre boyutlanır: adım değişince (e-posta → kod → sabit parola)
    // ya da hata iletisi çıkınca içerik yüksekliği değişir; yalnız dış build'e güvenmek pencerenin
    // eski boyutta kalmasına ("Kaydet" düğmesi kesiliyordu) yol açıyordu.
    final sized = _qs
        ? M2yBoyutIzleyici(onChanged: _fitWindow, child: framed)
        : framed;
    final page = Container(
      color: theme.colorScheme.background,
      alignment: _qs ? Alignment.topLeft : Alignment.center,
      // Hızlı Destek'te kaydırma YOK: pencere içeriğe göre büyür.
      child: _qs
          ? sized
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: sized,
            ),
    );
    return _qs ? m2yCompact(context, page) : page;
  }
}

/// Hızlı Destek'in dar penceresi için sıkı görünüm: küçük başlık, ikon, giriş alanı ve düğmeler.
Widget m2yCompact(BuildContext context, Widget child) {
  // Yazı ölçeği pencere genişliğine göre genel olarak ayarlanır (main.dart m2yTextScale);
  // ikon/düğme/alan yoğunluğu m2yCompactDialog ile aynıdır.
  return m2yCompactDialog(
    context,
    Builder(builder: (context) {
      final t = Theme.of(context);
      // Hızlı Destek için SABİT yazı/ikon ölçeği (ekranlar arası tutarlı; genel ölçek 0.80 üstüne biner):
      // başlık 17, giriş/düğme 14, gövde 12.5, etiket 12, simge 16 (06.10: kullanıcı isteğiyle +1 pt).
      TextStyle? boyut(TextStyle? s, double px, [FontWeight? w]) =>
          s?.copyWith(fontSize: px, fontWeight: w);
      return Theme(
        data: t.copyWith(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          iconTheme: t.iconTheme.copyWith(size: 16),
          textTheme: t.textTheme.copyWith(
            titleLarge: boyut(t.textTheme.titleLarge, 17, FontWeight.w600),
            titleMedium: boyut(t.textTheme.titleMedium, 14),
            bodyLarge: boyut(t.textTheme.bodyLarge, 14),
            bodyMedium: boyut(t.textTheme.bodyMedium, 12.5),
            bodySmall: boyut(t.textTheme.bodySmall, 12.5),
            labelLarge: boyut(t.textTheme.labelLarge, 14),
          ),
          inputDecorationTheme: t.inputDecorationTheme.copyWith(
            labelStyle: boyut(t.textTheme.bodyMedium, 13),
            floatingLabelStyle: boyut(t.textTheme.bodySmall, 12),
            hintStyle: boyut(t.textTheme.bodyMedium, 13),
          ),
          checkboxTheme: const CheckboxThemeData(
            visualDensity: VisualDensity(horizontal: -4, vertical: -4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        child: child,
      );
    }),
  );
}

Widget _section(
    BuildContext context, String title, String subtitle, Widget child) {
  // Tam sürümde başlık ve açıklama ortalanır (kutu simetrik görünür).
  final align =
      M2yAuth.instance.isQuickSupport ? TextAlign.start : TextAlign.center;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title,
          textAlign: align,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(subtitle,
          textAlign: align, style: Theme.of(context).textTheme.bodySmall),
      SizedBox(height: M2yAuth.instance.isQuickSupport ? 8 : 16),
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
      _oidcOptions.value = await m2yOidcYukleyici();
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
    final qs = M2yAuth.instance.isQuickSupport;
    final veya = Row(children: [
      const Expanded(child: Divider()),
      Text('veya', style: small).marginSymmetric(horizontal: 8),
      const Expanded(child: Divider()),
    ]);
    // Hızlı Destek: iki seçenek — yalnız Google ve e-posta kodu (Google üstte, tek dokunuş).
    // Tam sürüm: e-posta üstte, harici seçenekler (Google, Webauth) altta yan yana.
    final oidc = Obx(() {
      final options = qs
          ? _oidcOptions
              .where((e) => (e['name'] ?? '').toString().toLowerCase() == 'google')
              .toList()
          : _oidcOptions.toList();
      if (options.isEmpty) return const Offstage();
      final buttons = M2yOidcButtons(
        options: options,
        curOP: _curOP,
        onLogin: _onOidcLogin,
        tamGenislik: qs,
        olcek: qs ? 0.85 : 1.0,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: qs
            ? [buttons, const SizedBox(height: 6), veya, const SizedBox(height: 6)]
            : [const SizedBox(height: 12), veya, const SizedBox(height: 8), buttons],
      );
    });
    final eposta = Column(
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
              // Simge yok (tüm sürümlerde; kullanıcı kuralı: kutu gibi görünüyordu), alan sade kalır.
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
          SizedBox(height: qs ? 0 : 4),
          // KVKK bağlantısı rıza metninin ÜSTÜNDE (kullanıcı isteği, tüm sürümler): önce oku, sonra onayla.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => launchUrl(Uri.parse(kM2yKvkkUrl),
                  mode: LaunchMode.externalApplication),
              child: const Text('KVKK aydınlatma metni'),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Küçük onay kutusu (tüm sürümlerde; kullanıcı kuralı); FittedBox yerleşim boyutunu da küçültür.
              SizedBox(
                width: 22,
                height: 22,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Checkbox(
                    value: _consent,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _consent = v ?? false),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  qs
                      ? 'Aydınlatma metnini okudum; e-posta adresimin '
                          'işlenmesine açık rıza veriyorum.'
                      : 'Aydınlatma metnini okudum; e-posta adresimin oturum açma '
                          'amacıyla işlenmesine açık rıza veriyorum.',
                  style: small,
                ).marginOnly(left: 6, top: 3),
              ),
            ],
          ),
          SizedBox(height: qs ? 6 : 12),
          if (_busy) const LinearProgressIndicator(),
          SizedBox(height: qs ? 2 : 4),
          ElevatedButton(
            onPressed: _busy ? null : _sendCode,
            child: const Text('Doğrulama kodu gönder'),
          ),
      ],
    );
    return _section(
      context,
      'Oturum açın',
      qs
          ? 'Google ya da e-posta koduyla giriş yapın.'
          : 'Devam etmek için e-posta adresinize gönderilecek doğrulama kodunu '
              'girmeniz gerekir.',
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: qs ? [oidc, eposta] : [eposta, oidc],
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

/// Harici giriş düğmeleri (Google, Webauth…) tek satırda, ortalı ve eşit genişlikte;
/// sığmazsa alt satıra sarar. Tek seçenek varsa standart genişlikte ortalanır.
class M2yOidcButtons extends StatelessWidget {
  /// Sunucudan gelen seçenekler: her biri `{name, icon}` içeren harita.
  final List options;
  final RxString curOP;
  final Function(Map<String, dynamic>) onLogin;

  /// Kutunun tüm genişliğini kullanır (Hızlı Destek'te tek Google düğmesi).
  final bool tamGenislik;

  /// Düğme (genişlik, yükseklik, simge, yazı) ölçeği; Hızlı Destek'te 0.85 (kullanıcı isteği: %15 küçük).
  final double olcek;

  const M2yOidcButtons({
    Key? key,
    required this.options,
    required this.curOP,
    required this.onLogin,
    this.tamGenislik = false,
    this.olcek = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const gap = 8.0, minWidth = 130.0, maxWidth = 200.0;
    return LayoutBuilder(builder: (context, c) {
      final n = options.length;
      final w = tamGenislik && n == 1
          ? c.maxWidth * olcek
          : n <= 1
              ? maxWidth
              : ((c.maxWidth - gap * (n - 1)) / n).clamp(minWidth, maxWidth);
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: 6,
        children: options.map((e) {
          final op = (e['name'] ?? '').toString();
          return SizedBox(
            width: w,
            child: WidgetOP(
              config: ConfigOP(op: op, icon: e['icon']),
              curOP: curOP,
              cbLogin: onLogin,
              width: w,
              olcek: olcek,
              label: _label(op),
            ),
          );
        }).toList(),
      );
    });
  }

  /// Sabit Türkçe düğme metni (çeviri anahtarı kullanılmaz; yerel testte FFI gerekmez).
  static String _label(String op) {
    switch (op.toLowerCase()) {
      case 'google':
        return 'Google ile giriş yap';
      case 'webauth':
        return 'Webauth ile devam et';
      default:
        final ad = op.isEmpty ? '' : op[0].toUpperCase() + op.substring(1);
        return '$ad ile devam et'.trim();
    }
  }
}
