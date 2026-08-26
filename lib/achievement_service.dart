// ==============================================================
// achievement_service.dart
// --------------------------------------------------------------
// BAŞARI VE ROZET KİLİT KONTROL MOTORU
// ==============================================================

import 'package:shared_preferences/shared_preferences.dart';

class AchievementService {
  static final AchievementService instance = AchievementService._init();
  AchievementService._init();

  // Okuma veya kelime ekleme sonrasında tetiklenir, yeni açılan rozetleri döndürür
  Future<List<String>> checkAndUnlockAchievements({
    required int totalPagesRead,
    required int totalFlashcards,
    required int totalReadMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> newlyUnlocked = [];

    // Örnek kontrol mantığı: 10 sayfa barajı
    bool isPageMonsterUnlocked = prefs.getBool('badge_page_monster') ?? false;
    if (totalPagesRead >= 10 && !isPageMonsterUnlocked) {
      await prefs.setBool('badge_page_monster', true);
      newlyUnlocked.add('📖 Sayfa Canavarı: 10+ Sayfa Okundu!');
    }

    // İlk kelime kartı rozeti
    bool isFirstCardUnlocked = prefs.getBool('badge_first_card') ?? false;
    if (totalFlashcards > 0 && !isFirstCardUnlocked) {
      await prefs.setBool('badge_first_card', true);
      newlyUnlocked.add('⭐ İlk Kıvılcım: İlk Kelime Kartı Kaydedildi!');
    }

    return newlyUnlocked;
  }
}