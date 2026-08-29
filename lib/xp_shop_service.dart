// ============================================================================
// DOSYA ADI: lib/xp_shop_service.dart
// AÇIKLAMA: Duolingo / Clash Royale Modeli XP & Elmas Ekonomisi Servisi
// GÖREVLER & DÜZELTMELER:
//   1. Eşya anahtarları (golden_crown, flame_border, neon_theme) standartlaştırıldı.
//   2. Çift XP süresi milisaniye bazlı epoch zamanına bağlandı.
//   3. Kalkan ve bakiye düşüm metodları senkronize edildi.
// ============================================================================

import 'package:shared_preferences/shared_preferences.dart';

class XpShopService {
  static final XpShopService instance = XpShopService._init();
  XpShopService._init();

  // Toplam XP (Kariyer puanı)
  Future<int> getTotalXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_total_xp') ?? 100;
  }

  // Harcanabilir Elmas Bakiyesi
  Future<int> getGemsBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_gems_balance') ?? 50;
  }

  // XP Ekleme (Çift XP aktifse 2 katı kazandırır)
  Future<int> addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentXp = await getTotalXp();

    final doubleXpExpiry = prefs.getInt('double_xp_expiry_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    int finalXp = amount;
    if (now < doubleXpExpiry) {
      finalXp *= 2;
    }

    int updatedXp = currentXp + finalXp;
    await prefs.setInt('user_total_xp', updatedXp);
    return updatedXp;
  }

  // Elmas Ekleme
  Future<int> addGems(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentGems = await getGemsBalance();
    int updatedGems = currentGems + amount;
    await prefs.setInt('user_gems_balance', updatedGems);
    return updatedGems;
  }

  // Elmas Harcama
  Future<bool> spendGems(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentGems = await getGemsBalance();
    if (currentGems >= amount) {
      await prefs.setInt('user_gems_balance', currentGems - amount);
      return true;
    }
    return false;
  }

  // Kalkan Durumu
  Future<bool> hasFreezeShield() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_freeze_shield') ?? false;
  }

  Future<void> setFreezeShield(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_freeze_shield', value);
  }

  // Gece 00:00'a kalan süreyi hesaplar
  Duration getTimeUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  // Çift XP Durumu
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

  // Eşya Sahipliği Kontrolü (Tüm profille uyumlu standart)
  Future<bool> hasItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('item_owned_$itemId') ?? prefs.getBool('item_$itemId') ?? false;
  }

  // Eşya Satın Alma ve Kalıcı Kaydetme
  Future<void> buyItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('item_owned_$itemId', true);
    await prefs.setBool('item_$itemId', true);
  }

  // Eşya İptali (Test / Debug için)
  Future<void> revokeItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('item_owned_$itemId', false);
    await prefs.setBool('item_$itemId', false);
  }
}