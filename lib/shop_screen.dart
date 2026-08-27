// ============================================================================
// DOSYA ADI: lib/shop_screen.dart
// AÇIKLAMA: Canlı Kalkan Geri Sayım Sayaçlı & İmza Başlıklı Mağaza
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'xp_shop_service.dart';
import 'app_header.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _userGems = 50;
  int _userTotalXp = 100;
  int _streakDays = 1;
  bool _hasFreezeShield = true;
  bool _isDoubleXpActive = false;
  bool _hasGoldenCrown = false;
  bool _isWagerActive = false;
  final int _wagerDaysRemaining = 7;

  Timer? _countdownTimer;
  Duration _timeUntilMidnight = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadShopData();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timeUntilMidnight = XpShopService.instance.getTimeUntilMidnight();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeUntilMidnight = XpShopService.instance.getTimeUntilMidnight();
      });
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _loadShopData() async {
    final prefs = await SharedPreferences.getInstance();
    final gems = await XpShopService.instance.getGemsBalance();
    final xp = await XpShopService.instance.getTotalXp();
    final shield = await XpShopService.instance.hasFreezeShield();
    final doubleXp = await XpShopService.instance.isDoubleXpActive();
    final crown = await XpShopService.instance.hasItem('golden_crown');
    final streak = prefs.getInt('current_streak_days') ?? 1;
    final wager = prefs.getBool('is_wager_active') ?? false;

    if (!mounted) return;
    setState(() {
      _userGems = gems;
      _userTotalXp = xp;
      _hasFreezeShield = shield;
      _isDoubleXpActive = doubleXp;
      _hasGoldenCrown = crown;
      _streakDays = streak;
      _isWagerActive = wager;
    });
  }

  Future<void> _buyItem({
    required String title,
    required int price,
    required Future<void> Function() onPurchased,
  }) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);

    if (_userGems < price) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[800],
          content: const Text('❌ Yetersiz Elmas! Günlük hedeflerini tamamlayarak elmas kazanabilirsin.'),
        ),
      );
      return;
    }

    final success = await XpShopService.instance.spendGems(price);
    if (success) {
      await onPurchased();
      await _loadShopData();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
          content: Text('🎉 $title başarıyla satın alındı!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppHeader(
        title: 'Mağaza',
        subtitle: 'Güçlendiriciler & Özel Öğeler',
        badgeEmoji: '💎',
        gems: _userGems,
        xp: _userTotalXp,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildShieldWarningBanner(isDark),
            const SizedBox(height: 20),
            _buildWagerCard(isDark, colors),
            const SizedBox(height: 24),
            _buildSectionHeader('🛡️ Güvence & Güçlendiriciler'),
            const SizedBox(height: 12),
            _buildProductCard(
              emoji: '🛡️',
              title: 'Seri Kalkanı (Streak Freeze)',
              desc: 'Uygulamaya 1 gün giremediğinde serinin sıfırlanmasını önler.',
              price: 30,
              isOwned: _hasFreezeShield,
              ownedLabel: 'Kalkan Aktif',
              isDark: isDark,
              onBuy: () => _buyItem(
                title: 'Seri Kalkanı',
                price: 30,
                onPurchased: () => XpShopService.instance.setFreezeShield(true),
              ),
            ),
            const SizedBox(height: 12),
            _buildProductCard(
              emoji: '⚡',
              title: 'Çift XP İksiri (24 Saat)',
              desc: '24 saat boyunca okuduğun tüm sayfalardan 2 kat XP kazanırsın.',
              price: 50,
              isOwned: _isDoubleXpActive,
              ownedLabel: 'İksir Aktif',
              isDark: isDark,
              onBuy: () => _buyItem(
                title: 'Çift XP İksiri',
                price: 50,
                onPurchased: () => XpShopService.instance.activateDoubleXp(),
              ),
            ),
            const SizedBox(height: 12),
            _buildProductCard(
              emoji: '🔄',
              title: 'Seri İhya (Streak Repair)',
              desc: 'Unutulup yanan dünkü serini tek tıkla kurtarır ve geri getirir.',
              price: 60,
              isDark: isDark,
              onBuy: () => _buyItem(
                title: 'Seri İhya',
                price: 60,
                onPurchased: () async {},
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('👑 Statü & Kişiselleştirme'),
            const SizedBox(height: 12),
            _buildProductCard(
              emoji: '👑',
              title: 'Efsanevi Altın Taç',
              desc: 'Ana ekranda isminin yanında parlayan prestijli kraliyet tacı.',
              price: 80,
              isOwned: _hasGoldenCrown,
              ownedLabel: 'Kullanımda',
              isDark: isDark,
              onBuy: () => _buyItem(
                title: 'Altın Taç',
                price: 80,
                onPurchased: () => XpShopService.instance.buyItem('golden_crown'),
              ),
            ),
            const SizedBox(height: 12),
            _buildProductCard(
              emoji: '🌌',
              title: 'Gece & Neon Okuma Teması',
              desc: 'Okuma ekranı ve arayüz için özel neon mor gece paleti.',
              price: 70,
              isDark: isDark,
              onBuy: () => _buyItem(
                title: 'Neon Tema',
                price: 70,
                onPurchased: () => XpShopService.instance.buyItem('neon_theme'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildShieldWarningBanner(bool isDark) {
    final timerString = _formatDuration(_timeUntilMidnight);

    if (_hasFreezeShield) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('🛡️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Serin Güvende!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⏳ $timerString',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$_streakDays günlük serin gün sonuna kadar kalkan ile korunuyor.', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[300] : Colors.grey[800])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kalkanın Yok!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🔥 $timerString kaldı',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$_streakDays günlük serin gece sıfırlanabilir! Yanmaması için hemen kalkan al.', style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[300] : Colors.grey[800])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWagerCard(bool isDark, ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF311042)]
              : [const Color(0xFFEEF2FF), const Color(0xFFFDF2F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Text('🎯', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '7 Günlük Seri Bahsi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  _isWagerActive
                      ? 'Bahis Aktif! $_wagerDaysRemaining gün sonra +100 💎 kazanacaksın.'
                      : '50 💎 yatır, 7 gün üst üste oku, 100 💎 geri kazan!',
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _isWagerActive ? Colors.grey[700] : colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isWagerActive
                ? null
                : () => _buyItem(
                      title: '7 Günlük Seri Bahsi',
                      price: 50,
                      onPurchased: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('is_wager_active', true);
                      },
                    ),
            child: Text(_isWagerActive ? 'Aktif' : 'Katıl', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2),
    );
  }

  Widget _buildProductCard({
    required String emoji,
    required String title,
    required String desc,
    required int price,
    bool isOwned = false,
    String ownedLabel = 'Sahipsin',
    required bool isDark,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isOwned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ownedLabel,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            )
          else
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onBuy,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💎', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text('$price', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}