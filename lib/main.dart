// ============================================================================
// DOSYA ADI: lib/main.dart
// AÇIKLAMA: Draconic Lingua - Boşluğu Alınmış Büyük Logo ve Kontrastlı İlerleme Barları (Tam Kod)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'core/theme/draconic_theme.dart';
import 'book_model.dart';
import 'default_books.dart';
import 'library_screen.dart';
import 'flashcards_screen.dart';
import 'reader_screen.dart';
import 'habit_tracker_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'xp_shop_service.dart';
import 'streak_freeze_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await DefaultBooksManager.seedDefaultBooksIfNeeded();
    await XpShopService.instance.init();
  } catch (e) {
    debugPrint('Servis başlatma hatası: $e');
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
      title: 'Draconic Lingua',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B14),
        extensions: <ThemeExtension<dynamic>>[
          DraconicTheme.highEnd(),
        ],
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
        // Ejderha Rotası V2 — Faz 1: Mağaza sekmesi kalktı; "mağazaya git"
        // kısayolları artık Profil sekmesine yönlendiriyor (Seri Koruma vb.
        // haklar Faz 2'den itibaren Premium/PaywallTrigger üzerinden sunulacak).
        onNavigateToShop: () => _onTabTapped(4),
        onNavigateToLibrary: () => _onTabTapped(1),
        onNavigateToFlashcards: () => _onTabTapped(2),
      ),
      const LibraryScreen(),
      FlashcardsScreen(
        onNavigateToLibrary: () => _onTabTapped(1),
        onNavigateToShop: () => _onTabTapped(4),
      ),
      const LeaderboardScreen(),
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
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF070B14),
          border: Border(top: BorderSide(color: Color(0xFF1F2937), width: 1)),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF070B14),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: const Color(0xFFFDE68A),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.compassBold)), label: 'Ana Sayfa'),
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.bookOpenBold)), label: 'Dersler'),
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.swordBold)), label: 'Kelimeler'),
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.chartBarBold)), label: 'İlerleme'),
            BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(PhosphorIcons.userBold)), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToShop;
  final VoidCallback onNavigateToLibrary;
  final VoidCallback onNavigateToFlashcards;

  const DashboardScreen({
    super.key,
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
  int _currentStreak = 7;
  int _totalReadMinutes = 0;
  bool _isLoading = true;
  List<Book> _userBooks = [];
  Book? _activeBook;

  @override
  void initState() {
    super.initState();
    refreshDashboardStats();
  }

  Future<void> refreshDashboardStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      
      final streakResult = await StreakFreezeService.instance.checkAndUpdateStreak();
      final todayKey = _getTodayKey();
      
      final learnedToday = prefs.getInt('daily_learned_words_$todayKey') ?? 0;
      final target = prefs.getInt('active_daily_word_target') ?? 5;
      final readMins = prefs.getInt('stats_total_read_minutes') ?? 0;
      // Elmas/XP artık uygulamanın tek gerçek kaynağı olan XpShopService
      // üzerinden okunuyor (diğer 6 ekranla birebir aynı kaynak ve
      // ValueNotifier'lar) — eskiden burada kullanılan 'gems_balance' /
      // 'total_xp' anahtarları hiçbir yerde yazılmıyordu, bu yüzden Lobi
      // diğer ekranlarla senkron değildi.
      await XpShopService.instance.getGemsBalance();
      await XpShopService.instance.getTotalXp();

      List<Book> parsedBooks = [];
      final bookDataList = prefs.getStringList('saved_books');
      if (bookDataList != null && bookDataList.isNotEmpty) {
        parsedBooks = bookDataList.map((str) => Book.fromJson(str)).toList();
        parsedBooks.sort((a, b) {
          final dateA = a.lastReadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.lastReadDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
        });
      }

      if (!mounted) return;
      setState(() {
        _currentStreak = streakResult['streakDays'] ?? (prefs.getInt('current_streak_days') ?? 7);
        _todayLearnedCards = learnedToday;
        _dailyTargetCards = target;
        _totalReadMinutes = readMins;
        _userBooks = parsedBooks;
        _activeBook = parsedBooks.isNotEmpty ? parsedBooks.first : null;
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

  Color _getBookBadgeColor(String title) {
    final colors = [
      const Color(0xFF38BDF8),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFFA855F7),
    ];
    return colors[title.length % colors.length];
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE8C99B))),
      );
    }

    final double goalProgress = _dailyTargetCards > 0 ? (_todayLearnedCards / _dailyTargetCards).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14), 
      body: Stack(
        children: [
          // 1. KATMAN: KALE SİLUETLİ ARKA PLAN GÖRSELİ VE KARANLIK GEÇİŞ[cite: 3]
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/lobi_arkaplan.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF070B14).withValues(alpha: 0.3),
                          const Color(0xFF070B14).withValues(alpha: 0.8),
                          const Color(0xFF070B14),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 2. KATMAN: LOBİ İÇERİĞİ[cite: 3]
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. ÜST MARKA (DİKEY LOGO - SCALE İLE BOŞLUKLAR GİDERİLDİ) VE MİNİMALİST HUD ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Sol Taraf: Dikey Logo (Transform.scale ile etrafındaki şeffaf boşluklar kırpılarak büyütüldü)
                      Expanded(
                        flex: 34,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 72,
                            child: Transform.scale(
                              scale: 1.35,
                              alignment: Alignment.centerLeft,
                              child: Image.asset(
                                'assets/images/lobi_logo1.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                errorBuilder: (context, error, stackTrace) => Text(
                                  'Draconic Lingua', 
                                  style: GoogleFonts.lora(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Sağ Taraf: Sayaçlar (Taşma korumalı, optimize edilmiş esnek oran)[cite: 3]
                      // 4-5 haneli değerlere de yer açacak şekilde büyütüldü —
                      // bu artık uygulama genelinde kullanılacak referans
                      // sayaç/rozet tasarımı.
                      Expanded(
                        flex: 66,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // XP Sayaç — XpShopService.instance.xpNotifier'a canlı bağlı,
                            // diğer tüm ekranlarla aynı anda senkron güncellenir.
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: const Color(0xFF1F2937)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(PhosphorIcons.lightningBold, color: Color(0xFF38BDF8), size: 15),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: ValueListenableBuilder<int>(
                                        valueListenable: XpShopService.instance.xpNotifier,
                                        builder: (context, value, _) => Text(_formatNumber(value), overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            // NOT (Ejderha Rotası V2 — Faz 1): Elmas sayacı top bar'dan
                            // kaldırıldı. XpShopService.gemsNotifier ve ilişkili metodlar
                            // (addGems/spendGems) veri modelinde @Deprecated olarak
                            // bırakıldı — okuma yolları kapatılıyor, alan silinmiyor.
                            // Streak Sayaç
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(color: const Color(0xFF1F2937)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(PhosphorIcons.fireBold, color: Color(0xFFF59E0B), size: 15),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text(_formatNumber(_currentStreak), overflow: TextOverflow.ellipsis, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            // Profil İkonu
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                ).then((_) => refreshDashboardStats());
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                                  border: Border.all(color: const Color(0xFF1F2937)),
                                ),
                                child: const Icon(PhosphorIcons.shieldCheckBold, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- 2. HERO DERS KARTI (YÜKSEK KONTRASTLI İLERLEME BARI) ---[cite: 3, 4]
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 190),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF161B2E).withValues(alpha: 0.9), const Color(0xFF0F172A).withValues(alpha: 0.95)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.3), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Görev panosu hissi için sol üst köşede çok soluk bir
                        // pusula/rün süsü — tamamen kararlı, hiçbir dokunma
                        // alanını veya veri akışını etkilemiyor.
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Icon(PhosphorIcons.compassBold, size: 20, color: const Color(0xFFFDE68A).withValues(alpha: 0.15)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(PhosphorIcons.scrollBold, size: 13, color: const Color(0xFFFDE68A).withValues(alpha: 0.8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'GÜNÜN GÖREVİ',
                                    style: GoogleFonts.outfit(color: const Color(0xFFFDE68A).withValues(alpha: 0.85), fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.4),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.55,
                                child: Text(
                                  _activeBook != null ? _activeBook!.title : 'Kelime Egzersizi', 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.lora(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text('Günlük Hedef • $_todayLearnedCards/$_dailyTargetCards Kelime', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: goalProgress,
                                        minHeight: 8,
                                        backgroundColor: const Color(0xFF334155), // Boş kısım için açık kontrast zemin[cite: 4]
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)), // Dolu kısım doygun altın[cite: 4]
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 100),
                                ],
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: () {
                                  if (_activeBook != null) {
                                    _openReaderDirectly(_activeBook!);
                                  } else {
                                    widget.onNavigateToFlashcards();
                                  }
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)]),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(PhosphorIcons.playFill, size: 14, color: Color(0xFF070B14)),
                                      const SizedBox(width: 8),
                                      Text('Derse Başla', style: GoogleFonts.outfit(color: const Color(0xFF070B14), fontWeight: FontWeight.w900, fontSize: 13.5)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: -5,
                          bottom: -5,
                          child: Image.asset('assets/images/ignis_avatar.png', width: 145, height: 165, fit: BoxFit.contain),
                        ),
                        // Mühür/rün rozeti hissi: içi altın gradyanlı küçük
                        // bir mühür ikonu + aynı metin — sade bir pill yerine
                        // "görev panosuna basılmış onay mührü" gibi duruyor.
                        Positioned(
                          top: 15,
                          right: 105,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.45)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(PhosphorIcons.sealCheckBold, size: 11, color: Color(0xFFFDE68A)),
                                const SizedBox(width: 4),
                                Text(
                                  'Sen yaparsın!',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // --- 3. DEVAM EDEN KİTAPLAR (YÜKSEK KONTRASTLI MİNİ BARLAR) ---[cite: 3, 4]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Devam Eden Kitaplar', style: GoogleFonts.lora(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: widget.onNavigateToLibrary,
                        child: Text('Tümünü Gör >', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 115,
                    child: _userBooks.isEmpty
                        ? Center(child: Text('Henüz kitap eklenmedi.', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12)))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _userBooks.length,
                            itemBuilder: (context, index) {
                              final book = _userBooks[index];
                              final totalPages = book.pages.isEmpty ? 1 : book.pages.length;
                              final progress = (book.currentPage / totalPages).clamp(0.0, 1.0);
                              final percent = (progress * 100).toInt();
                              final isSelected = index == 0;
                              final badgeColor = _getBookBadgeColor(book.title);

                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () => _openReaderDirectly(book),
                                  child: Container(
                                    width: 110,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFFDE68A) : const Color(0xFF1F2937),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), blurRadius: 12)]
                                          : [],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                                          ),
                                          child: Center(
                                            child: Text(
                                              book.title.isNotEmpty ? book.title[0].toUpperCase() : 'B',
                                              style: GoogleFonts.lora(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text('%$percent okundu', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10)),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 4,
                                            backgroundColor: const Color(0xFF334155), // Açık kontrast zemin[cite: 4]
                                            valueColor: AlwaysStoppedAnimation<Color>(isSelected ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8)), // Doygun renk[cite: 4]
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 28),

                  // --- 4. GÜNLÜK SERİ MÜHÜR ÇUBUĞU ---[cite: 3]
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Color(0xFF1E293B), shape: BoxShape.circle),
                                  child: const Icon(PhosphorIcons.fireBold, color: Color(0xFFF59E0B), size: 16),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Günlük Seri', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
                                    Text('Devam et!', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const HabitTrackerScreen()),
                                ).then((_) => refreshDashboardStats());
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text('$_currentStreak', style: GoogleFonts.lora(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  Text('gün >', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (index) {
                            final isCompleted = index < (_currentStreak % 7 == 0 && _currentStreak > 0 ? 7 : _currentStreak % 7);
                            return Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCompleted ? const Color(0xFFFDE68A) : const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                border: Border.all(color: isCompleted ? const Color(0xFFF59E0B) : const Color(0xFF334155), width: 1.5),
                                boxShadow: isCompleted ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 8)] : [],
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(PhosphorIcons.checkBold, color: Color(0xFF070B14), size: 15)
                                    : null,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- 5. GELİŞİM İSTATİSTİKLERİ ---[cite: 3]
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1F2937)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Row(
                              children: [
                                const Icon(PhosphorIcons.timerBold, size: 14, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 6),
                                Text('$_totalReadMinutes dk', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Okuma Süresi', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10)),
                          ],
                        ),
                        Container(height: 24, width: 1, color: const Color(0xFF1F2937)),
                        Column(
                          children: [
                            Row(
                              children: [
                                const Icon(PhosphorIcons.bookOpenTextBold, size: 14, color: Color(0xFFFDE68A)),
                                const SizedBox(width: 6),
                                Text('${_userBooks.length}', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Aktif Kitap', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}