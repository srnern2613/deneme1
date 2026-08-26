// ==============================================================
// DOSYA ADI: lib/streak_freeze_service.dart
// AÇIKLAMA: Seri Kalkanı ve Günlük Giriş/Streak Takip Motoru
// ==============================================================

import 'package:shared_preferences/shared_preferences.dart';

class StreakFreezeService {
  static final StreakFreezeService instance = StreakFreezeService._init();
  StreakFreezeService._init();

  // Uygulama açıldığında veya okuma bittiğinde seri kontrolü yapılır
  Future<Map<String, dynamic>> checkAndUpdateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = _getDateKey(DateTime.now());
    final lastActiveStr = prefs.getString('stats_last_active_date');
    
    int streakDays = prefs.getInt('current_streak_days') ?? 1;
    bool hasFreezeShield = prefs.getBool('has_freeze_shield') ?? true; // Varsayılan 1 kalkan hediye
    bool shieldUsedToday = false;

    if (lastActiveStr != null) {
      final lastActiveDate = DateTime.tryParse(lastActiveStr) ?? DateTime.now();
      final difference = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
          .difference(DateTime(lastActiveDate.year, lastActiveDate.month, lastActiveDate.day))
          .inDays;

      if (difference == 0) {
        // Bugün zaten girmiş, seri aynı kalır
      } else if (difference == 1) {
        // Dün girmiş, seri 1 artar!
        streakDays += 1;
        await prefs.setInt('current_streak_days', streakDays);
      } else if (difference > 1) {
        // Arada 1 günden fazla boşluk var! Kalkan var mı?
        if (hasFreezeShield) {
          // Kalkan seriyi kurtardı!
          hasFreezeShield = false;
          shieldUsedToday = true;
          await prefs.setBool('has_freeze_shield', false);
        } else {
          // Kalkan yok, seri maalesef sıfırlanır :(
          streakDays = 1;
          await prefs.setInt('current_streak_days', 1);
        }
      }
    }

    // Bugünün tarihini son aktif tarih olarak kaydet
    await prefs.setString('stats_last_active_date', todayStr);

    return {
      'streakDays': streakDays,
      'hasFreezeShield': hasFreezeShield,
      'shieldUsedToday': shieldUsedToday,
    };
  }

  // Kalkanı yeniden doldurma görevi (Örn: 20 sayfa okuyunca kazanılır)
  Future<void> refuelShield() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_freeze_shield', true);
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}