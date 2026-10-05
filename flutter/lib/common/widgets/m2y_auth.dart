// M2YDesk: zorunlu e-posta + kod oturumu — durum denetleyicisi.
//
// Akış: açılış → (oturum yok/geçersiz) giriş ekranı → (sabit parola yoksa)
// sabit parola ekranı → ana pencere. Oturum yokken bağlantı kapısı kapalıdır
// (`stop-service`; bkz. `ui_interface::m2y_set_connection_gate`).
// Tasarım: docs/eposta-kod-girisi.md.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:get/get.dart';

enum M2yAuthStage { checking, login, setPassword, ready }

const kM2yOptLastEmail = 'm2y-last-email';
const kM2yOptAutostart = 'm2y-autostart';
const kM2yKvkkUrl = 'https://desk.mehmetmesut.com/#kvkk';
const kM2yCodeLength = 6;

final _fixedPasswordRe = RegExp(r'^[0-9]{6}$');
final _codeRe = RegExp(r'^[0-9]{6}$');
final _emailRe = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');

/// Sabit parola kuralı: tam 6 hane, yalnızca rakam.
bool m2yIsFixedPassword(String s) => _fixedPasswordRe.hasMatch(s);

bool m2yIsCode(String s) => _codeRe.hasMatch(s);

/// E-posta normalizasyonu: kırp + küçük harf.
String m2yNormalizeEmail(String s) => s.trim().toLowerCase();

/// İstemci tarafı biçim denetimi (sunucu ayrıca doğrular; yalnızca ASCII).
bool m2yIsValidEmail(String s) => s.length <= 254 && _emailRe.hasMatch(s);

class M2yAuth {
  M2yAuth._();
  static final M2yAuth instance = M2yAuth._();

  /// Arka planda oturumun yeniden doğrulanma aralığı.
  static const _recheckInterval = Duration(minutes: 30);

  final stage = M2yAuthStage.checking.obs;
  Timer? _timer;
  bool _started = false;

  bool get isReady => stage.value == M2yAuthStage.ready;

  /// Hızlı Destek (yalnızca gelen bağlantı) sürümü mü?
  bool get isQuickSupport => bind.isIncomingOnly();

  /// Ana pencere açılışında bir kez çağrılır.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    // Çıkış ya da 401 (UserModel.reset) → giriş ekranı.
    ever<String>(gFFI.userModel.userName, (name) {
      final active = stage.value == M2yAuthStage.ready ||
          stage.value == M2yAuthStage.setPassword;
      if (name.isEmpty && active) unawaited(_toLogin());
    });
    final token = bind.mainGetLocalOption(key: 'access_token');
    if (token.isEmpty || bind.mainM2YAuthExpired()) {
      await _toLogin(clearSession: token.isNotEmpty);
    } else {
      // 7 günlük tolerans içinde: hemen aç, sunucuyu arka planda doğrula.
      final verify = _recheckSession();
      await _afterLogin();
      await verify;
    }
    _timer = Timer.periodic(_recheckInterval, (_) => _recheckSession());
  }

  Future<void> _recheckSession() async {
    if (stage.value == M2yAuthStage.login) return;
    final status = await gFFI.userModel.m2yVerifySession();
    if (status == 200) return; // süre sıfırlandı
    if (status == 401) {
      // UserModel.reset oturumu sildi.
      if (stage.value != M2yAuthStage.login) await _toLogin();
      return;
    }
    if (bind.mainM2YAuthExpired()) {
      debugPrint('M2YDesk: 7 gündür sunucuya ulaşılamadı, oturum kapatılıyor');
      await _toLogin(clearSession: true);
    }
  }

  Future<void> _toLogin({bool clearSession = false}) async {
    stage.value = M2yAuthStage.login;
    bind.mainM2YSetConnectionGate(closed: true);
    if (clearSession) await gFFI.userModel.reset(resetOther: true);
  }

  /// Kod ya da Google ile oturum açıldıktan sonra.
  Future<void> onLoggedIn() async {
    bind.mainM2YMarkAuthOk();
    await _afterLogin();
  }

  Future<void> _afterLogin() async {
    final hasPassword =
        await bind.mainGetCommon(key: 'permanent-password-set') == 'true';
    // Bu arada sunucu oturumu reddetmiş olabilir (401).
    if (!_hasToken()) return _toLogin();
    if (!hasPassword) {
      stage.value = M2yAuthStage.setPassword;
      return;
    }
    _open();
  }

  void onFixedPasswordSaved() => _open();

  bool _hasToken() => bind.mainGetLocalOption(key: 'access_token').isNotEmpty;

  void _open() {
    if (!_hasToken()) {
      unawaited(_toLogin());
      return;
    }
    bind.mainM2YSetConnectionGate(closed: false);
    stage.value = M2yAuthStage.ready;
  }

  Future<void> logout() async {
    await gFFI.userModel.logOut();
    await _toLogin();
  }

  /// Hızlı Destek "Sürekli erişim": açıkken geçici + kalıcı parola ve Windows
  /// açılışında otomatik başlatma; kapalıyken yalnızca tek kullanımlık parola.
  bool get permanentAccessOn =>
      bind.mainGetOptionSync(key: kOptionVerificationMethod) !=
      kUseTemporaryPassword;

  Future<void> setPermanentAccess(bool on) async {
    await bind.mainSetOption(
        key: kOptionVerificationMethod,
        value: on ? kUseBothPasswords : kUseTemporaryPassword);
    await bind.mainSetLocalOption(key: kM2yOptAutostart, value: on ? '' : 'N');
  }

  @visibleForTesting
  void dispose() => _timer?.cancel();
}
