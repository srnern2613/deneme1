// ============================================================================
// DOSYA ADI: lib/shop_screen.dart
// AÇIKLAMA: Mağaza, Sabit Sekmeli Ganimet Dolabı, Kompakt Akordeon Güçler,
//            AbsorbPointer Zırhlı Sandık Sistemi ve Metin Kırılma Korumalı Kozmetik Kartları
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'xp_shop_service.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback? onNavigateToExplore;
  const ShopScreen({super.key, this.onNavigateToExplore});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
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

  int _selectedTabIndex = 0; // 0: Fırsatlar, 1: Güvence, 2: Çerçeveler, 3: Temalar, 4: Prestij
  bool _isInventoryExpanded = false; // Kompakt Aktif Güçler Akordeon Kontrolü
  bool _isChestOpeningInProgress = false; // Race-condition / Çift Tıklama Koruması

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
      if (!mounted) return;
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
      await XpShopService.instance.getGemsBalance();
      await XpShopService.instance.getTotalXp();
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
    if (!mounted) return;
    if (current == itemId) {
      await XpShopService.instance.setActiveCosmetic(category, 'none');
    } else {
      await XpShopService.instance.setActiveCosmetic(category, itemId);
    }
    if (!mounted) return;
    await _loadShopData();
  }

  Future<void> _dropItem(String itemId, String category) async {
    HapticFeedback.mediumImpact();
    await XpShopService.instance.revokeItem(itemId);
    if (!mounted) return;
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
        content: Text('🗑️ Ürün envanterden kaldırıldı.'),
      ),
    );
  }

  Future<void> _addDebugGems() async {
    HapticFeedback.heavyImpact();
    await XpShopService.instance.addGems(500);
    if (!mounted) return;
    await _loadShopData();
  }

  void _triggerDualFlyToHudEffect({required Offset startPosition, required int addedGems, required int addedXp}) {
    final overlay = Overlay.of(context);
    final RenderBox? gemsBox = _hudGemsKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? xpBox = _hudXpKey.currentContext?.findRenderObject() as RenderBox?;

    if (gemsBox == null || xpBox == null) return;

    final gemsTarget = gemsBox.localToGlobal(Offset.zero) + Offset(gemsBox.size.width / 2, gemsBox.size.height / 2);
    final xpTarget = xpBox.localToGlobal(Offset.zero) + Offset(xpBox.size.width / 2, xpBox.size.height / 2);

    const particleCount = 10;

    late OverlayEntry overlayEntry;
    int completedParticles = 0;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            ...List.generate(particleCount, (index) {
              return _DualFlyingParticle(
                start: startPosition + Offset(Random().nextDouble() * 40 - 20, Random().nextDouble() * 30 - 15),
                end: gemsTarget,
                curveLift: 70.0 + (index * 6),
                icon: PhosphorIcons.diamondBold,
                color: const Color(0xFF38BDF8),
                delay: Duration(milliseconds: index * 55),
                onImpact: () {
                  HapticFeedback.selectionClick();
                  completedParticles++;
                  if (!mounted) return;
                  if (completedParticles >= particleCount * 2) {
                    overlayEntry.remove();
                    if (mounted) _loadShopData();
                  }
                },
              );
            }),
            ...List.generate(particleCount, (index) {
              return _DualFlyingParticle(
                start: startPosition + Offset(Random().nextDouble() * 40 - 20, Random().nextDouble() * 30 - 15),
                end: xpTarget,
                curveLift: -70.0 - (index * 6),
                icon: PhosphorIcons.lightningBold,
                color: const Color(0xFFF59E0B),
                delay: Duration(milliseconds: (index * 55) + 120),
                onImpact: () {
                  HapticFeedback.selectionClick();
                  completedParticles++;
                  if (!mounted) return;
                  if (completedParticles >= particleCount * 2) {
                    overlayEntry.remove();
                    if (mounted) _loadShopData();
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

  // --- PSİKOLOJİK DEĞER ÇAPALAMA VE YÜKSEK NİYETLİ POPUP ---
  void _showInsufficientGemsDialog(int requiredGems) {
    HapticFeedback.vibrate();
    final missingGems = requiredGems - XpShopService.instance.gemsNotifier.value;

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
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 48)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                    const SizedBox(height: 20),
                    Text('GANİMETİ KAÇIRMA!', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 21, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                    const SizedBox(height: 10),
                    Text('Bu hazineye ulaşmak için yalnızca $missingGems Elmasa ihtiyacın var. Fırsatı yakala!', textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13.5, decoration: TextDecoration.none)),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B), 
                          foregroundColor: const Color(0xFF070B14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          _addDebugGems();
                        },
                        child: Text('Hemen Sahip Ol (500 Elmas)', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
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
              if (!mounted) return;
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              final currentChests = prefs.getInt('chests_opened_today') ?? 0;
              await prefs.setInt('chests_opened_today', currentChests + 1);

              await XpShopService.instance.addGems(earnedGems);
              await XpShopService.instance.addXp(earnedXp);

              if (!mounted) return;
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

    if (XpShopService.instance.gemsNotifier.value < price) {
      if (!mounted) return;
      _showInsufficientGemsDialog(price);
      return;
    }

    try {
      final success = await XpShopService.instance.spendGems(price);
      if (!mounted) return;
      if (success) {
        await XpShopService.instance.buyItem(itemId);
        if (!mounted) return;
        if (categoryToEquip != null) {
          await XpShopService.instance.setActiveCosmetic(categoryToEquip, itemId);
        }
        if (!mounted) return;
        await _loadShopData();
      }
    } catch (_) {}
  }

  // --- KOMPAKT AKORDEON AKTİF GÜÇLER ALANI ---
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              HapticFeedback.selectionClick();
              if (!mounted) return;
              setState(() => _isInventoryExpanded = !_isInventoryExpanded);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(PhosphorIcons.sparkleBold, color: Color(0xFF38BDF8), size: 14),
                    const SizedBox(width: 6),
                    Text('AKTİF GÜÇLER (${activePills.length})', style: GoogleFonts.outfit(color: const Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  ],
                ),
                Icon(_isInventoryExpanded ? PhosphorIcons.caretUpBold : PhosphorIcons.caretDownBold, color: const Color(0xFF93C5FD), size: 14),
              ],
            ),
          ),
          if (_isInventoryExpanded) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: activePills),
          ],
        ],
      ),
    );
  }

  Widget _buildActivePill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15), 
        borderRadius: BorderRadius.circular(10), 
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
      body: SafeArea(
        child: NestedScrollView(
          physics: const BouncingScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: _buildHeader(),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyTabBarDelegate(
                  child: Container(
                    color: const Color(0xFF070B14),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _buildTabChip(0, '✨ Fırsatlar', PhosphorIcons.sparkleBold),
                          const SizedBox(width: 8),
                          _buildTabChip(1, '🛡️ Güvence', PhosphorIcons.shieldCheckBold),
                          const SizedBox(width: 8),
                          _buildTabChip(2, '🖼️ Çerçeveler', PhosphorIcons.frameCornersBold),
                          const SizedBox(width: 8),
                          _buildTabChip(3, '📖 Temalar', PhosphorIcons.bookOpenBold),
                          const SizedBox(width: 8),
                          _buildTabChip(4, '👑 Prestij', PhosphorIcons.crownBold),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTodayActiveInventoryBar(),
                if (_selectedTabIndex == 0) ...[
                  _buildShieldWarningBanner(),
                  const SizedBox(height: 14),
                  _buildWagerCard(),
                  const SizedBox(height: 14),
                  _buildShowcaseChestCard(),
                ] else if (_selectedTabIndex == 1) ...[
                  _buildConsumableCard(
                    icon: PhosphorIcons.shieldCheckBold,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'Seri Kalkanı (Streak Freeze)',
                    desc: 'Uygulamaya giremediğinde serini dondurur.',
                    price: 30,
                    isActive: _hasFreezeShield,
                    activeLabel: 'Kalkan Aktif',
                    onBuy: () async {
                      if (XpShopService.instance.gemsNotifier.value >= 30) {
                        await XpShopService.instance.spendGems(30);
                        await XpShopService.instance.setFreezeShield(true);
                        if (!mounted) return;
                        _loadShopData();
                      } else {
                        if (!mounted) return;
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
                      if (XpShopService.instance.gemsNotifier.value >= 50) {
                        await XpShopService.instance.spendGems(50);
                        await XpShopService.instance.activateDoubleXp();
                        if (!mounted) return;
                        _loadShopData();
                      } else {
                        if (!mounted) return;
                        _showInsufficientGemsDialog(50);
                      }
                    },
                  ),
                ] else if (_selectedTabIndex == 2) ...[
                  _buildSectionHeader('Profil Çerçeveleri', badge: 'KOZMETİK'),
                  const SizedBox(height: 10),
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
                ] else if (_selectedTabIndex == 3) ...[
                  _buildSectionHeader('Kitap Okuma Temaları', badge: 'CANLI TEST'),
                  const SizedBox(height: 10),
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
                ] else if (_selectedTabIndex == 4) ...[
                  _buildSectionHeader('Prestij & Tac Stilleri', badge: 'LİDERLİK'),
                  const SizedBox(height: 10),
                  _buildCosmeticWardrobeCard(itemId: 'golden_crown', category: 'crown', icon: PhosphorIcons.crownBold, iconColor: const Color(0xFFF59E0B), title: 'Efsanevi Kraliyet Tacı', desc: 'Profilinde ve liderlik tablosunda adının yanında altın taç parıldar.', price: 80),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(int index, String label, IconData icon) {
    final bool isSelected = _selectedTabIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        HapticFeedback.selectionClick();
        if (!mounted) return;
        setState(() => _selectedTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
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
              Text('Prestij Odası & Koleksiyon Dolabı', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: XpShopService.instance.gemsNotifier,
              builder: (context, gems, _) {
                return Container(
                  key: _hudGemsKey,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827), 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: const Color(0xFF38BDF8)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                      const SizedBox(width: 4),
                      Text('$gems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 6),
                      InkWell(onTap: _addDebugGems, child: const Icon(PhosphorIcons.plusBold, color: Color(0xFF38BDF8), size: 14)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<int>(
              valueListenable: XpShopService.instance.xpNotifier,
              builder: (context, xp, _) {
                return Container(
                  key: _hudXpKey,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827), 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 15),
                      const SizedBox(width: 3),
                      Text('$xp XP', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              },
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
      decoration: BoxDecoration(
        color: const Color(0xFF111827), 
        borderRadius: BorderRadius.circular(22), 
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(PhosphorIcons.targetBold, color: Color(0xFF818CF8), size: 22)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -3, duration: 1000.ms),
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

  // --- ACİLİYET ROZETLİ ("Günün Fırsatı ✨") DESTANSI SANDIK KARTI & ABSORBPOINTER ---
  Widget _buildShowcaseChestCard() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B), 
            borderRadius: BorderRadius.circular(22), 
            border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(PhosphorIcons.treasureChestBold, color: Color(0xFFF472B6), size: 26)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
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
              AbsorbPointer(
                absorbing: _isChestOpeningInProgress,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEC4899), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (_isChestOpeningInProgress) return;
                    if (XpShopService.instance.gemsNotifier.value >= 45) {
                      setState(() => _isChestOpeningInProgress = true);
                      try {
                        await XpShopService.instance.spendGems(45);
                        if (!mounted) return;
                        _startChestOpeningCeremony();
                      } finally {
                        if (mounted) {
                          setState(() => _isChestOpeningInProgress = false);
                        }
                      }
                    } else {
                      if (!mounted) return;
                      _showInsufficientGemsDialog(45);
                    }
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('45', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 3),
                      Icon(PhosphorIcons.diamondBold, size: 13, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -8,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF59E0B)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 1)],
            ),
            child: Text('Günün Fırsatı ✨', style: GoogleFonts.outfit(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
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

  // --- METİN KIRILMA KORUMALI (FLEXIBLE + ELLIPSIS) KOZMETİK KARTI ---
  Widget _buildCosmeticWardrobeCard({required String itemId, required String category, required IconData icon, required Color iconColor, required String title, required String desc, required int price}) {
    final bool isOwned = _ownedItems[itemId] ?? false;
    bool isEquipped = category == 'frame' ? (_activeFrame == itemId) : (category == 'crown' ? _hasGoldenCrown : (_activeTheme == itemId));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEquipped ? const Color(0xFF1E1B4B).withValues(alpha: 0.7) : const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isEquipped ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title, 
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (category == 'frame' || category == 'crown') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                        child: Text('Ligde Görünür ✨', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 8.5, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc, 
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isOwned) ...[
            IconButton(
              icon: const Icon(PhosphorIcons.trashBold, color: Color(0xFFEF4444), size: 18),
              tooltip: 'Ürünü Bırak',
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
      decoration: BoxDecoration(
        color: const Color(0xFF111827), 
        borderRadius: BorderRadius.circular(18), 
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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

// -----------------------------------------------------------------------------
// STICKY (SABİT) HEADER DELEGATE
// -----------------------------------------------------------------------------
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 60.0;

  @override
  double get minExtent => 60.0;

  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

// -----------------------------------------------------------------------------
// GACHA 3 AŞAMALI SANDIK AÇILIŞ TÖRENİ
// -----------------------------------------------------------------------------
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

  void _startOpening() {
    if (_crackStage >= 1) return;
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() => _crackStage = 1);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() => _crackStage = 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: _crackStage == 0 ? _startOpening : null,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_crackStage == 0)
                const Icon(PhosphorIcons.treasureChestBold, color: Color(0xFFF472B6), size: 100)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms)
              else if (_crackStage == 1)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFEC4899), blurRadius: 40, spreadRadius: 10)],
                  ),
                  child: const Icon(PhosphorIcons.treasureChestBold, color: Color(0xFFF472B6), size: 100),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .shake(hz: 8, curve: Curves.easeInOut)
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1200.ms)
              else if (_crackStage == 2)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFF59E0B), blurRadius: 60, spreadRadius: 20)],
                  ),
                  child: const Icon(PhosphorIcons.treasureChestBold, color: Color(0xFFF472B6), size: 120),
                )
                    .animate()
                    .scale(curve: Curves.elasticOut, duration: 800.ms)
                    .fadeIn(),
                    
              const SizedBox(height: 30),

              if (_crackStage == 0)
                Text('Açmak İçin Dokun!', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))
                    .animate().fadeIn()
              else if (_crackStage == 1)
                Text('Açılıyor...', style: GoogleFonts.outfit(color: const Color(0xFFF472B6), fontSize: 20, fontWeight: FontWeight.w900))
                    .animate().fadeIn().shake(hz: 4)
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('+${widget.earnedGems}', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 4),
                    const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 28),
                    const SizedBox(width: 16),
                    Text('+${widget.earnedXp} XP', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontSize: 32, fontWeight: FontWeight.w900)),
                  ],
                ).animate().scale(curve: Curves.elasticOut, duration: 800.ms).fadeIn(),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981), 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 8,
                    shadowColor: const Color(0xFF10B981).withValues(alpha: 0.5)
                  ),
                  onPressed: () => widget.onCollect(Offset(screenSize.width / 2, screenSize.height / 2)),
                  child: Text('Topla & Kapat', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
                ).animate().slideY(begin: 1, end: 0, curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DÖNEN VE PARLAYAN UÇAN PARTİKÜL EFEKTİ
// -----------------------------------------------------------------------------
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
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
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
        
        return Positioned(
          left: currentX, 
          top: currentY, 
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: widget.color, blurRadius: 10, spreadRadius: 2)],
            ),
            child: Icon(widget.icon, color: widget.color, size: 24),
          )
          .animate(onPlay: (c) => c.repeat())
          .rotate(duration: 400.ms)
          .scale(begin: const Offset(1.3, 1.3), end: const Offset(0.7, 0.7), duration: 750.ms),
        );
      },
    );
  }
}