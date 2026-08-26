// ==============================================================
// DOSYA ADI: lib/xp_shop_service.dart
// AÇIKLAMA: Duolingo Modeli XP & Kıt Elmas (Gems) Ekonomisi Servisi
// ==============================================================

import 'package:shared_preferences/shared_preferences.dart';

class XpShopService {
  static final XpShopService instance = XpShopService._init();
  XpShopService._init();

  // Toplam XP (Asla harcanmaz, kariyer puanıdır)
  Future<int> getTotalXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_total_xp') ?? 100;
  }

  // Harcanabilir Elmas Bakiyesi
  Future<int> getGemsBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_gems_balance') ?? 50; // Başlangıç 50 Elmas
  }

  // XP Ekleme (Okuma ve Flashcard için)
  Future<int> addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentXp = await getTotalXp();

    final doubleXpExpiry = prefs.getInt('double_xp_expiry_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    int finalXp = amount;
    if (now < doubleXpExpiry) {
      finalXp *= 2; // Çift XP İksiri aktif!
    }

    int updatedXp = currentXp + finalXp;
    await prefs.setInt('user_total_xp', updatedXp);
    return updatedXp;
  }

  // Elmas Ekleme (Yalnızca Günlük Hedef Tamamlama veya Sandıklardan)
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

  // Kalkan ve İksir Durumları
  Future<bool> hasFreezeShield() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_freeze_shield') ?? true;
  }

  Future<void> setFreezeShield(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_freeze_shield', value);
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
    return prefs.getBool('item_owned_$itemId') ?? false;
  }

  Future<void> buyItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('item_owned_$itemId', true);
  }
}