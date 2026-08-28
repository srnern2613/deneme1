// ============================================================================
// DOSYA ADI: lib/shop_screen.dart
// AÇIKLAMA: Akıcı Uçuş Hızı, Kozmik Arka Plan & "Bugün Alınanlar" Envanter Çubuklu Mağaza
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'xp_shop_service.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback? onNavigateToExplore;
  const ShopScreen({super.key, this.onNavigateToExplore});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  int _userGems = 500;
  int _userTotalXp = 100;
  int _streakDays = 1;
  bool _hasFreezeShield = false;
  bool _isDoubleXpActive = false;
  bool _hasGoldenCrown = false;
  bool _isWagerActive = false;
  bool _hasUsedRepairToday = false;
  int _chestsOpenedToday = 0;
  int _wagerProgressDays = 3;

  Timer? _countdownTimer;
  Duration _timeUntilMidnight = Duration.zero;

  // Canlı HUD Anahtarları ve Çarpma Animasyon Tetikleyicileri
  final GlobalKey _hudGemsKey = GlobalKey();
  final GlobalKey _hudXpKey = GlobalKey();
  double _gemsScale = 1.0;
  double _xpScale = 1.0;

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
    final repairUsed = prefs.getBool('streak_repair_used_today') ?? false;
    final chestsCount = prefs.getInt('chests_opened_today') ?? 0;
    final wagerDays = prefs.getInt('wager_progress_days') ?? 3;

    if (!mounted) return;
    setState(() {
      _userGems = gems;
      _userTotalXp = xp;
      _hasFreezeShield = shield;
      _isDoubleXpActive = doubleXp;
      _hasGoldenCrown = crown;
      _streakDays = streak;
      _isWagerActive = wager;
      _hasUsedRepairToday = repairUsed;
      _chestsOpenedToday = chestsCount;
      _wagerProgressDays = wagerDays;
    });
  }

  Future<void> _addDebugGems() async {
    HapticFeedback.heavyImpact();
    await XpShopService.instance.addGems(500);
    await _loadShopData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(milliseconds: 900),
        content: Text('💎 +500 Elmas Eklendi! (Mevcut: $_userGems 💎)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Future<void> _resetDebugGems() async {
    HapticFeedback.vibrate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_gems_balance', 0);
    await prefs.setInt('user_gems', 0);
    await prefs.setInt('gems_balance', 0);
    await XpShopService.instance.setFreezeShield(false);
    await prefs.setString('double_xp_expires_at', DateTime.now().subtract(const Duration(days: 2)).toIso8601String());
    await prefs.setBool('item_golden_crown', false);
    await prefs.setBool('golden_crown', false);
    await prefs.setBool('item_neon_theme', false);
    await prefs.setBool('neon_theme', false);
    await prefs.setBool('is_wager_active', false);
    await prefs.setBool('streak_repair_used_today', false);
    await prefs.setInt('chests_opened_today', 0);
    await prefs.setInt('wager_progress_days', 3);

    await _loadShopData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(milliseconds: 900),
        content: Text('🗑️ Envanter ve Elmaslar Sıfırlandı!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Future<void> _revokeItem(String itemKey, String itemName) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();

    if (itemKey == 'shield') {
      await XpShopService.instance.setFreezeShield(false);
      await prefs.setBool('has_freeze_shield', false);
      await prefs.setBool('freeze_shield', false);
    } else if (itemKey == 'double_xp') {
      await prefs.setString('double_xp_expires_at', DateTime.now().subtract(const Duration(days: 2)).toIso8601String());
    } else if (itemKey == 'golden_crown') {
      await prefs.setBool('item_golden_crown', false);
      await prefs.setBool('golden_crown', false);
    } else if (itemKey == 'neon_theme') {
      await prefs.setBool('item_neon_theme', false);
      await prefs.setBool('neon_theme', false);
    } else if (itemKey == 'wager') {
      await prefs.setBool('is_wager_active', false);
    } else if (itemKey == 'repair') {
      await prefs.setBool('streak_repair_used_today', false);
    }

    await _loadShopData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFE11D48),
        duration: const Duration(milliseconds: 900),
        content: Text('↩️ $itemName bırakıldı! Tekrar satın alabilirsin.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  // ==========================================================================
  // DOĞAL AKIŞ HIZINDA ÇİFT UÇUŞ (ELMAS VE XP) + ÇARPTIKÇA ARTAN CANLI SAYAÇ
  // ==========================================================================
  void _triggerDualFlyToHudEffect({
    required Offset startPosition,
    required int addedGems,
    required int addedXp,
  }) {
    final overlay = Overlay.of(context);
    final RenderBox? gemsBox = _hudGemsKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? xpBox = _hudXpKey.currentContext?.findRenderObject() as RenderBox?;

    if (gemsBox == null || xpBox == null) return;

    final gemsTarget = gemsBox.localToGlobal(Offset.zero) + Offset(gemsBox.size.width / 2, gemsBox.size.height / 2);
    final xpTarget = xpBox.localToGlobal(Offset.zero) + Offset(xpBox.size.width / 2, xpBox.size.height / 2);

    const particleCount = 8;
    final gemIncrementPerHit = (addedGems / particleCount).ceil();
    final xpIncrementPerHit = (addedXp / particleCount).ceil();

    late OverlayEntry overlayEntry;
    int completedParticles = 0;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Uçan Elmaslar
            ...List.generate(particleCount, (index) {
              return _DualFlyingParticle(
                start: startPosition + Offset(Random().nextDouble() * 30 - 15, Random().nextDouble() * 20 - 10),
                end: gemsTarget,
                curveLift: 60.0 + (index * 5),
                icon: PhosphorIcons.diamondBold,
                color: const Color(0xFF38BDF8),
                delay: Duration(milliseconds: index * 65),
                onImpact: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _userGems += gemIncrementPerHit;
                    _gemsScale = 1.3;
                  });
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) setState(() => _gemsScale = 1.0);
                  });
                  completedParticles++;
                  if (completedParticles >= particleCount * 2) {
                    overlayEntry.remove();
                    _loadShopData();
                  }
                },
              );
            }),
            // Uçan Enerjiler (XP)
            ...List.generate(particleCount, (index) {
              return _DualFlyingParticle(
                start: startPosition + Offset(Random().nextDouble() * 30 - 15, Random().nextDouble() * 20 - 10),
                end: xpTarget,
                curveLift: -60.0 - (index * 5),
                icon: PhosphorIcons.lightningBold,
                color: const Color(0xFFF59E0B),
                delay: Duration(milliseconds: (index * 65) + 160),
                onImpact: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _userTotalXp += xpIncrementPerHit;
                    _xpScale = 1.3;
                  });
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) setState(() => _xpScale = 1.0);
                  });
                  completedParticles++;
                  if (completedParticles >= particleCount * 2) {
                    overlayEntry.remove();
                    _loadShopData();
                  }
                },
              );
            }),
          ],
        );
      },
    );

    overlay.insert(overlayEntry);
  }

  // ==========================================================================
  // ŞIK YETERSİZ BAKİYE DİYALOĞU (HATASIZ TİPOGRAFİ)
  // ==========================================================================
  void _showInsufficientGemsDialog(int requiredGems) {
    HapticFeedback.vibrate();
    final missingGems = requiredGems - _userGems;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'InsufficientGems',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 26),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1F1123), Color(0xFF0D1322)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 2),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 6),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 2),
                      ),
                      child: const Icon(PhosphorIcons.lockKeyBold, color: Color(0xFFEF4444), size: 44)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(duration: 500.ms, begin: const Offset(1, 1), end: const Offset(1.15, 1.15)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'KİLİTLİ HAZİNE!',
                      style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 1.2, decoration: TextDecoration.none),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bu ganimeti açmak için $missingGems Elmasa daha ihtiyacın var.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13.5, height: 1.45, decoration: TextDecoration.none),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kitap okuyarak veya hedefleri tamamlayarak hemen elmas toplayabilirsin!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12, decoration: TextDecoration.none),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Kapat', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: const Color(0xFF070B14),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 8,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _addDebugGems();
                            },
                            child: Text('+500 Test Elması Al', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // TÜM GÜÇLENDİRİCİLER İÇİN 3D KART ÇEVİRME ZAFER KUTLAMASI
  // ==========================================================================
  void _showItemUnlockVictoryDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String perkText,
    required String categoryTag,
  }) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.96),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: _ItemUnlockVictoryView(
            icon: icon,
            iconColor: iconColor,
            title: title,
            perkText: perkText,
            categoryTag: categoryTag,
            onClose: () => Navigator.pop(ctx),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // CLASH ROYALE KART PATLAMALI DESTANSI SANDIK SEREMONİSİ
  // ==========================================================================
  void _startChestOpeningCeremony() {
    final earnedGems = Random().nextInt(110) + 70;
    final earnedXp = 150;
    final isJackpot = earnedGems >= 140;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.96),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: _ChestOpeningDialog(
            earnedGems: earnedGems,
            earnedXp: earnedXp,
            isJackpot: isJackpot,
            onCollect: (screenCenter) async {
              Navigator.pop(context);
              
              final prefs = await SharedPreferences.getInstance();
              final currentChests = prefs.getInt('chests_opened_today') ?? 0;
              await prefs.setInt('chests_opened_today', currentChests + 1);

              await XpShopService.instance.addGems(earnedGems);
              await XpShopService.instance.addXp(earnedXp);

              _triggerDualFlyToHudEffect(
                startPosition: screenCenter,
                addedGems: earnedGems,
                addedXp: earnedXp,
              );
            },
          ),
        );
      },
    );
  }

  void _showItemDetailsModal({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String fullDescription,
    required int price,
    required bool isOwned,
    required VoidCallback onConfirmBuy,
    VoidCallback? onRevoke,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(24)),
              child: Icon(icon, color: iconColor, size: 44),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(fullDescription, textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.5, height: 1.45)),
            const SizedBox(height: 24),
            if (isOwned) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: Center(child: Text('Bu Eşyaya Zaten Sahipsin', style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.w900))),
              ),
              const SizedBox(height: 10),
              if (onRevoke != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onRevoke();
                  },
                  icon: const Icon(PhosphorIcons.arrowUUpLeftBold, size: 16),
                  label: Text('Öğeyi Bırak / İptal Et (Test)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
            ] else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirmBuy();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(PhosphorIcons.diamondBold, size: 16),
                      const SizedBox(width: 6),
                      Text('$price Elmas ile Hemen Aç', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _buyItem({
    required String title,
    required int price,
    required Future<void> Function() onPurchased,
    IconData? icon,
    Color? iconColor,
    String? perkText,
    String? categoryTag,
  }) async {
    HapticFeedback.mediumImpact();

    if (_userGems < price) {
      _showInsufficientGemsDialog(price);
      return;
    }

    final success = await XpShopService.instance.spendGems(price);
    if (success) {
      await onPurchased();
      await _loadShopData();
      if (!mounted) return;

      if (icon != null) {
        _showItemUnlockVictoryDialog(
          icon: icon,
          iconColor: iconColor ?? const Color(0xFF38BDF8),
          title: title,
          perkText: perkText ?? 'Bu öğe hesabına kalıcı olarak eklendi ve aktif edildi.',
          categoryTag: categoryTag ?? 'GÜÇLENDİRİCİ',
        );
      }
    }
  }

  // ==========================================================================
  // BUGÜNÜN AKTİF ENVANTER VE GÜÇLERİ ÇUBUĞU (SAHİPLİK ETKİSİ)
  // ==========================================================================
  Widget _buildTodayActiveInventoryBar() {
    final List<Widget> activePills = [];

    if (_hasFreezeShield) {
      activePills.add(_buildActivePill(
        icon: PhosphorIcons.shieldCheckBold,
        label: 'Seri Kalkanı Aktif',
        color: const Color(0xFF38BDF8),
      ));
    }
    if (_isDoubleXpActive) {
      activePills.add(_buildActivePill(
        icon: PhosphorIcons.lightningBold,
        label: 'Çift XP Aktif (2x)',
        color: const Color(0xFFF59E0B),
      ));
    }
    if (_hasUsedRepairToday) {
      activePills.add(_buildActivePill(
        icon: PhosphorIcons.arrowCounterClockwiseBold,
        label: 'Seri İhya Kullanıldı',
        color: const Color(0xFF10B981),
      ));
    }
    if (_chestsOpenedToday > 0) {
      activePills.add(_buildActivePill(
        icon: PhosphorIcons.treasureChestBold,
        label: '$_chestsOpenedToday Sandık Açıldı',
        color: const Color(0xFFEC4899),
      ));
    }

    if (activePills.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.08), blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIcons.sparkleBold, color: Color(0xFF38BDF8), size: 14),
              const SizedBox(width: 6),
              Text(
                'BUGÜNÜN AKTİF GÜÇLERİ',
                style: GoogleFonts.outfit(color: const Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: activePills,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildActivePill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F46E5).withValues(alpha: 0.18),
                boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.18), blurRadius: 100, spreadRadius: 60)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ganimet Dükkanı', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          Text('Güçlendiriciler ve Özel Sandıklar', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Row(
                        children: [
                          // CANLI ELMAS KUTUSU
                          AnimatedScale(
                            scale: _gemsScale,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeOutBack,
                            child: Container(
                              key: _hudGemsKey,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 1.5),
                                boxShadow: _gemsScale > 1.0
                                    ? [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.8), blurRadius: 16, spreadRadius: 2)]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                                  const SizedBox(width: 4),
                                  Text('$_userGems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: _addDebugGems,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.25), shape: BoxShape.circle),
                                      child: const Icon(PhosphorIcons.plusBold, color: Color(0xFF38BDF8), size: 11),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: _resetDebugGems,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.25), shape: BoxShape.circle),
                                      child: const Icon(PhosphorIcons.trashBold, color: Color(0xFFEF4444), size: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // CANLI XP KUTUSU
                          AnimatedScale(
                            scale: _xpScale,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeOutBack,
                            child: Container(
                              key: _hudXpKey,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
                                boxShadow: _xpScale > 1.0
                                    ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.8), blurRadius: 16, spreadRadius: 2)]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  const Icon(PhosphorIcons.lightningBold, color: Colors.orange, size: 15),
                                  const SizedBox(width: 3),
                                  Text('$_userTotalXp', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTodayActiveInventoryBar(),
                  _buildShieldWarningBanner(),
                  const SizedBox(height: 16),
                  _buildWagerCard(),
                  const SizedBox(height: 22),
                  _buildSectionHeader('Günün Özel Fırsatları', badge: 'SINIRLI SÜRE'),
                  const SizedBox(height: 12),
                  _buildShowcaseChestCard(),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Güvence & Güçlendiriciler'),
                  const SizedBox(height: 12),
                  _buildProductCard(
                    icon: PhosphorIcons.shieldCheckBold,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'Seri Kalkanı (Streak Freeze)',
                    desc: 'Uygulamaya giremediğinde serinin sıfırlanmasını engeller.',
                    fullDesc: 'Seri Kalkanı, yoğun günlerde mevcut serini dondurarak yanmasını önler.',
                    price: 30,
                    isOwned: _hasFreezeShield,
                    ownedLabel: 'Kalkan Aktif',
                    badge: 'POPÜLER',
                    badgeColor: const Color(0xFF38BDF8),
                    onBuy: () => _buyItem(
                      title: 'Seri Kalkanı',
                      price: 30,
                      icon: PhosphorIcons.shieldCheckBold,
                      iconColor: const Color(0xFF38BDF8),
                      categoryTag: 'EFSANEVİ GÜVENCE',
                      perkText: 'Serin artık 24 saat boyunca donduruldu ve güvende!',
                      onPurchased: () => XpShopService.instance.setFreezeShield(true),
                    ),
                    onRevoke: () => _revokeItem('shield', 'Seri Kalkanı'),
                  ),
                  const SizedBox(height: 12),
                  _buildProductCard(
                    icon: PhosphorIcons.lightningBold,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Çift XP İksiri (24 Saat)',
                    desc: '24 saat boyunca tüm aktivitelerden 2 kat XP kazandırır.',
                    fullDesc: '24 saat boyunca okuduğun tüm içeriklerden iki katı tecrübe puanı alırsın.',
                    price: 50,
                    isOwned: _isDoubleXpActive,
                    ownedLabel: 'İksir Aktif',
                    badge: '2X KAZANÇ',
                    badgeColor: const Color(0xFFF59E0B),
                    onBuy: () => _buyItem(
                      title: 'Çift XP İksiri',
                      price: 50,
                      icon: PhosphorIcons.lightningBold,
                      iconColor: const Color(0xFFF59E0B),
                      categoryTag: 'GÜÇLENDİRİCİ İKSİR',
                      perkText: '24 saat boyunca okuyacağın her sayfadan tam 2 kat XP kazanacaksın!',
                      onPurchased: () => XpShopService.instance.activateDoubleXp(),
                    ),
                    onRevoke: () => _revokeItem('double_xp', 'Çift XP İksiri'),
                  ),
                  const SizedBox(height: 12),
                  _buildProductCard(
                    icon: PhosphorIcons.arrowCounterClockwiseBold,
                    iconColor: const Color(0xFF10B981),
                    title: 'Seri İhya (Streak Repair)',
                    desc: 'Dün kaçırdığın ve yanan serini anında geri kurtarır.',
                    fullDesc: 'Dün tamamlayamadığın okuma hedefini telafi eder ve serini kurtarır.',
                    price: 60,
                    isOwned: _hasUsedRepairToday,
                    ownedLabel: 'Kurtarıldı',
                    onBuy: () => _buyItem(
                      title: 'Seri İhya',
                      price: 60,
                      icon: PhosphorIcons.arrowCounterClockwiseBold,
                      iconColor: const Color(0xFF10B981),
                      categoryTag: 'ZAMAN SİHRİ',
                      perkText: 'Yanan dünkü serin mucizevi bir şekilde geri getirildi!',
                      onPurchased: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('streak_repair_used_today', true);
                      },
                    ),
                    onRevoke: () => _revokeItem('repair', 'Seri İhya'),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader('Statü & Prestij'),
                  const SizedBox(height: 12),
                  _buildProductCard(
                    icon: PhosphorIcons.crownBold,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Efsanevi Kraliyet Tacı',
                    desc: 'İsminin yanında sürekli parıldayan kraliyet tacı.',
                    fullDesc: 'Profilinde ve sıralamada seni diğerlerinden ayıran şık altın taç.',
                    price: 80,
                    isOwned: _hasGoldenCrown,
                    ownedLabel: 'Kullanımda',
                    badge: 'PRESTİJ',
                    badgeColor: const Color(0xFFF59E0B),
                    onBuy: () => _buyItem(
                      title: 'Kraliyet Tacı',
                      price: 80,
                      icon: PhosphorIcons.crownBold,
                      iconColor: const Color(0xFFF59E0B),
                      categoryTag: 'KRALİYET PRESTİJİ',
                      perkText: 'Artık ana ekranda ve lig tablosunda isminin yanında altın bir taç parlayacak!',
                      onPurchased: () => XpShopService.instance.buyItem('golden_crown'),
                    ),
                    onRevoke: () => _revokeItem('golden_crown', 'Altın Taç'),
                  ),
                  const SizedBox(height: 12),
                  _buildProductCard(
                    icon: PhosphorIcons.flameBold,
                    iconColor: const Color(0xFFEC4899),
                    title: 'Elmas Alev Çerçevesi',
                    desc: 'Profil kartını alevli ve elmas kaplı özel efektle donatır.',
                    fullDesc: 'Profil görselinin etrafını saran animasyonlu alev çerçevesi.',
                    price: 120,
                    onBuy: () => _buyItem(
                      title: 'Alev Çerçevesi',
                      price: 120,
                      icon: PhosphorIcons.flameBold,
                      iconColor: const Color(0xFFEC4899),
                      categoryTag: 'ÖZEL KOZMETİK',
                      perkText: 'Profil kartın artık elmas mavisi alevlerle kuşatıldı!',
                      onPurchased: () async {},
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildProductCard(
                    icon: PhosphorIcons.moonStarsBold,
                    iconColor: const Color(0xFF818CF8),
                    title: 'Gece & Neon Okuma Teması',
                    desc: 'Okuma deneyimi için özel neon mor gece paleti.',
                    fullDesc: 'Gece okumalarında gözleri dinlendiren mor neon palet.',
                    price: 70,
                    onBuy: () => _buyItem(
                      title: 'Neon Tema',
                      price: 70,
                      icon: PhosphorIcons.moonStarsBold,
                      iconColor: const Color(0xFF818CF8),
                      categoryTag: 'ATMOSFERİK TEMA',
                      perkText: 'Özel neon mor okuyucu teması kitaplığına entegre edildi!',
                      onPurchased: () => XpShopService.instance.buyItem('neon_theme'),
                    ),
                    onRevoke: () => _revokeItem('neon_theme', 'Neon Tema'),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShieldWarningBanner() {
    final timerString = _formatDuration(_timeUntilMidnight);

    if (_hasFreezeShield) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
              child: const Icon(PhosphorIcons.shieldCheckBold, color: Color(0xFF38BDF8), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Serin Güvende!', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFF93C5FD))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text('⏳ $timerString', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFF93C5FD))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('$_streakDays günlük serin gün sonuna kadar kalkan ile korunuyor.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(PhosphorIcons.warningBold, color: Color(0xFFEF4444), size: 24)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(duration: 600.ms, begin: const Offset(1, 1), end: const Offset(1.15, 1.15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Kalkanın Yok!', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFFFCA5A5))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text('🔥 $timerString kaldı', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFFFCA5A5))),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text('$_streakDays günlük serin gece sıfırlanabilir! Yanmaması için hemen kalkan al.', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWagerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1E1B4B).withValues(alpha: 0.9), const Color(0xFF0F172A).withValues(alpha: 0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
            child: const Icon(PhosphorIcons.targetBold, color: Color(0xFF818CF8), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('7 Günlük Seri Bahsi', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  _isWagerActive ? 'Bahis Aktif! 7 gün tamamlandığında +100 💎 alacaksın.' : '50 💎 yatır, 7 gün üst üste oku, 100 💎 geri kap!',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_isWagerActive)
            InkWell(
              onTap: () => _revokeItem('wager', 'Seri Bahsi'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Text('$_wagerProgressDays/7 Gün', style: GoogleFonts.outfit(color: const Color(0xFFA5B4FC), fontWeight: FontWeight.w900, fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text('İptal Et (Test)', style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 8.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF0F172A),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _buyItem(
                title: '7 Günlük Seri Bahsi',
                price: 50,
                icon: PhosphorIcons.targetBold,
                iconColor: const Color(0xFF818CF8),
                categoryTag: 'SERİ MEYDAN OKUMASI',
                perkText: '7 gün üst üste okuma bahsin başladı. Tamamla ve 100 Elmas kazan!',
                onPurchased: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_wager_active', true);
                },
              ),
              child: Text('Katıl', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }

  Widget _buildShowcaseChestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF311042).withValues(alpha: 0.9), const Color(0xFF1E1B4B).withValues(alpha: 0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEC4899).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
            child: const Icon(PhosphorIcons.treasureChestBold, color: Color(0xFFF472B6), size: 26)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .rotate(duration: 1200.ms, begin: -0.06, end: 0.06)
                .scale(duration: 1200.ms, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('Destansı Sandık', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(color: const Color(0xFFEC4899), borderRadius: BorderRadius.circular(5)),
                      child: Text('%30 İNDİRİM', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 7.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('İçinden 75-175 Elmas & +150 XP çıkar!', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFFBCFE8))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC4899),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            onPressed: () => _buyItem(
              title: 'Destansı Sandık',
              price: 45,
              onPurchased: () async {
                _startChestOpeningCeremony();
              },
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(PhosphorIcons.diamondBold, size: 12, color: Colors.white),
                const SizedBox(width: 3),
                Text('45', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? badge}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.2)),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
            ),
            child: Text(badge, style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w900, fontSize: 9)),
          ),
      ],
    );
  }

  Widget _buildProductCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required String fullDesc,
    required int price,
    bool isOwned = false,
    String ownedLabel = 'Sahipsin',
    String? badge,
    Color? badgeColor,
    required VoidCallback onBuy,
    VoidCallback? onRevoke,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showItemDetailsModal(
          icon: icon,
          iconColor: iconColor,
          title: title,
          fullDescription: fullDesc,
          price: price,
          isOwned: isOwned,
          onConfirmBuy: onBuy,
          onRevoke: onRevoke,
        ),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF111827).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOwned ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF1F2937),
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: (badgeColor ?? const Color(0xFF38BDF8)).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                            child: Text(badge, style: GoogleFonts.outfit(color: badgeColor ?? const Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 8.5)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(desc, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isOwned)
                InkWell(
                  onTap: onRevoke,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(ownedLabel, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF34D399))),
                        const SizedBox(width: 4),
                        const Icon(PhosphorIcons.xBold, size: 10, color: Color(0xFFEF4444)),
                      ],
                    ),
                  ),
                )
              else
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFF38BDF8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onBuy,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIcons.diamondBold, size: 12, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 4),
                      Text('$price', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET: _ItemUnlockVictoryView (3D Flip / Zafer Kartı)
// ============================================================================
class _ItemUnlockVictoryView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String perkText;
  final String categoryTag;
  final VoidCallback onClose;

  const _ItemUnlockVictoryView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.perkText,
    required this.categoryTag,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              size: Size.infinite,
              painter: _SunburstPainter(color: iconColor.withValues(alpha: 0.28)),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 8000.ms),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: iconColor.withValues(alpha: 0.8), width: 1.5),
                      boxShadow: [BoxShadow(color: iconColor.withValues(alpha: 0.3), blurRadius: 15)],
                    ),
                    child: Text(
                      categoryTag,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2, decoration: TextDecoration.none),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 28),

                  Container(
                    width: 240,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: iconColor, width: 3.5),
                      boxShadow: [
                        BoxShadow(color: iconColor.withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 8),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: iconColor, size: 68),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          perkText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), fontSize: 13, height: 1.4, decoration: TextDecoration.none),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.bounceOut)
                      .rotate(duration: 500.ms, begin: -0.1, end: 0, curve: Curves.easeOutBack),

                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 12,
                        shadowColor: const Color(0xFF10B981).withValues(alpha: 0.8),
                      ),
                      onPressed: onClose,
                      child: Text('KULLANMAYA BAŞLA', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ).animate().fadeIn(delay: 350.ms).scale(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET: _ChestOpeningDialog (Kozmik Gece Işıltılı & 3 Kademeli Sandık)
// ============================================================================
class _ChestOpeningDialog extends StatefulWidget {
  final int earnedGems;
  final int earnedXp;
  final bool isJackpot;
  final Function(Offset) onCollect;

  const _ChestOpeningDialog({
    required this.earnedGems,
    required this.earnedXp,
    required this.isJackpot,
    required this.onCollect,
  });

  @override
  State<_ChestOpeningDialog> createState() => _ChestOpeningDialogState();
}

class _ChestOpeningDialogState extends State<_ChestOpeningDialog> {
  int _crackStage = 0;
  int _displayedGems = 0;
  int _displayedXp = 0;

  void _handleTap(BuildContext context) {
    if (_crackStage == 0) {
      HapticFeedback.mediumImpact();
      setState(() => _crackStage = 1);
    } else if (_crackStage == 1) {
      HapticFeedback.heavyImpact();
      setState(() => _crackStage = 2);
    } else if (_crackStage == 2) {
      HapticFeedback.heavyImpact();
      setState(() => _crackStage = 3);
      _rollGemsCountWithOvershoot();
    } else if (_crackStage == 3) {
      HapticFeedback.heavyImpact();
      setState(() => _crackStage = 4);
      _rollXpCountWithOvershoot();
    }
  }

  void _rollGemsCountWithOvershoot() {
    _displayedGems = 0;
    int current = 0;
    final maxOvershoot = widget.earnedGems + 8;

    Timer.periodic(const Duration(milliseconds: 38), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (current < maxOvershoot) {
          current += max(1, ((maxOvershoot - current) / 4).ceil());
          _displayedGems = current;
          HapticFeedback.selectionClick();
        } else {
          _displayedGems = widget.earnedGems;
          HapticFeedback.heavyImpact();
          timer.cancel();
        }
      });
    });
  }

  void _rollXpCountWithOvershoot() {
    _displayedXp = 0;
    int current = 0;
    final maxOvershoot = widget.earnedXp + 15;

    Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (current < maxOvershoot) {
          current += max(1, ((maxOvershoot - current) / 4).ceil());
          _displayedXp = current;
          HapticFeedback.selectionClick();
        } else {
          _displayedXp = widget.earnedXp;
          HapticFeedback.heavyImpact();
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerOffset = Offset(screenSize.width / 2, screenSize.height / 2);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _crackStage < 4 ? () => _handleTap(context) : null,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [
                      const Color(0xFF311042).withValues(alpha: 0.85),
                      const Color(0xFF110726).withValues(alpha: 0.95),
                      const Color(0xFF030712).withValues(alpha: 0.98),
                    ],
                  ),
                ),
              ),
            ),

            if (_crackStage >= 3)
              Positioned.fill(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _SunburstPainter(
                    color: (widget.isJackpot
                            ? const Color(0xFFF59E0B)
                            : (_crackStage == 3 ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B)))
                        .withValues(alpha: 0.28),
                  ),
                ).animate(onPlay: (c) => c.repeat()).rotate(duration: widget.isJackpot ? 5000.ms : 9000.ms),
              ),

            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_crackStage < 3) ...[
                      Text(
                        _crackStage == 0
                            ? 'DESTANSI SANDIK!'
                            : (_crackStage == 1 ? 'KAPAK ZORLANIYOR...' : '💥 PATLAMAYA HAZIR! 💥'),
                        style: GoogleFonts.outfit(
                          color: _crackStage == 2 ? const Color(0xFFF43F5E) : const Color(0xFFFDE68A),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _crackStage == 0
                            ? 'Açmak için dokun!'
                            : (_crackStage == 1 ? 'Güçlüce bir kez daha dokun!' : 'Son bir dokunuşla patlat!'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.5, decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 44),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_crackStage >= 1)
                            Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_crackStage == 1 ? const Color(0xFFF59E0B) : const Color(0xFFEC4899))
                                        .withValues(alpha: 0.8),
                                    blurRadius: _crackStage == 1 ? 50 : 80,
                                    spreadRadius: _crackStage == 1 ? 15 : 30,
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899).withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                              border: _crackStage >= 1 ? Border.all(color: const Color(0xFFFDE68A), width: 2.5) : null,
                            ),
                            child: const Center(
                              child: Icon(PhosphorIcons.treasureChestBold, color: Color(0xFFF472B6), size: 90),
                            ),
                          )
                              .animate(
                                target: _crackStage.toDouble(),
                                onPlay: (c) => c.repeat(reverse: true),
                              )
                              .shake(
                                duration: _crackStage == 2 ? 150.ms : 450.ms,
                                hz: _crackStage == 2 ? 10 : 3,
                                offset: Offset(_crackStage * 4.0, _crackStage * 2.0),
                              )
                              .scale(
                                duration: 300.ms,
                                begin: const Offset(1, 1),
                                end: Offset(1 + _crackStage * 0.1, 1 + _crackStage * 0.1),
                              ),
                        ],
                      ),
                      const SizedBox(height: 46),
                      Text(
                        '⚡ DOKUN ⚡',
                        style: GoogleFonts.outfit(color: const Color(0xFFF472B6), fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1.5, decoration: TextDecoration.none),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 300.ms, begin: 0.3, end: 1.0),
                    ] else if (_crackStage == 3) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF38BDF8)),
                        ),
                        child: Text(
                          '1/2 GANİMET',
                          style: GoogleFonts.outfit(color: const Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2, decoration: TextDecoration.none),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: 230,
                        padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFF38BDF8), width: 3.5),
                          boxShadow: [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), blurRadius: 40, spreadRadius: 8)],
                        ),
                        child: Column(
                          children: [
                            const Icon(PhosphorIcons.diamondBold, color: Colors.white, size: 70),
                            const SizedBox(height: 18),
                            Text(
                              '+$_displayedGems',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: 4),
                            Text('Elmas Kazandın!', style: GoogleFonts.inter(color: const Color(0xFFE0F2FE), fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                          ],
                        ),
                      ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 38),
                      Text(
                        'Devam etmek için ekrana dokun 👉',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13.5, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 400.ms, begin: 0.4, end: 1.0),
                    ] else ...[
                      if (widget.isJackpot)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.6), blurRadius: 20)],
                          ),
                          child: Text(
                            '🔥 BÜYÜK VURGUN! (JACKPOT) 🔥',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, decoration: TextDecoration.none),
                          ),
                        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut)
                      else
                        Text(
                          '🎉 DESTANSI GANİMET! 🎉',
                          style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 0.5, decoration: TextDecoration.none),
                        ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
                              boxShadow: [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.45), blurRadius: 18)],
                            ),
                            child: Row(
                              children: [
                                const Icon(PhosphorIcons.diamondBold, color: Colors.white, size: 26),
                                const SizedBox(width: 8),
                                Text('+$_displayedGems', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFB45309)]),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: const Color(0xFFFBBF24), width: 2.5),
                              boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.45), blurRadius: 18)],
                            ),
                            child: Row(
                              children: [
                                const Icon(PhosphorIcons.lightningBold, color: Colors.white, size: 26),
                                const SizedBox(width: 8),
                                Text('+$_displayedXp XP', style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                              ],
                            ),
                          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                        ],
                      ),
                      const SizedBox(height: 44),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 12,
                            shadowColor: const Color(0xFF10B981).withValues(alpha: 0.8),
                          ),
                          onPressed: () => widget.onCollect(centerOffset),
                          child: Text('GANİMETİ TOPLA & BİTİR', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ).animate().fadeIn(delay: 200.ms).scale(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DUAL FLY-TO-HUD: İki Ayrı Hedefe Sıvı Akış Hızında Parçacık Hareketi
// ============================================================================
class _DualFlyingParticle extends StatefulWidget {
  final Offset start;
  final Offset end;
  final double curveLift;
  final IconData icon;
  final Color color;
  final Duration delay;
  final VoidCallback onImpact;

  const _DualFlyingParticle({
    required this.start,
    required this.end,
    required this.curveLift,
    required this.icon,
    required this.color,
    required this.delay,
    required this.onImpact,
  });

  @override
  State<_DualFlyingParticle> createState() => _DualFlyingParticleState();
}

class _DualFlyingParticleState extends State<_DualFlyingParticle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curveAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _curveAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);

    Future.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _isVisible = true);
      _controller.forward().then((_) {
        if (mounted) {
          widget.onImpact();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _curveAnimation,
      builder: (context, child) {
        final t = _curveAnimation.value;
        if (t >= 1.0) return const SizedBox.shrink();

        final currentX = lerpDouble(widget.start.dx, widget.end.dx, t)!;
        final currentY = lerpDouble(widget.start.dy, widget.end.dy, t)! - (sin(t * pi) * widget.curveLift);

        return Positioned(
          left: currentX,
          top: currentY,
          child: Transform.scale(
            scale: 1.05 - (t * 0.3),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: widget.color.withValues(alpha: 0.9), blurRadius: 12, spreadRadius: 3),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 15),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// CUSTOM PAINTER: Sonsuz Taşan Dönen Işık Huzmesi
// ============================================================================
class _SunburstPainter extends CustomPainter {
  final Color color;
  const _SunburstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = sqrt(size.width * size.width + size.height * size.height) * 1.5;
    const int rays = 18;
    const double angleStep = (2 * pi) / rays;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: color.a * 1.2),
          color,
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    for (int i = 0; i < rays; i++) {
      if (i % 2 == 0) {
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..arcTo(
            Rect.fromCircle(center: center, radius: radius),
            i * angleStep,
            angleStep,
            false,
          )
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter oldDelegate) => oldDelegate.color != color;
}