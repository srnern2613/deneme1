import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'book_model.dart';
import 'default_books.dart';
import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'flashcards_exercise_screen.dart';
import 'word_boss_battle_screen.dart';
import 'reader_screen.dart';
import 'book_journey_screen.dart';
import 'habit_tracker_screen.dart';
import 'profile_screen.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'xp_shop_service.dart';
import 'database_helper.dart';
import 'streak_freeze_service.dart';
import 'audio_handler.dart';
import 'mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await MyAudioHandler.init();
    await DefaultBooksManager.seedDefaultBooksIfNeeded();
    await XpShopService.instance.init();
  } catch (e) {
    debugPrint('Initialization error: $e');
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

enum ActionPriorityType {
  streakAtRisk,
  wordBoss,
  dueSrs,
  activeBook,
  dailyGoal,
}

class NextBestActionData {
  final ActionPriorityType type;
  final String badgeText;
  final Color badgeColor;
  final Color badgeTextColor;
  final String title;
  final String description;
  final String buttonLabel;
  final IconData buttonIcon;
  final double progressValue;
  final String progressLabel;
  final VoidCallback onAction;

  NextBestActionData({
    required this.type,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.progressValue,
    required this.progressLabel,
    required this.onAction,
  });
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onNavigateToShop;
  final VoidCallback onNavigateToLibrary;
  final VoidCallback onNavigateToFlashcards;

  const DashboardScreen({
    super.key,
    required this.onToggleTheme,
    required this.onNavigateToShop,
    required this.onNavigateToLibrary,
    required this.onNavigateToFlashcards,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _todayLearnedCards = 0;
  int _dailyTargetCards = 5;
  int _dueReviewCount = 0;
  int _currentStreak = 1;
  bool _isStreakProtectedToday = false;
  int _totalReadMinutes = 0;

  List<Map<String, dynamic>> _activePracticeCards = [];
  Map<String, dynamic>? _topBossCard;
  int _activeBossCount = 0;

  Book? _activeBook;
  Map<String, dynamic>? _activeBookStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshDashboardStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    refreshDashboardStats();
  }

  Future<void> refreshDashboardStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = _getTodayKey();

      final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
      final streak = streakResult['streakDays'] ?? (prefs.getInt('current_streak_days') ?? 1);
      
      await XpShopService.instance.getGemsBalance();
      await XpShopService.instance.getTotalXp();

      final learnedToday = prefs.getInt('daily_learned_words_$todayKey') ?? 0;
      final target = prefs.getInt('active_daily_word_target') ?? 5;
      final streakSaved = prefs.getBool('streak_completed_$todayKey') ?? (learnedToday > 0);
      final readMins = prefs.getInt('stats_total_read_minutes') ?? 0;

      final practiceCards = await DatabaseHelper.instance.getActivePracticeCards();
      final reviewCount = practiceCards.where((c) => (c['repetitions'] as int? ?? 0) < 5).length;

      final bossCards = await DatabaseHelper.instance.getActiveBossCards(limit: 1);
      final bossCount = await DatabaseHelper.instance.getActiveBossCount();
      final topBoss = bossCards.isNotEmpty ? bossCards.first : null;

      Book? mostRecentBook;
      Map<String, dynamic>? mostRecentBookStats;

      final bookDataList = prefs.getStringList('saved_books');
      if (bookDataList != null && bookDataList.isNotEmpty) {
        final List<Book> parsedBooks = bookDataList.map((str) => Book.fromJson(str)).toList();
        parsedBooks.sort((a, b) {
          final dateA = a.lastReadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.lastReadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
        if (parsedBooks.isNotEmpty) {
          mostRecentBook = parsedBooks.first;
          mostRecentBookStats = await DatabaseHelper.instance.getBookJourneyData(
            bookTitle: mostRecentBook.title,
            bookId: mostRecentBook.id,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _activePracticeCards = practiceCards;
        _todayLearnedCards = learnedToday;
        _dailyTargetCards = target;
        _dueReviewCount = reviewCount;
        _currentStreak = streak;
        _isStreakProtectedToday = streakSaved;
        _totalReadMinutes = readMins;
        _topBossCard = topBoss;
        _activeBossCount = bossCount;
        _activeBook = mostRecentBook;
        _activeBookStats = mostRecentBookStats;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Günaydın';
    } else if (hour >= 12 && hour < 18) {
      return 'Tünaydın';
    } else {
      return 'İyi Akşamlar';
    }
  }

  NextBestActionData _determineNextBestAction() {
    final nowHour = DateTime.now().hour;
    final isEvening = nowHour >= 17;
    final remainingWords = (_dailyTargetCards - _todayLearnedCards).clamp(0, 999);
    final isGoalCompleted = _todayLearnedCards >= _dailyTargetCards;
    final goalProgress = _dailyTargetCards > 0 ? (_todayLearnedCards / _dailyTargetCards).clamp(0.0, 1.0) : 0.0;

    if (!_isStreakProtectedToday && (isEvening || _currentStreak > 1)) {
      return NextBestActionData(
        type: ActionPriorityType.streakAtRisk,
        badgeText: '🔥 SERİN TEHLİKEDE',
        badgeColor: const Color(0xFFEF4444).withValues(alpha: 0.18),
        badgeTextColor: const Color(0xFFF87171),
        title: 'Serini Korumak İçin 5 Dk Yeter!',
        description: '$_currentStreak günlük serin bugün bozulmasın. 1 kısa pratik yaparak serini güvenceye al.',
        buttonLabel: 'SERİYİ KURTAR',
        buttonIcon: PhosphorIcons.fireBold,
        progressValue: 0.0,
        progressLabel: 'Henüz Pratik Yapılmadı',
        onAction: _startSrsSession,
      );
    }

    if (_topBossCard != null && _activeBossCount > 0) {
      final bossWord = _topBossCard!['word'] as String? ?? 'Kelime';
      final bossLevel = _topBossCard!['boss_level'] as int? ?? 1;

      return NextBestActionData(
        type: ActionPriorityType.wordBoss,
        badgeText: '👹 WORD BOSS TEHDİDİ (L$bossLevel)',
        badgeColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
        badgeTextColor: const Color(0xFFFCA5A5),
        title: '"$bossWord" Seni Zorluyor',
        description: 'Hata yaptığın bu kelime direniyor. Arenada 6 turlu rövanşa çıkıp +20 XP kazan!',
        buttonLabel: 'RÖVANŞA ÇIK',
        buttonIcon: PhosphorIcons.swordBold,
        progressValue: 1.0,
        progressLabel: '$_activeBossCount Aktif Boss',
        onAction: () => _startBossBattle(_topBossCard!),
      );
    }

    if (_dueReviewCount >= 4) {
      return NextBestActionData(
        type: ActionPriorityType.dueSrs,
        badgeText: '🧠 UNUTMA EĞRİSİ ALARMI',
        badgeColor: const Color(0xFF818CF8).withValues(alpha: 0.18),
        badgeTextColor: const Color(0xFFA5B4FC),
        title: '$_dueReviewCount Kelime Tekrar Bekliyor',
        description: 'Öğrendiğin kelimeleri kalıcı hafızaya taşımak için hafıza kartı egzersizini tamamla.',
        buttonLabel: 'SRS TEKRARINA BAŞLA',
        buttonIcon: PhosphorIcons.brainBold,
        progressValue: (_dueReviewCount / 15).clamp(0.0, 1.0),
        progressLabel: '$_dueReviewCount Kelime Bekliyor',
        onAction: _startSrsSession,
      );
    }

    if (_activeBook != null && _activeBookStats != null) {
      final int readingPercent = _activeBookStats!['reading_percentage'] as int? ?? 0;
      if (readingPercent > 0 && readingPercent < 100) {
        return NextBestActionData(
          type: ActionPriorityType.activeBook,
          badgeText: '📖 OKUMA YOLCULUĞU',
          badgeColor: const Color(0xFF38BDF8).withValues(alpha: 0.18),
          badgeTextColor: const Color(0xFF7DD3FC),
          title: '${_activeBook!.title}\'de %$readingPercent\'tesin',
          description: 'Kaldığın yerden okumaya devam et, bilmediğin yeni kelimeleri bağlamında avla.',
          buttonLabel: 'OKUMAYA DEVAM ET',
          buttonIcon: PhosphorIcons.bookOpenBold,
          progressValue: (readingPercent / 100).clamp(0.0, 1.0),
          progressLabel: '%$readingPercent Tamamlandı',
          onAction: () => _openReaderDirectly(_activeBook!),
        );
      }
    }

    return NextBestActionData(
      type: ActionPriorityType.dailyGoal,
      badgeText: _isStreakProtectedToday ? '🎉 BUGÜNKÜ SERİN GÜVENDE' : '🎯 GÜNLÜK HEDEF',
      badgeColor: (_isStreakProtectedToday ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
      badgeTextColor: _isStreakProtectedToday ? const Color(0xFF34D399) : const Color(0xFFFDE68A),
      title: isGoalCompleted ? 'Günlük Hedef Tamamlandı!' : 'Bugün $remainingWords Kelime Hedefin Var',
      description: isGoalCompleted 
          ? 'Harika gidiyorsun! İstersen ekstra pratik yaparak kelimelerini ustalaştırabilirsin.'
          : 'Hafıza kartlarıyla pratik yaparak bugünkü kelime kotanı tamamla.',
      buttonLabel: isGoalCompleted ? 'EKSTRA PRATİK YAP' : 'HEMEN BAŞLA',
      buttonIcon: PhosphorIcons.playBold,
      progressValue: goalProgress,
      progressLabel: '$_todayLearnedCards / $_dailyTargetCards Kelime',
      onAction: _startSrsSession,
    );
  }

  void _startSrsSession() {
    HapticFeedback.heavyImpact();
    if (_activePracticeCards.isEmpty) {
      widget.onNavigateToLibrary();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => FlashcardsExerciseScreen(cards: _activePracticeCards)),
    ).then((_) => refreshDashboardStats());
  }

  void _startBossBattle(Map<String, dynamic> bossCard) {
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => WordBossBattleScreen(bossCard: bossCard)),
    ).then((_) => refreshDashboardStats());
  }

  Future<void> _openReaderDirectly(Book book) async {
    HapticFeedback.selectionClick();
    await Navigator.push<ReadingSessionResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          book: book,
          onPageChanged: (newPage) {
            book.currentPage = newPage;
            book.lastReadDate = DateTime.now();
          },
        ),
      ),
    );
    refreshDashboardStats();
  }

  void _openBookJourneyDirectly(Book book) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookJourneyScreen(
          bookTitle: book.title,
          bookId: book.id,
          author: book.author,
          onContinueReading: () => _openReaderDirectly(book),
        ),
      ),
    ).then((_) => refreshDashboardStats());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
      );
    }

    final action = _determineNextBestAction();
    final bottomSafePadding = MediaQuery.of(context).padding.bottom + 130.0;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20.0, 14.0, 20.0, bottomSafePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPersonalStateHeader(),
              const SizedBox(height: 16),
              _buildHeroNextBestActionCard(action),
              const SizedBox(height: 16),
              if (_activeBook != null) ...[
                _buildActiveBookSection(_activeBook!, _activeBookStats),
                const SizedBox(height: 20),
              ],
              Text(
                'Gelişim ve İlerleme',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 10),
              if (_activeBossCount > 0 && action.type != ActionPriorityType.wordBoss && _topBossCard != null) ...[
                _buildBossQuickBanner(_topBossCard!, _activeBossCount),
                const SizedBox(height: 10),
              ],
              _buildWeeklySummaryBanner(),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())).then((_) => refreshDashboardStats()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
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
                                  child: Text('LİGDE YÜKSEL', style: GoogleFonts.outfit(color: const Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 8.5)),
                                ),
                              ],
                            ),
                            Text('Meydan okumaları tamamla ve ligde kal', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
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

  Widget _buildPersonalStateHeader() {
    final greeting = _getTimeBasedGreeting();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '👋 $greeting, Eren',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Bugün seni bekleyen görevler hazır.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.onNavigateToShop,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          '$gems',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 5),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const HabitTrackerScreen()),
                ).then((_) => refreshDashboardStats());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isStreakProtectedToday ? const Color(0xFF10B981) : Colors.orange,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIcons.fireBold,
                      color: _isStreakProtectedToday ? const Color(0xFF10B981) : Colors.orange,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$_currentStreak G',
                      style: GoogleFonts.outfit(
                        color: _isStreakProtectedToday ? const Color(0xFF10B981) : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            ValueListenableBuilder<int>(
              valueListenable: XpShopService.instance.xpNotifier,
              builder: (context, xp, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '$xp',
                        style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
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

  Widget _buildHeroNextBestActionCard(NextBestActionData action) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.15), blurRadius: 18, offset: const Offset(0, 6)),
        ],
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
                  color: action.badgeColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: action.badgeTextColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  action.badgeText,
                  style: GoogleFonts.outfit(color: action.badgeTextColor, fontWeight: FontWeight.w900, fontSize: 10.5, letterSpacing: 0.3),
                ),
              ),
              Text(
                action.progressLabel,
                style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            action.title,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(
            action.description,
            style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: action.progressValue,
              minHeight: 6,
              backgroundColor: const Color(0xFF070B14),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: action.onAction,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF070B14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: Icon(action.buttonIcon, size: 18),
              label: Text(
                action.buttonLabel,
                style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBookSection(Book book, Map<String, dynamic>? stats) {
    final int totalPages = book.pages.isEmpty ? 1 : book.pages.length;
    final int currentPage = book.currentPage.clamp(0, totalPages);
    final double readingRatio = (currentPage / totalPages).clamp(0.0, 1.0);
    final int readingPercentage = (readingRatio * 100).toInt();

    final int discoveredWords = stats?['total_words'] as int? ?? 0;
    final int masteredWords = stats?['mastered_count'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openBookJourneyDirectly(book),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(book.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14.5, color: Colors.white),
                          ),
                          Text(
                            book.author,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(PhosphorIcons.caretRightBold, size: 15, color: Color(0xFF64748B)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('📖 %$readingPercentage okundu', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
                    Text('Sayfa ${currentPage + 1} / $totalPages', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: readingRatio,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF070B14),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text('🧠 $discoveredWords keşif', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8))),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text('⭐ $masteredWords usta', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 34,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF070B14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => _openReaderDirectly(book),
                        icon: const Icon(PhosphorIcons.playBold, size: 12),
                        label: Text(
                          book.currentPage > 0 ? 'DEVAM ET' : 'OKU',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900),
                        ),
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
  }

  Widget _buildBossQuickBanner(Map<String, dynamic> topBoss, int count) {
    final word = topBoss['word'] as String? ?? 'Kelime';
    final lvl = topBoss['boss_level'] as int? ?? 1;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _startBossBattle(topBoss),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          children: [
            const Text('👹', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Word Boss: "$word" (L$lvl)', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  Text('$count aktif Boss rövanş bekliyor', style: GoogleFonts.inter(color: const Color(0xFFFCA5A5), fontSize: 10.5)),
                ],
              ),
            ),
            const Icon(PhosphorIcons.swordBold, color: Color(0xFFEF4444), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniStatItem(PhosphorIcons.timerBold, '$_totalReadMinutes dk', 'Okuma Süresi', const Color(0xFF38BDF8)),
          Container(height: 24, width: 1, color: const Color(0xFF1F2937)),
          _buildMiniStatItem(PhosphorIcons.brainBold, '$_dueReviewCount Kelime', 'SRS Bekleyen', const Color(0xFF818CF8)),
          Container(height: 24, width: 1, color: const Color(0xFF1F2937)),
          _buildMiniStatItem(PhosphorIcons.fireBold, '$_currentStreak Gün', 'Mevcut Seri', const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildMiniStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(value, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 9.5)),
      ],
    );
  }
}