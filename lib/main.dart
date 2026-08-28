// ============================================================================
// DOSYA ADI: lib/main.dart
// AÇIKLAMA: Nihai Oyunlaştırma Mimarisi - 3D Aksiyon Kristali & Neon Alt Göstergeli Bar
// ============================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

// --- UYGULAMA İÇİ EKRAN VE SERVİS BAĞLANTILARI ---
import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'habit_tracker_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'xp_shop_service.dart';
import 'audio_handler.dart';
import 'mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await MyAudioHandler.init();
  } catch (e) {
    debugPrint('AudioService başlatma hatası: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    HapticFeedback.lightImpact();
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kişisel Gelişim & Okuma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF10B981),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          primary: const Color(0xFF818CF8),
          secondary: const Color(0xFF34D399),
          surface: const Color(0xFF131B2E),
        ),
      ),
      themeMode: _themeMode,
      home: RootScreen(onToggleTheme: _toggleTheme),
    );
  }
}

// ============================================================================
// SINIF: RootScreen (Ana Navigasyon Yöneticisi)
// ============================================================================
class RootScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const RootScreen({super.key, required this.onToggleTheme});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;
  final GlobalKey<_DashboardScreenState> _dashboardKey = GlobalKey<_DashboardScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        key: _dashboardKey,
        onToggleTheme: widget.onToggleTheme,
        onNavigateToShop: () => _onTabTapped(3),
      ),
      const LibraryScreen(),
      const FlashcardsScreen(),
      const ShopScreen(),
      const ProfileScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      _dashboardKey.currentState?.refreshReadingStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // 1. KATMAN: Ekranlar
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),

          // 2. KATMAN: Mini Player
          const Positioned(
            left: 0,
            right: 0,
            bottom: 84,
            child: GlobalMiniPlayer(),
          ),

          // 3. KATMAN: Yüzen Nihai Oyunlaştırma Alt Barı
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: _buildUltimateBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildUltimateBottomBar() {
    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Arka Buzlu Cam Gövde
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: PhosphorIcons.compassBold,
                      label: 'Keşfet',
                      activeColor: const Color(0xFF38BDF8),
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: PhosphorIcons.booksBold,
                      label: 'Kitaplık',
                      activeColor: const Color(0xFF34D399),
                    ),
                    
                    // Orta buton yerleşim boşluğu
                    const SizedBox(width: 54),

                    _buildNavItem(
                      index: 3,
                      icon: PhosphorIcons.storefrontBold,
                      label: 'Mağaza',
                      activeColor: const Color(0xFFEC4899),
                      hasBadge: true,
                    ),
                    _buildNavItem(
                      index: 4,
                      icon: PhosphorIcons.userBold,
                      label: 'Profil',
                      activeColor: const Color(0xFFA855F7),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Merkez: 3D Aksiyon & Düello Kristal Butonu
          Positioned(
            top: 2,
            child: _buildCenterActionCrystal(),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterActionCrystal() {
    final isSelected = _currentIndex == 2;

    return GestureDetector(
      onTap: () => _onTabTapped(2),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: isSelected ? 58 : 54,
        height: isSelected ? 58 : 54,
        decoration: BoxDecoration(
          // Mor / İndigo Aksiyon Kristali Gradyanı
          gradient: LinearGradient(
            colors: isSelected
                ? [const Color(0xFF818CF8), const Color(0xFF4F46E5)]
                : [const Color(0xFF6366F1), const Color(0xFF3730A3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFFA5B4FC),
            width: isSelected ? 2.5 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: isSelected ? 0.65 : 0.4),
              blurRadius: isSelected ? 20 : 12,
              spreadRadius: isSelected ? 3 : 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            PhosphorIcons.swordBold,
            color: Colors.white,
            size: isSelected ? 28 : 25,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
    bool hasBadge = false,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    icon,
                    size: 21,
                    color: isSelected ? activeColor : const Color(0xFF64748B),
                  ),
                ),
                if (hasBadge && !isSelected)
                  Positioned(
                    right: -3,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC4899),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.8),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            // Şık Neon Alt Çizgi İndikatörü
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 12 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [BoxShadow(color: activeColor.withValues(alpha: 0.8), blurRadius: 4, spreadRadius: 0.5)]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SINIF: DashboardScreen (Ana Lobi / Keşfet Sekmesi)
// ============================================================================
class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onNavigateToShop;
  const DashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.onNavigateToShop,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _todayPages = 0;
  int _readingTargetPages = 20;
  int _currentStreak = 1;
  int _userGems = 50;

  @override
  void initState() {
    super.initState();
    refreshReadingStats();
  }

  Future<void> refreshReadingStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _getTodayKey();

      final pages = prefs.getInt('daily_pages_$todayKey') ?? 0;
      final target = prefs.getInt('active_reading_target_pages') ?? 20;
      final streak = prefs.getInt('current_streak_days') ?? 1;
      final gems = await XpShopService.instance.getGemsBalance();

      final goalRewardClaimed = prefs.getBool('goal_reward_claimed_$todayKey') ?? false;
      if (pages >= target && !goalRewardClaimed && pages > 0) {
        await prefs.setBool('goal_reward_claimed_$todayKey', true);
        await XpShopService.instance.addGems(15);
      }

      if (!mounted) return;
      setState(() {
        _todayPages = pages;
        _readingTargetPages = target;
        _currentStreak = streak;
        _userGems = gems;
      });
    } catch (_) {}
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final goalProgress = (_readingTargetPages > 0)
        ? (_todayPages / _readingTargetPages).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.15), blurRadius: 100, spreadRadius: 50),
                ],
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.08), blurRadius: 120, spreadRadius: 60),
                ],
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 105.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. ÜST HUD & STATÜ PANELI ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: widget.onNavigateToShop,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                                  const SizedBox(width: 5),
                                  Text('$_userGems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.2), shape: BoxShape.circle),
                                    child: const Icon(PhosphorIcons.plusBold, color: Color(0xFF38BDF8), size: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (context) => const HabitTrackerScreen()));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  const Icon(PhosphorIcons.fireBold, color: Colors.orange, size: 15)
                                      .animate(onPlay: (c) => c.repeat(reverse: true))
                                      .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
                                  const SizedBox(width: 5),
                                  Text('$_currentStreak gün', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), shape: BoxShape.circle),
                                    child: const Icon(PhosphorIcons.plusBold, color: Colors.orange, size: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                        ),
                        child: const Icon(PhosphorIcons.trophyBold, color: Color(0xFFF59E0B), size: 18),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 18),

                  // --- 2. ARENA / LİG KARTI ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1E1B4B).withValues(alpha: 0.9), const Color(0xFF0F172A).withValues(alpha: 0.9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'SEZON 3 • 4 GÜN KALDI',
                                style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.w800, fontSize: 10),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(PhosphorIcons.trendUpBold, color: Color(0xFFEF4444), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Ligde 4. Sıradısın!',
                                  style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '12. Arena - Kelime Ustası',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1. ile aranda 50 XP var, hemen geç!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(
                            value: 0.65,
                            minHeight: 10,
                            backgroundColor: Color(0xFF0F172A),
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- 3. GÜNLÜK GİZEMLİ SANDIK ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(PhosphorIcons.giftBold, color: Color(0xFF34D399), size: 22)
                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                  .rotate(duration: 1000.ms, begin: -0.05, end: 0.05),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Günlük Gizemli Sandık', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text('ÖDÜLLÜ', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 9)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('$_todayPages / $_readingTargetPages sayfa okundu', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5)),
                                ],
                              ),
                            ),
                            const Icon(PhosphorIcons.lockKeyBold, color: Color(0xFF34D399), size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: goalProgress,
                            minHeight: 5,
                            backgroundColor: const Color(0xFF1F2937),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- 4. HIZLI AKSİYON IZGARASI ---
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const FlashcardsScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF1F2937)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(PhosphorIcons.swordBold, color: Color(0xFFEC4899), size: 20),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                                      ),
                                      child: Text('CANLI', style: GoogleFonts.outfit(color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w900, fontSize: 8.5)),
                                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 600.ms, begin: 0.5, end: 1.0),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text('Kelime Düellosu', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text('Hızlı Savaş', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LibraryScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF1F2937)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(PhosphorIcons.targetBold, color: Color(0xFF38BDF8), size: 20),
                                ),
                                const SizedBox(height: 12),
                                Text('Kitaplığım', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text('PDF & Okuma', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // --- 5. ANA ÇAĞRI BUTONU ---
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            Navigator.of(context).push(MaterialPageRoute(builder: (context) => const LibraryScreen()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 8,
                            shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(PhosphorIcons.lightningBold, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'HIZLI PRATİK BAŞLAT',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                              ),
                            ],
                          ),
                        ),
                      ).animate().scale(duration: 200.ms),
                      const SizedBox(height: 6),
                      Text(
                        '⚡ Hemen başla, +50 XP ve serini garantile!',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}