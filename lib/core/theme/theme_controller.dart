// ============================================================================
// DOSYA ADI: lib/core/theme/theme_controller.dart
// AÇIKLAMA: UI/UX Düzeltme Listesi — T-6: Karanlık (Zindan) / Aydınlık
// (Parşömen) tema anahtarının tek gerçek kaynağı. Tercih shared_preferences'ta
// kalıcı, sistem teması TAKİP EDİLMEZ (kullanıcı kararı — sadece iki seçenek,
// elle geçiş). Varsayılan: Karanlık.
//
// Kullanım: main.dart açılışta ThemeController.instance.init() ile tercihi
// yükler (bu, ilk karenin doğru temayla çizilmesini sağlar — T-6'daki "açılışta
// tema sıçraması olmaz" şartı). Ekranlar `ThemeController.instance.current`
// (DraconicTheme) veya doğrudan `Theme.of(context).extension<DraconicTheme>()`
// üzerinden okur; ikisi de MaterialApp'in extensions listesiyle senkron.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'draconic_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_is_dark';

  bool _isDark = true; // Varsayılan: Karanlık (Zindan)
  bool _initialized = false;

  bool get isDark => _isDark;
  bool get initialized => _initialized;

  DraconicTheme get current =>
      _isDark ? DraconicTheme.highEnd() : DraconicTheme.parchment();

  /// main.dart'ta runApp'ten ÖNCE çağrılmalı — ilk kare doğru temayla
  /// çizilsin diye (T-6: "açılışta tema sıçraması olmaz").
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      _isDark = true;
    }
    _initialized = true;
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // Kalıcılık başarısız olsa bile mevcut oturumda tema değişikliği geçerli kalır.
    }
  }

  Future<void> toggle() => setDark(!_isDark);
}
