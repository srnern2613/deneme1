// ============================================================================
// DOSYA ADI: lib/shop_screen.dart
// AÇIKLAMA: Taşma Hatası Giderilmiş ve Analiz Uyarıları Temizlenmiş Mağaza
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'xp_shop_service.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback? onNavigateToExplore;
  const ShopScreen({super.key, this.onNavigateToExplore});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  int _userGems = 50;
  int _userTotalXp = 100;
  bool _hasFreezeShield = false;
  bool _isDoubleXpActive = false;
  bool _hasGoldenCrown = false;
  bool _hasFlameBorder = false;
  bool _isWagerActive = false;
  bool _hasUsedRepairToday = false;
  int _chestsOpenedToday = 0;
  int _wagerProgressDays = 3;

  String _activeFrame = 'none';
  String _activeTheme = 'default';

  final Map<String, bool> _ownedItems = {};

  final ValueNotifier<Duration> _timeUntilMidnightNotifier = ValueNotifier<Duration>(Duration.zero);
  Timer? _countdownTimer;

  final GlobalKey _hudGemsKey = GlobalKey();
  final GlobalKey _hudXpKey = GlobalKey();

  final List<String> _allCosmeticKeys = [
    'golden_crown', 'flame_border', 'neon_frame', 'emerald_frame', 'titan_frame', 'storm_frame', 'cosmic_frame',
    'neon_theme', 'parchment_theme', 'nordic_theme', 'espresso_theme', 'oled_theme', 'sakura_theme',
    'gold_card', 'crystal_card', 'aurora_bg', 'cybercity_bg'
  ];

  @override
  void initState() {
    super.initState();
    _loadShopData();
    _startIsolatedTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadShopData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timeUntilMidnightNotifier.dispose();
    super.dispose();
  }

  void _startIsolatedTimer() {
    _timeUntilMidnightNotifier.value = XpShopService.instance.getTimeUntilMidnight();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = XpShopService.instance.getTimeUntilMidnight();
      _timeUntilMidnightNotifier.value = remaining;
      if (remaining.inSeconds <= 1) {
        _loadShopData();
      }
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _loadShopData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gems = await XpShopService.instance.getGemsBalance();
      final xp = await XpShopService.instance.getTotalXp();
      final shield = await XpShopService.instance.hasFreezeShield();
      final doubleXp = await XpShopService.instance.isDoubleXpActive();
      final crown = await XpShopService.instance.hasItem('golden_crown');
      final flame = await XpShopService.instance.hasItem('flame_border');
      final wager = prefs.getBool('is_wager_active') ?? false;
      final repairUsed = prefs.getBool('streak_repair_used_today') ?? false;
      final chestsCount = prefs.getInt('chests_opened_today') ?? 0;
      final wagerDays = prefs.getInt('wager_progress_days') ?? 3;

      final frame = await XpShopService.instance.getActiveCosmetic('frame', defaultVal: 'none');
      final theme = await XpShopService.instance.getActiveCosmetic('reading_theme', defaultVal: 'default');

      final Map<String, bool> ownership = {};
      for (var key in _allCosmeticKeys) {
        ownership[key] = await XpShopService.instance.hasItem(key);
      }

      if (!mounted) return;
      setState(() {
        _userGems = gems;
        _userTotalXp = xp;
        _hasFreezeShield = shield;
        _isDoubleXpActive = doubleXp;
        _hasGoldenCrown = crown;
        _hasFlameBorder = flame;
        _activeFrame = frame;
        _activeTheme = theme;
        _isWagerActive = wager;
        _hasUsedRepairToday = repairUsed;
        _chestsOpenedToday = chestsCount;
        _wagerProgressDays = wagerDays;
        _ownedItems.clear();
        _ownedItems.addAll(ownership);
      });
    } catch (_) {}
  }

  Future<void> _toggleEquipCosmetic(String category, String itemId) async {
    HapticFeedback.selectionClick();
    final current = await XpShopService.instance.getActiveCosmetic(category);
    if (current == itemId) {
      await XpShopService.instance.setActiveCosmetic(category, 'none');
    } else {
      await XpShopService.instance.setActiveCosmetic(category, itemId);
    }
    await _loadShopData();
  }

  Future<void> _dropItem(String itemId, String category) async {
    HapticFeedback.mediumImpact();
    await XpShopService.instance.revokeItem(itemId);
    if (category == 'frame' && _activeFrame == itemId) {
      await XpShopService.instance.setActiveCosmetic('frame', 'none');
    } else if (category == 'reading_theme' && _activeTheme == itemId) {
      await XpShopService.instance.setActiveCosmetic('reading_theme', 'default');
    } else if (category == 'crown') {
      await XpShopService.instance.revokeItem('golden_crown');
    }
    await _loadShopData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFFEF4444),
        content: Text('🗑️ Ürün test amaçlı bırakıldı / envanterden kaldırıldı.'),
      ),
    );
  }

  Future<void> _addDebugGems() async {
    HapticFeedback.heavyImpact();
    await XpShopService.instance.addGems(500);
    await _loadShopData();
  }

  void _triggerDualFlyToHudEffect({required Offset startPosition, required int addedGems, required int addedXp}) {
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
                  setState(() => _userGems += gemIncrementPerHit);
                  completedParticles++;
                  if (completedParticles >= particleCount * 2) {
                    overlayEntry.remove();
                    _loadShopData();
                  }
                },
              );
            }),
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
                  setState(() => _userTotalXp += xpIncrementPerHit);
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
                  gradient: const LinearGradient(colors: [Color(0xFF1F1123), Color(0xFF0D1322)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIcons.lockKeyBold, color: Color(0xFFEF4444), size: 44),
                    const SizedBox(height: 20),
                    Text('KİLİTLİ HAZİNE!', style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontSize: 21, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                    const SizedBox(height: 10),
                    Text('Bu ganimeti açmak için $missingGems Elmasa daha ihtiyacın var.', textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13.5, decoration: TextDecoration.none)),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: const Color(0xFF070B14)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addDebugGems();
                      },
                      child: const Text('+500 Test Elması Al', style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _startChestOpeningCeremony() {
    final earnedGems = Random().nextInt(110) + 70;
    final earnedXp = 150;

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
            onCollect: (screenCenter) async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              final currentChests = prefs.getInt('chests_opened_today') ?? 0;
              await prefs.setInt('chests_opened_today', currentChests + 1);

              await XpShopService.instance.addGems(earnedGems);
              await XpShopService.instance.addXp(earnedXp);

              _triggerDualFlyToHudEffect(startPosition: screenCenter, addedGems: earnedGems, addedXp: earnedXp);
            },
          ),
        );
      },
    );
  }

  Future<void> _buyItem({
    required String itemId,
    required String title,
    required int price,
    required String categoryTag,
    required String perkText,
    IconData? icon,
    Color? iconColor,
    String? categoryToEquip,
  }) async {
    HapticFeedback.mediumImpact();

    if (_userGems < price) {
      _showInsufficientGemsDialog(price);
      return;
    }

    final success = await XpShopService.instance.spendGems(price);
    if (success) {
      await XpShopService.instance.buyItem(itemId);
      if (categoryToEquip != null) {
        await XpShopService.instance.setActiveCosmetic(categoryToEquip, itemId);
      }
      await _loadShopData();
    }
  }

  Widget _buildTodayActiveInventoryBar() {
    final List<Widget> activePills = [];

    if (_hasFreezeShield) {
      activePills.add(_buildActivePill(icon: PhosphorIcons.shieldCheckBold, label: 'Seri Kalkanı Aktif', color: const Color(0xFF38BDF8)));
    }
    if (_isDoubleXpActive) {
      activePills.add(_buildActivePill(icon: PhosphorIcons.lightningBold, label: 'Çift XP Aktif (2x)', color: const Color(0xFFF59E0B)));
    }
    if (_hasGoldenCrown) {
      activePills.add(_buildActivePill(icon: PhosphorIcons.crownBold, label: 'Kraliyet Tacı Takılı', color: const Color(0xFFF59E0B)));
    }
    if (_hasFlameBorder) {
      activePills.add(_buildActivePill(icon: PhosphorIcons.flameBold, label: 'Alev Çerçevesi Aktif', color: const Color(0xFFEC4899)));
    }
    if (_hasUsedRepairToday) {
      activePills.add(_buildActivePill(icon: PhosphorIcons.arrowCounterClockwiseBold, label: 'Seri İhya Kullanıldı', color: const Color(0xFF10B981)));
    }
    if (_chestsOpenedToday > 0) {
      activePills.add(_buildActivePill(icon: PhosphorIcons.treasureChestBold, label: '$_chestsOpenedToday Sandık Açıldı', color: const Color(0xFFEC4899)));
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIcons.sparkleBold, color: Color(0xFF38BDF8), size: 14),
              const SizedBox(width: 6),
              Text('BUGÜNÜN AKTİF GÜÇLERİ', style: GoogleFonts.outfit(color: const Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: activePills),
        ],
      ),
    );
  }

  Widget _buildActivePill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.4))),
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
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildTodayActiveInventoryBar(),
                  _buildShieldWarningBanner(),
                  const SizedBox(height: 16),
                  _buildWagerCard(),
                  const SizedBox(height: 22),
                  _buildSectionHeader('Günün Özel Fırsatları', badge: 'SINIRLI SÜRE'),
                  const SizedBox(height: 12),
                  _buildShowcaseChestCard(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Güvence & Güçlendiriciler'),
                  const SizedBox(height: 12),
                  _buildConsumableCard(
                    icon: PhosphorIcons.shieldCheckBold,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'Seri Kalkanı (Streak Freeze)',
                    desc: 'Uygulamaya giremediğinde serini dondurur.',
                    price: 30,
                    isActive: _hasFreezeShield,
                    activeLabel: 'Kalkan Aktif',
                    onBuy: () async {
                      if (_userGems >= 30) {
                        await XpShopService.instance.spendGems(30);
                        await XpShopService.instance.setFreezeShield(true);
                        _loadShopData();
                      } else {
                        _showInsufficientGemsDialog(30);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildConsumableCard(
                    icon: PhosphorIcons.lightningBold,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Çift XP İksiri (24 Saat)',
                    desc: '24 saat boyunca tüm aktivitelerden 2 kat XP verir.',
                    price: 50,
                    isActive: _isDoubleXpActive,
                    activeLabel: '2X Aktif',
                    onBuy: () async {
                      if (_userGems >= 50) {
                        await XpShopService.instance.spendGems(50);
                        await XpShopService.instance.activateDoubleXp();
                        _loadShopData();
                      } else {
                        _showInsufficientGemsDialog(50);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Profil Çerçeveleri', badge: 'KOZMETİK DOLAP'),
                  const SizedBox(height: 12),
                  _buildCosmeticWardrobeCard(itemId: 'flame_border', category: 'frame', icon: PhosphorIcons.flameBold, iconColor: const Color(0xFFEC4899), title: 'Elmas Alev Çerçevesi', desc: 'Profil fotoğrafını parıldayan elmas alevleriyle kuşatır.', price: 120),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'neon_frame', category: 'frame', icon: PhosphorIcons.waveformBold, iconColor: const Color(0xFFA855F7), title: 'Siberpunk Neon Çerçeve', desc: 'Mor ve camgöbeği animasyonlu neon fütüristik çerçeve.', price: 130),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'emerald_frame', category: 'frame', icon: PhosphorIcons.leafBold, iconColor: const Color(0xFF10B981), title: 'Zümrüt Doğa Çerçevesi', desc: 'Sarmaşık ve canlı yeşil zümrüt ışıltılı prestij halkası.', price: 110),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'titan_frame', category: 'frame', icon: PhosphorIcons.shieldStarBold, iconColor: const Color(0xFFF59E0B), title: 'Antik Titan Çerçevesi', desc: 'Ağır bronz ve altın işlemeli efsanevi savaşçı çerçevesi.', price: 150),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'storm_frame', category: 'frame', icon: PhosphorIcons.lightningSlashBold, iconColor: const Color(0xFF38BDF8), title: 'Yıldırım Fırtınası', desc: 'Mavi elektrik arklarıyla çevrili yüksek voltajlı kenarlık.', price: 140),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'cosmic_frame', category: 'frame', icon: PhosphorIcons.planetBold, iconColor: const Color(0xFFC084FC), title: 'Kozmik Galaksi Çerçevesi', desc: 'Dönen yıldız tozları ve uzay boşluğu gradyanı.', price: 160),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Kitap Okuma Temaları', badge: 'CANLI TEST EDİLEBİLİR'),
                  const SizedBox(height: 12),
                  _buildCosmeticWardrobeCard(itemId: 'neon_theme', category: 'reading_theme', icon: PhosphorIcons.moonStarsBold, iconColor: const Color(0xFF818CF8), title: 'Gece & Neon Paleti', desc: 'Gözleri yormayan koyu mor zemin ve yumuşak neon metinler.', price: 70),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'parchment_theme', category: 'reading_theme', icon: PhosphorIcons.scrollBold, iconColor: const Color(0xFFD97706), title: 'Antik Parşömen Teması', desc: 'Eski kütüphane kağıt dokusu ve nostaljik kahverengi mürekkep.', price: 65),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'nordic_theme', category: 'reading_theme', icon: PhosphorIcons.treeBold, iconColor: const Color(0xFF059669), title: 'Nordik Çam Ormanı', desc: 'Huzur veren koyu çam yeşili arkaplan ve sakinleştirici font tonları.', price: 75),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'espresso_theme', category: 'reading_theme', icon: PhosphorIcons.coffeeBold, iconColor: const Color(0xFF92400E), title: 'Espresso Sıcak Kahve', desc: 'Sıcak krem rengi tipografi ve zengin koyu kahve arka plan.', price: 60),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'oled_theme', category: 'reading_theme', icon: PhosphorIcons.circleHalfBold, iconColor: Colors.white, title: 'OLED Saf Siyah', desc: 'Maksimum şarj tasarrufu sağlayan sıfır ışık sızıntılı derin siyah.', price: 80),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'sakura_theme', category: 'reading_theme', icon: PhosphorIcons.flowerLotusBold, iconColor: const Color(0xFFF472B6), title: 'Japon Kiraz Çiçeği (Sakura)', desc: 'Pastel pembe ve yumuşak gün batımı tonlarında dingin okuma.', price: 75),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Prestij & Kart Stilleri'),
                  const SizedBox(height: 12),
                  _buildCosmeticWardrobeCard(itemId: 'golden_crown', category: 'crown', icon: PhosphorIcons.crownBold, iconColor: const Color(0xFFF59E0B), title: 'Efsanevi Kraliyet Tacı', desc: 'Profilinde ve liderlik tablosunda adının yanında altın taç parıldar.', price: 80),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ganimet Dükkanı', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              Text('Kozmetik Dolabı & Güçlendiriciler', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: _hudGemsKey,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF38BDF8))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                  const SizedBox(width: 4),
                  Text('$_userGems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 6),
                  InkWell(onTap: _addDebugGems, child: const Icon(PhosphorIcons.plusBold, color: Color(0xFF38BDF8), size: 14)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              key: _hudXpKey,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF59E0B))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 15),
                  const SizedBox(width: 3),
                  Text('$_userTotalXp XP', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShieldWarningBanner() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _timeUntilMidnightNotifier,
      builder: (context, remainingTime, _) {
        final timerString = _formatDuration(remainingTime);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hasFreezeShield ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFF7F1D1D).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hasFreezeShield ? const Color(0xFF38BDF8) : const Color(0xFFEF4444)),
          ),
          child: Row(
            children: [
              Icon(_hasFreezeShield ? PhosphorIcons.shieldCheckBold : PhosphorIcons.warningBold, color: _hasFreezeShield ? const Color(0xFF38BDF8) : const Color(0xFFEF4444), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_hasFreezeShield ? 'Serin Güvende!' : 'Kalkanın Yok!', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white)),
                    Text('Kalan Süre: $timerString', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWagerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF6366F1))),
      child: Row(
        children: [
          const Icon(PhosphorIcons.targetBold, color: Color(0xFF818CF8), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('7 Günlük Seri Bahsi', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white)),
                Text(_isWagerActive ? 'Bahis Aktif! ($_wagerProgressDays/7 Gün)' : '50 💎 yatır, 7 gün oku, 100 💎 kazan!', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseChestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1E1B4B), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEC4899))),
      child: Row(
        children: [
          const Icon(PhosphorIcons.treasureChestBold, color: Color(0xFFF472B6), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Destansı Sandık', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13.5, color: Colors.white)),
                Text('75-175 Elmas & +150 XP kazan!', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFFBCFE8))),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white),
            onPressed: () async {
              if (_userGems >= 45) {
                await XpShopService.instance.spendGems(45);
                _startChestOpeningCeremony();
              } else {
                _showInsufficientGemsDialog(45);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('45', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 3),
                const Icon(PhosphorIcons.diamondBold, size: 13, color: Colors.white),
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
        Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
            child: Text(badge, style: GoogleFonts.outfit(color: const Color(0xFFA5B4FC), fontWeight: FontWeight.w900, fontSize: 9)),
          ),
      ],
    );
  }

  Widget _buildCosmeticWardrobeCard({required String itemId, required String category, required IconData icon, required Color iconColor, required String title, required String desc, required int price}) {
    final bool isOwned = _ownedItems[itemId] ?? false;
    bool isEquipped = category == 'frame' ? (_activeFrame == itemId) : (category == 'crown' ? _hasGoldenCrown : (_activeTheme == itemId));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEquipped ? const Color(0xFF1E1B4B).withValues(alpha: 0.7) : const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isEquipped ? const Color(0xFF6366F1) : const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                Text(desc, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOwned) ...[
            IconButton(
              icon: const Icon(PhosphorIcons.trashBold, color: Color(0xFFEF4444), size: 18),
              tooltip: 'Ürünü Bırak (Test)',
              onPressed: () => _dropItem(itemId, category),
            ),
            const SizedBox(width: 4),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: isEquipped ? const Color(0xFF4F46E5) : const Color(0xFF10B981).withValues(alpha: 0.15),
                foregroundColor: isEquipped ? Colors.white : const Color(0xFF34D399),
              ),
              onPressed: () => _toggleEquipCosmetic(category, itemId),
              child: Text(isEquipped ? 'Kullanımda ✓' : 'Kuşan', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ] else
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.2), foregroundColor: const Color(0xFF38BDF8)),
              onPressed: () => _buyItem(itemId: itemId, title: title, price: price, categoryTag: 'ÖZEL KOZMETİK', perkText: '$title envantere eklendi!', icon: icon, iconColor: iconColor, categoryToEquip: category),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$price', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(width: 3),
                  const Icon(PhosphorIcons.diamondBold, size: 13, color: Color(0xFF38BDF8)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConsumableCard({required IconData icon, required Color iconColor, required String title, required String desc, required int price, required bool isActive, required String activeLabel, required VoidCallback onBuy}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF1F2937))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white)),
                Text(desc, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(activeLabel, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF34D399))),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.2), foregroundColor: const Color(0xFF38BDF8)),
              onPressed: onBuy,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$price', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(width: 3),
                  const Icon(PhosphorIcons.diamondBold, size: 13, color: Color(0xFF38BDF8)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChestOpeningDialog extends StatefulWidget {
  final int earnedGems;
  final int earnedXp;
  final Function(Offset) onCollect;

  const _ChestOpeningDialog({required this.earnedGems, required this.earnedXp, required this.onCollect});

  @override
  State<_ChestOpeningDialog> createState() => _ChestOpeningDialogState();
}

class _ChestOpeningDialogState extends State<_ChestOpeningDialog> {
  int _crackStage = 0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: _crackStage < 1 ? () => setState(() => _crackStage = 1) : null,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(PhosphorIcons.treasureChestBold, color: Color(0xFFF472B6), size: 90),
              const SizedBox(height: 20),
              if (_crackStage == 0)
                Text('Açmak İçin Dokun!', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('+${widget.earnedGems}', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 4),
                    const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 24),
                    const SizedBox(width: 12),
                    Text('+${widget.earnedXp} XP', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 26, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  onPressed: () => widget.onCollect(Offset(screenSize.width / 2, screenSize.height / 2)),
                  child: const Text('Topla & Kapat', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DualFlyingParticle extends StatefulWidget {
  final Offset start;
  final Offset end;
  final double curveLift;
  final IconData icon;
  final Color color;
  final Duration delay;
  final VoidCallback onImpact;

  const _DualFlyingParticle({required this.start, required this.end, required this.curveLift, required this.icon, required this.color, required this.delay, required this.onImpact});

  @override
  State<_DualFlyingParticle> createState() => _DualFlyingParticleState();
}

class _DualFlyingParticleState extends State<_DualFlyingParticle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _curveAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      _controller.forward().then((_) {
        if (mounted) widget.onImpact();
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
    return AnimatedBuilder(
      animation: _curveAnimation,
      builder: (context, child) {
        final t = _curveAnimation.value;
        if (t >= 1.0) return const SizedBox.shrink();
        final currentX = lerpDouble(widget.start.dx, widget.end.dx, t)!;
        final currentY = lerpDouble(widget.start.dy, widget.end.dy, t)! - (sin(t * pi) * widget.curveLift);
        return Positioned(left: currentX, top: currentY, child: Icon(widget.icon, color: widget.color, size: 16));
      },
    );
  }
}