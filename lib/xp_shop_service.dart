import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class XpShopService {
  static final XpShopService instance = XpShopService._init();
  XpShopService._init();

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
    return updatedXp;
  }

  Future<int> addGems(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentGems = prefs.getInt('user_gems_balance') ?? 50;
    int updatedGems = currentGems + amount;
    await prefs.setInt('user_gems_balance', updatedGems);
    gemsNotifier.value = updatedGems;
    return updatedGems;
  }

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

  Future<void> buyItem(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('item_owned_$itemId', true);
    await prefs.setBool('item_$itemId', true);
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