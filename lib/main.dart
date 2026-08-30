// ============================================================================
// DOSYA ADI: lib/main.dart
// AÇIKLAMA: Senkronize Üst Bar ve Semantik Renkli Lobi Mimarisi
// ============================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'flashcards_exercise_screen.dart';
import 'habit_tracker_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'xp_shop_service.dart';
import 'database_helper.dart';
import 'audio_handler.dart';
import 'mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await MyAudioHandler.init();
  } catch (e) {
    debugPrint('AudioService error: $e');
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
  final ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kişisel Gelişim & Okuma',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          primary: const Color(0xFFF59E0B),
          secondary: const Color(0xFF10B981),
          surface: const Color(0xFF131B2E),
        ),
      ),
      themeMode: _themeMode,
      home: RootScreen(onToggleTheme: _toggleTheme),
    );
  }
}

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
        onNavigateToLibrary: () => _onTabTapped(1),
        onNavigateToFlashcards: () => _onTabTapped(2),
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
      _dashboardKey.currentState?.refreshDashboardStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSystemPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 84 + bottomSystemPadding,
            child: const GlobalMiniPlayer(),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: bottomSystemPadding > 0 ? bottomSystemPadding + 4 : 12,
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
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(index: 0, icon: PhosphorIcons.compassBold, label: 'Lobi', activeColor: const Color(0xFF38BDF8)),
                    _buildNavItem(index: 1, icon: PhosphorIcons.booksBold, label: 'Kitaplık', activeColor: const Color(0xFF10B981)),
                    const SizedBox(width: 54),
                    _buildNavItem(index: 3, icon: PhosphorIcons.storefrontBold, label: 'Mağaza', activeColor: const Color(0xFFEC4899), hasBadge: true),
                    _buildNavItem(index: 4, icon: PhosphorIcons.userBold, label: 'Profil', activeColor: const Color(0xFFA855F7)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: 2, child: _buildCenterActionCrystal()),
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
          gradient: LinearGradient(
            colors: isSelected
                ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                : [const Color(0xFFD97706), const Color(0xFFB45309)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFFFDE68A),
            width: isSelected ? 2.5 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: isSelected ? 0.65 : 0.3),
              blurRadius: isSelected ? 20 : 10,
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

  Widget _buildNavItem({required int index, required IconData icon, required String label, required Color activeColor, bool hasBadge = false}) {
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
                  child: Icon(icon, size: 21, color: isSelected ? activeColor : const Color(0xFF64748B)),
                ),
                if (hasBadge && !isSelected)
                  Positioned(
                    right: -3,
                    top: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: Color(0xFFEC4899), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, color: isSelected ? Colors.white : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onNavigateToShop;
  final VoidCallback onNavigateToLibrary;
  final VoidCallback onNavigateToFlashcards;

  const DashboardScreen({super.key, required this.onToggleTheme, required this.onNavigateToShop, required this.onNavigateToLibrary, required this.onNavigateToFlashcards});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _todayLearnedCards = 0;
  int _dailyTargetCards = 5;
  int _dueReviewCount = 0;
  int _currentStreak = 1;
  bool _isStreakProtectedToday = false;
  int _userGems = 50;
  int _userTotalXp = 100;
  List<Map<String, dynamic>> _allCards = [];

  @override
  void initState() {
    super.initState();
    refreshDashboardStats();
  }

  Future<void> refreshDashboardStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _getTodayKey();
      final cards = await DatabaseHelper.instance.getFlashcards();
      final gems = await XpShopService.instance.getGemsBalance();
      final xp = await XpShopService.instance.getTotalXp();

      final learnedToday = prefs.getInt('daily_learned_words_$todayKey') ?? 0;
      final target = prefs.getInt('active_daily_word_target') ?? 5;
      final streak = prefs.getInt('current_streak_days') ?? 1;
      final streakSaved = prefs.getBool('streak_completed_$todayKey') ?? (learnedToday > 0);
      final reviewCount = cards.where((c) => (c['repetitions'] as int? ?? 0) < 5).length;

      if (!mounted) return;
      setState(() {
        _allCards = cards;
        _todayLearnedCards = learnedToday;
        _dailyTargetCards = target;
        _dueReviewCount = reviewCount;
        _currentStreak = streak;
        _isStreakProtectedToday = streakSaved;
        _userGems = gems;
        _userTotalXp = xp;
      });
    } catch (_) {}
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _startHeroAction() {
    HapticFeedback.heavyImpact();
    if (_allCards.isEmpty) {
      widget.onNavigateToLibrary();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => FlashcardsExerciseScreen(cards: _allCards)),
    ).then((_) => refreshDashboardStats());
  }

  @override
  Widget build(BuildContext context) {
    final remainingWords = (_dailyTargetCards - _todayLearnedCards).clamp(0, 999);
    final isGoalCompleted = _todayLearnedCards >= _dailyTargetCards;
    final goalProgress = _dailyTargetCards > 0 ? (_todayLearnedCards / _dailyTargetCards).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 110.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: widget.onNavigateToShop,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                              const SizedBox(width: 5),
                              Text('$_userGems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const HabitTrackerScreen()),
                          ).then((_) => refreshDashboardStats());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _isStreakProtectedToday ? const Color(0xFF10B981) : Colors.orange, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.fireBold, color: _isStreakProtectedToday ? const Color(0xFF10B981) : Colors.orange, size: 15),
                              const SizedBox(width: 5),
                              Text('$_currentStreak gün', style: GoogleFonts.outfit(color: _isStreakProtectedToday ? const Color(0xFF10B981) : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 15),
                        const SizedBox(width: 4),
                        Text('$_userTotalXp XP', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.65), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_isStreakProtectedToday ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isStreakProtectedToday ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                          ),
                          child: Text(
                            _isStreakProtectedToday ? 'BUGÜNKÜ SERİN GÜVENDE' : 'SERİ İÇİN 1 PRATİK YAP',
                            style: GoogleFonts.outfit(color: _isStreakProtectedToday ? const Color(0xFF34D399) : const Color(0xFFFDE68A), fontWeight: FontWeight.w800, fontSize: 10.5),
                          ),
                        ),
                        Text('Hedef: $_todayLearnedCards / $_dailyTargetCards', style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isGoalCompleted ? '🎉 Günlük Hedef Tamamlandı!' : 'Bugünün Hedefi: $remainingWords Kelime Kaldı',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: goalProgress,
                        minHeight: 8,
                        backgroundColor: const Color(0xFF070B14),
                        valueColor: AlwaysStoppedAnimation<Color>(isGoalCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _startHeroAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF070B14),
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(PhosphorIcons.playBold, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isGoalCompleted ? 'EKSTRA PRATİK YAP' : 'HEMEN BAŞLA',
                              style: GoogleFonts.outfit(fontSize: 15.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Öğrenme & İlerleme Durumu', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: widget.onNavigateToFlashcards,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF1F2937))),
                  child: Row(
                    children: [
                      const Icon(PhosphorIcons.brainBold, color: Color(0xFF818CF8), size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_dueReviewCount kelime tekrar bekliyor', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                            Text('SRS algoritmasıyla hafızanı canlı tut', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF64748B), size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())).then((_) => refreshDashboardStats()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3))),
                  child: Row(
                    children: [
                      const Icon(PhosphorIcons.trophyBold, color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('12. Arena • 4. Sıra', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(5)),
                                  child: Text('GÖREVLERİ GÖR', style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 8.5)),
                                ),
                              ],
                            ),
                            Text('Meydan okumaları tamamla ve ligde yüksel', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF64748B), size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: widget.onNavigateToLibrary,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
                  child: Row(
                    children: [
                      const Icon(PhosphorIcons.booksBold, color: Color(0xFF34D399), size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kitap Okuyarak Kelime Yakala', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5)),
                            Text('Alice Harikalar Diyarında & Diğerleri', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                      ),
                      const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF64748B), size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}