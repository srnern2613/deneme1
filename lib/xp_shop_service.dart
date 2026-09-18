// ============================================================================
// DOSYA ADI: lib/xp_shop_service.dart
// AÇIKLAMA: Mağaza Ekonomi Servisi, Atomik Rollback Mekanizması, Değer Senkronizasyonu
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// EJDERHA ROTASI V2 — FAZ 1 NOTU:
// Elmas ekonomisi kaldırıldı. Aşağıdaki elmas alanları/metodları
// SİLİNMEDİ — veri modelini ve derlemeyi bozmamak için @Deprecated
// olarak bırakıldı. Yeni kod bunları çağırmamalı; kalan çağrı
// noktaları (shop_screen, library/flashcards/profile/leaderboard
// ekranlarındaki elmas rozetleri) sırayla temizlenecek. "Seri Koruma"
// gibi haklar Faz 2'den itibaren entitlement/PaywallTrigger üzerinden
// (Premium) sunulacak, elmasla satın alma yolu kullanılmayacak.
class XpShopService {
  static final XpShopService instance = XpShopService._init();
  XpShopService._init();

  @Deprecated('Elmas ekonomisi kaldırıldı (Ejderha Rotası V2 — Faz 1). Yeni kod kullanmasın.')
  final ValueNotifier<int> gemsNotifier = ValueNotifier<int>(50);
  final ValueNotifier<int> xpNotifier = ValueNotifier<int>(100);
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    gemsNotifier.value = prefs.getInt('user_gems_balance') ?? 50;
    xpNotifier.value = prefs.getInt('user_total_xp') ?? 100;
    _isInitialized = true;
  }

  Future<int> getTotalXp() async {
    final prefs = await SharedPreferences.getInstance();
    final xp = prefs.getInt('user_total_xp') ?? 100;
    xpNotifier.value = xp;
    return xp;
  }

  @Deprecated('Elmas ekonomisi kaldırıldı (Ejderha Rotası V2 — Faz 1). Yeni kod kullanmasın.')
  Future<int> getGemsBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final gems = prefs.getInt('user_gems_balance') ?? 50;
    gemsNotifier.value = gems;
    return gems;
  }

  Future<int> addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentXp = prefs.getInt('user_total_xp') ?? 100;

    final doubleXpExpiry = prefs.getInt('double_xp_expiry_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    int finalXp = amount;
    if (now < doubleXpExpiry) {
      finalXp *= 2;
    }

    int updatedXp = currentXp + finalXp;
    await prefs.setInt('user_total_xp', updatedXp);
    xpNotifier.value = updatedXp;

    // P0-C: liderlik tablosundaki "SEZON XP" etiketi artık gerçek bir veriye
    // karşılık geliyor — toplam XP'den ayrı, haftalık (Pazar) sıfırlanan
    // kendi sayacı. getSeasonXp() hafta değiştiyse burada otomatik sıfırlar.
    final currentSeasonXp = await getSeasonXp();
    await prefs.setInt('season_xp', currentSeasonXp + finalXp);

    return updatedXp;
  }

  /// Sezon (haftalık) hafta anahtarı — hafta başlangıcı en son geçmiş Pazar.
  /// leaderboard_screen._getRemainingSeasonTime()'daki "Pazar gecesi sıfırlama"
  /// ile aynı sınırı kullanır.
  String _currentSeasonWeekKey() {
    final now = DateTime.now();
    final int daysSinceSunday = now.weekday % 7; // Pazartesi=1 … Pazar=7%7=0
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceSunday));
    return '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  }

  /// P0-C: Sezon XP — toplam XP'den bağımsız, haftalık sıfırlanan sayaç.
  /// Hafta değiştiyse (son yazılan hafta anahtarı güncel haftadan farklıysa)
  /// sayaç 0'a döner ve yeni hafta anahtarı kaydedilir; toplam XP'ye
  /// dokunulmaz.
  Future<int> getSeasonXp() async {
    final prefs = await SharedPreferences.getInstance();
    final storedWeek = prefs.getString('season_xp_week') ?? '';
    final currentWeek = _currentSeasonWeekKey();
    if (storedWeek != currentWeek) {
      await prefs.setString('season_xp_week', currentWeek);
      await prefs.setInt('season_xp', 0);
      return 0;
    }
    return prefs.getInt('season_xp') ?? 0;
  }

  @Deprecated('Elmas ekonomisi kaldırıldı (Ejderha Rotası V2 — Faz 1). Yeni kod kullanmasın.')
  Future<int> addGems(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentGems = prefs.getInt('user_gems_balance') ?? 50;
    int updatedGems = currentGems + amount;
    await prefs.setInt('user_gems_balance', updatedGems);
    gemsNotifier.value = updatedGems;
    return updatedGems;
  }

  /// Doğrudan elmas harcamak yerine basit eksiltmeler için kullanılır.
  @Deprecated('Elmas ekonomisi kaldırıldı (Ejderha Rotası V2 — Faz 1). Yeni kod kullanmasın.')
  Future<bool> spendGems(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentGems = prefs.getInt('user_gems_balance') ?? 50;
    if (currentGems >= amount) {
      final updated = currentGems - amount;
      await prefs.setInt('user_gems_balance', updated);
      gemsNotifier.value = updated;
      return true;
    }
    return false;
  }

  /// ATOMİK SATIN ALIM VE ROLLBACK MEKANİZMASI
  /// Satın alma işlemi sırasında SharedPreferences yazma hatası oluşursa,
  /// düşülen elmas miktarı kullanıcıya otomatik iade edilir.
  @Deprecated('Elmas ekonomisi kaldırıldı (Ejderha Rotası V2 — Faz 1). Satın alma akışı Faz 2\'de RevenueCat/PaywallTrigger\'a taşınacak.')
  Future<bool> buyItemWithRollback(String itemId, int price, {String? categoryToEquip}) async {
    final prefs = await SharedPreferences.getInstance();
    int currentGems = prefs.getInt('user_gems_balance') ?? 50;

    if (currentGems < price) return false;

    // 1. Adım: Elması Düş (Optimistic Update)
    int updatedGems = currentGems - price;
    await prefs.setInt('user_gems_balance', updatedGems);
    gemsNotifier.value = updatedGems;

    try {
      // 2. Adım: Eşyayı Kaydet
      await prefs.setBool('item_owned_$itemId', true);
      await prefs.setBool('item_$itemId', true);

      if (categoryToEquip != null) {
        await prefs.setString('active_cosmetic_$categoryToEquip', itemId);
      }
      return true; // İşlem Kusursuz Tamamlandı
    } catch (e) {
      // 3. Adım: Hata Durumunda ROLLBACK (İade)
      await prefs.setInt('user_gems_balance', currentGems);
      gemsNotifier.value = currentGems;
      debugPrint('ShopService Kritik Hata: Satın alım başarısız, rollback uygulandı. Hata: $e');
      throw Exception('Satın alma işlemi başarısız oldu, elmaslarınız iade edildi.');
    }
  }

  Future<bool> hasFreezeShield() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_freeze_shield') ?? false;
  }

  Future<void> setFreezeShield(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_freeze_shield', value);
  }

  Duration getTimeUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  Future<void> activateDoubleXp() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
    await prefs.setInt('double_xp_expiry_time', expiry);
  }

  Future<bool> isDoubleXpActive() async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt('double_xp_expiry_time') ?? 0;
    return DateTime.now().millisecondsSinceEpoch < expiry;
  }

  Future<bool> hasItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('item_owned_$itemId') ?? prefs.getBool('item_$itemId') ?? false;
  }

  Future<void> revokeItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('item_owned_$itemId', false);
    await prefs.setBool('item_$itemId', false);
  }

  Future<String> getActiveCosmetic(String category, {String defaultVal = 'none'}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('active_cosmetic_$category') ?? defaultVal;
  }

  Future<void> setActiveCosmetic(String category, String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_cosmetic_$category', itemId);
  }
}