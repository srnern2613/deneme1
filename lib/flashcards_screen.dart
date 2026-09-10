// ============================================================================
// DOSYA ADI: lib/flashcards_screen.dart
// AÇIKLAMA: Pratik Ekranı, RPG Hafıza Zindanı, FOMO Sayacı, Soft Paywall (Kilit),
//            Dinamik 2X XP Rotasyonu, Asenkron XP Modalı, 2x2 Grid ve Test Modu
// ============================================================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'database_helper.dart';
import 'flashcards_exercise_screen.dart';
import 'quiz_exercise_screen.dart';
import 'match_exercise_screen.dart';
import 'spelling_exercise_screen.dart';
import 'word_boss_battle_screen.dart';
import 'xp_shop_service.dart';

class FlashcardsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLibrary;
  final VoidCallback? onNavigateToShop;

  const FlashcardsScreen({
    super.key, 
    this.onNavigateToLibrary, 
    this.onNavigateToShop,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _bossCards = [];
  bool _isLoading = true;

  int _totalValidPoolCount = 0; 
  int _sessionLimit = 0;
  String _learningStateFilter = 'ALL';
  bool _isTestModeActive = false; // Geliştirici Test Modu

  late Timer _fomoTimer;
  String _fomoTimeLeft = "00:00";
  int _dailyDoubleXpIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _calculateDailyDoubleXp();
    _loadSettingsAndCards();
    _startFomoTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fomoTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _calculateDailyDoubleXp();
      _loadSettingsAndCards();
    }
  }

  // GÜNLÜK 2X XP ROTASYON ALGORİTMASI (SEED BAZLI)
  void _calculateDailyDoubleXp() {
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    setState(() {
      _dailyDoubleXpIndex = seed % 4; // 0: Quiz, 1: SRS, 2: Match, 3: Spelling
    });
  }

  void _startFomoTimer() {
    _updateFomoTime();
    _fomoTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _updateFomoTime();
    });
  }

  void _updateFomoTime() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    setState(() {
      _fomoTimeLeft = "${diff.inHours}s ${diff.inMinutes % 60}dk";
    });
  }

  Future<void> _loadSettingsAndCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      
      setState(() {
        _sessionLimit = prefs.getInt('arena_session_limit') ?? 0;
        _learningStateFilter = prefs.getString('arena_state_filter') ?? 'ALL';
        _isTestModeActive = prefs.getBool('dev_test_mode') ?? false;
      });

      await _loadCardsAndStats();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCardsAndStats() async {
    try {
      var allValidCards = await DatabaseHelper.instance.getActivePracticeCards();
      final bossCards = await DatabaseHelper.instance.getActiveBossCards(limit: 3);
      await XpShopService.instance.getGemsBalance();
      await XpShopService.instance.getTotalXp();

      if (!mounted) return;
      
      // Mutlak toplam pratik kartı sayısı (Kilitler bu değere bakacak)
      _totalValidPoolCount = allValidCards.length;

      // Egzersiz seansı için filtreleme (Koleksiyon filtresi sadece listeyi daraltır)
      var sessionCards = List<Map<String, dynamic>>.from(allValidCards);
      if (_learningStateFilter == 'LEARNING') {
        sessionCards = sessionCards.where((c) => c['learning_state'] == 'LEARNING').toList();
      }

      if (_sessionLimit > 0 && sessionCards.length > _sessionLimit) {
        sessionCards = sessionCards.sublist(0, _sessionLimit);
      }

      if (!mounted) return;
      setState(() {
        _cards = sessionCards.isNotEmpty ? sessionCards : allValidCards; // Eğer filtrelenen liste boşsa tüm havuzu koru
        _bossCards = bossCards;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // --- ARENA AYARLARI VE TEST MODU ---
  void _openArenaSettings() {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(PhosphorIcons.gearSixBold, color: Color(0xFFF59E0B), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Arena Pratik Ayarları',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SEANS BAŞINA KART LİMİTİ',
                    style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLimitChip(setModalState, 0, 'Tümü'),
                      _buildLimitChip(setModalState, 10, '10 Kart'),
                      _buildLimitChip(setModalState, 20, '20 Kart'),
                      _buildLimitChip(setModalState, 30, '30 Kart'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'KOLEKSİYON FİLTRESİ',
                    style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStateChip(setModalState, 'ALL', 'Tüm Kelimeler'),
                      const SizedBox(width: 8),
                      _buildStateChip(setModalState, 'LEARNING', 'Sadece Öğrenilenler'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // --- GELİŞTİRİCİ TEST MODU (KİLİTLERİ AÇAR) ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(PhosphorIcons.bugBold, color: Color(0xFFEF4444), size: 20),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Geliştirici Test Modu', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Tüm kilitleri anında açar', style: GoogleFonts.inter(color: const Color(0xFFFCA5A5), fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _isTestModeActive,
                          activeThumbColor: const Color(0xFFEF4444),
                          onChanged: (val) async {
                            HapticFeedback.heavyImpact();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('dev_test_mode', val);
                            setModalState(() => _isTestModeActive = val);
                            setState(() => _isTestModeActive = val); 
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF070B14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                        final prefs = await SharedPreferences.getInstance();
                        if (!mounted) return;
                        await prefs.setInt('arena_session_limit', _sessionLimit);
                        await prefs.setString('arena_state_filter', _learningStateFilter);
                        if (!mounted) return;
                        _loadCardsAndStats();
                      },
                      child: Text('Kaydet ve Kapat', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLimitChip(StateSetter setModalState, int limitValue, String label) {
    final isSelected = _sessionLimit == limitValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setModalState(() => _sessionLimit = limitValue);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: isSelected ? null : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent, 
              width: 1.5
            ),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? const Color(0xFF070B14) : Colors.white,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateChip(StateSetter setModalState, String stateValue, String label) {
    final isSelected = _learningStateFilter == stateValue;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setModalState(() => _learningStateFilter = stateValue);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: isSelected ? null : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent, 
              width: 1.5
            ),
            boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? const Color(0xFF070B14) : Colors.white,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showXpSummaryModal() async {
    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 150));
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Icon(PhosphorIcons.trophyBold, color: Color(0xFFF59E0B), size: 48)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
              const SizedBox(height: 16),
              Text('Günlük Deneyim (XP) Raporu', style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('Arenadaki başarıların ve okuma süren XP\'ye dönüştü. Ligde yükselmek için mücadeleye devam et!', textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF334155))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Mevcut Lig:', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Altın Arena (4. Sıra)', style: GoogleFonts.outfit(color: const Color(0xFFFDE68A), fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: Text('Kapat', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToLibraryRoot() {
    HapticFeedback.lightImpact();
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.onNavigateToLibrary?.call();
  }

  void _startSrsExercise() {
    HapticFeedback.mediumImpact();
    final multiplier = _dailyDoubleXpIndex == 1 ? 2 : 1;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => FlashcardsExerciseScreen(cards: _cards, xpMultiplier: multiplier)
    )).then((_) {
      if (mounted) _loadCardsAndStats();
    });
  }

  void _startQuizExercise() {
    HapticFeedback.mediumImpact();
    final multiplier = _dailyDoubleXpIndex == 0 ? 2 : 1;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => QuizExerciseScreen(cards: _cards, xpMultiplier: multiplier)
    )).then((_) {
      if (mounted) _loadCardsAndStats();
    });
  }

  void _startMatchExercise() {
    HapticFeedback.mediumImpact();
    final multiplier = _dailyDoubleXpIndex == 2 ? 2 : 1;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => MatchExerciseScreen(cards: _cards, xpMultiplier: multiplier)
    )).then((_) {
      if (mounted) _loadCardsAndStats();
    });
  }

  void _startSpellingExerciseWithPaywall() {
    if (!_isTestModeActive && _totalValidPoolCount < 20) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Önce okuyarak ${20 - _totalValidPoolCount} kelime daha topla (Şu an: $_totalValidPoolCount/20) 📖', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    HapticFeedback.mediumImpact();
    final multiplier = _dailyDoubleXpIndex == 3 ? 2 : 1;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => SpellingExerciseScreen(cards: _cards, xpMultiplier: multiplier)
    )).then((_) {
      if (mounted) _loadCardsAndStats();
    });
  }

  void _startBossBattle(Map<String, dynamic> bossCard) {
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => WordBossBattleScreen(bossCard: bossCard))).then((_) {
      if (mounted) _loadCardsAndStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModernHeader(),
                    const SizedBox(height: 18),
                    _buildDynamicBossBanner(),
                    _buildMemoryDungeonHero(),
                    const SizedBox(height: 24),
                    Text('Öğrenme & Oyun Modları', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3)),
                    const SizedBox(height: 14),
                    
                    // --- 2x2 KARESEL GRID (IZGARA) MİMARİSİ ---
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85,
                      children: [
                        _buildGridPracticeCard(
                          icon: PhosphorIcons.lightningBold,
                          title: 'Hızlı Test',
                          desc: '4 seçenek arasından doğru anlamı yakala.',
                          reward: _dailyDoubleXpIndex == 0 ? '2X XP' : '+6 XP',
                          fomoLabel: _dailyDoubleXpIndex == 0 ? 'Son $_fomoTimeLeft' : null,
                          accentColor: const Color(0xFF38BDF8),
                          onTap: (_isTestModeActive || _totalValidPoolCount >= 4) ? _startQuizExercise : null,
                          isLocked: !_isTestModeActive && _totalValidPoolCount < 4,
                          lockMessage: '4 Kelime Gerekli',
                        ),
                        _buildGridPracticeCard(
                          icon: PhosphorIcons.cardsBold,
                          title: 'SRS Hafıza',
                          desc: 'Aralıklı tekrar algoritması ile hafızanı tazele.',
                          reward: _dailyDoubleXpIndex == 1 ? '2X XP' : '+5 XP',
                          fomoLabel: _dailyDoubleXpIndex == 1 ? 'Son $_fomoTimeLeft' : null,
                          accentColor: const Color(0xFFA855F7),
                          onTap: (_isTestModeActive || _totalValidPoolCount >= 1) ? _startSrsExercise : null,
                          isLocked: !_isTestModeActive && _totalValidPoolCount < 1,
                          lockMessage: '1 Kelime Gerekli',
                        ),
                        _buildGridPracticeCard(
                          icon: PhosphorIcons.puzzlePieceBold,
                          title: 'Eşleştirme',
                          desc: 'Blokları eşleştirerek tahtayı temizle.',
                          reward: _dailyDoubleXpIndex == 2 ? '2X XP' : '+10 XP',
                          fomoLabel: _dailyDoubleXpIndex == 2 ? 'Son $_fomoTimeLeft' : null,
                          accentColor: const Color(0xFF6366F1),
                          onTap: (_isTestModeActive || _totalValidPoolCount >= 4) ? _startMatchExercise : null,
                          isLocked: !_isTestModeActive && _totalValidPoolCount < 4,
                          lockMessage: '4 Kelime Gerekli',
                        ),
                        _buildGridPracticeCard(
                          icon: PhosphorIcons.headphonesBold,
                          title: 'Dinle & Yaz',
                          desc: 'Telaffuzu dinle, kelimenin imlasını çöz.',
                          reward: _dailyDoubleXpIndex == 3 ? '2X XP' : '+15 XP',
                          fomoLabel: _dailyDoubleXpIndex == 3 ? 'Son $_fomoTimeLeft' : null,
                          accentColor: const Color(0xFF10B981),
                          onTap: _startSpellingExerciseWithPaywall,
                          isLocked: !_isTestModeActive && _totalValidPoolCount < 20,
                          lockMessage: '20 Kelime Gerekli',
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMemoryDungeonHero() {
    final bool isPoolEmpty = !_isTestModeActive && _totalValidPoolCount < 4;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPoolEmpty 
            ? [const Color(0xFF1F1123), const Color(0xFF0F172A)]
            : [const Color(0xFFD97706), const Color(0xFFB45309)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isPoolEmpty ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFFDE68A).withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: (isPoolEmpty ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(isPoolEmpty ? PhosphorIcons.bookOpenTextBold : PhosphorIcons.swordBold, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPoolEmpty ? 'Zindan Kapalı!' : 'Hafıza Zindanı (SRS)',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPoolEmpty ? 'Girmek için önce kitaplıkta avlanmalısın.' : '${_cards.length} kelime aralıklı tekrar bekliyor.',
                      style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isPoolEmpty ? const Color(0xFFEF4444) : const Color(0xFF070B14),
                foregroundColor: isPoolEmpty ? Colors.white : const Color(0xFFFDE68A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: isPoolEmpty ? _navigateToLibraryRoot : _startSrsExercise,
              child: Text(
                isPoolEmpty ? 'KİTAPLIĞA GİT VE AVLAN 🏹' : 'ZİNDANA GİR ⚔️',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2x2 GRID UYUMLU KART TASARIMI VE SOFT PAYWALL KİLİDİ ---
  Widget _buildGridPracticeCard({
    required IconData icon,
    required String title,
    required String desc,
    required String reward,
    required Color accentColor,
    required VoidCallback? onTap,
    bool isLocked = false,
    String? lockMessage,
    String? fomoLabel,
  }) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: fomoLabel != null ? const Color(0xFFF59E0B).withValues(alpha: 0.6) : const Color(0xFF1F2937), 
              width: fomoLabel != null ? 2.0 : 1.5
            ),
            boxShadow: fomoLabel != null ? [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 1)] : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: accentColor, size: 22),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (fomoLabel != null && fomoLabel.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                                child: Text(fomoLabel, style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFFFCA5A5))),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: fomoLabel != null ? const Color(0xFFF59E0B) : accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                reward,
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: fomoLabel != null ? const Color(0xFF070B14) : accentColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        desc,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), height: 1.3),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // SOFT PAYWALL KİLİT KATMANI
        if (isLocked)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(
                    color: const Color(0xFF070B14).withValues(alpha: 0.78),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIcons.lockKeyBold, color: Color(0xFF94A3B8), size: 26),
                          if (lockMessage != null) ...[
                            const SizedBox(height: 4),
                            Text(lockMessage, style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModernHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Arena', style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                if (_isTestModeActive)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(6)),
                    child: Text('TEST AÇIK', style: GoogleFonts.outfit(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
            Text('Kelime Arenası & Oyunlar', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        Row(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: XpShopService.instance.gemsNotifier,
              builder: (context, gems, _) {
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: widget.onNavigateToShop,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8)),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIcons.diamondBold, color: Color(0xFF38BDF8), size: 15),
                        const SizedBox(width: 5),
                        Text('$gems', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 4),
                        const Icon(PhosphorIcons.plusBold, color: Color(0xFF38BDF8), size: 12),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: XpShopService.instance.xpNotifier,
              builder: (context, xp, _) {
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _showXpSummaryModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 15),
                        const SizedBox(width: 4),
                        Text('$xp XP', style: GoogleFonts.outfit(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            // --- ARENA AYARLARI BUTONU (SLIDERS) ---
            GestureDetector(
              onTap: _openArenaSettings,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Icon(PhosphorIcons.slidersBold, color: Color(0xFF38BDF8), size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDynamicBossBanner() {
    if (_bossCards.isEmpty) {
      return const SizedBox.shrink();
    }

    final topBoss = _bossCards.first;
    final bossWord = topBoss['word'] as String? ?? '';
    final bossLevel = topBoss['boss_level'] as int? ?? 1;

    Color badgeColor;
    String levelName;
    switch (bossLevel) {
      case 4:
        badgeColor = const Color(0xFFEF4444);
        levelName = 'LEGENDARY BOSS';
        break;
      case 3:
        badgeColor = const Color(0xFFA855F7);
        levelName = 'ELITE BOSS';
        break;
      case 2:
        badgeColor = const Color(0xFFF59E0B);
        levelName = 'RIVAL';
        break;
      case 1:
      default:
        badgeColor = const Color(0xFF38BDF8);
        levelName = 'TROUBLEMAKER';
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: badgeColor.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('👹', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    '${_bossCards.length} Word Boss Seni Bekliyor',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  levelName,
                  style: GoogleFonts.outfit(
                    color: badgeColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Zorlandığın kelimelerden "$bossWord" rövanş istiyor! 6 turlu meydan okumayı tamamla, ekstra XP kazan.',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: badgeColor,
                foregroundColor: (bossLevel == 1 || bossLevel == 2) ? const Color(0xFF070B14) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _startBossBattle(topBoss),
              icon: const Icon(PhosphorIcons.swordBold, size: 16),
              label: Text(
                '⚔️ RÖVANŞA GİT ("$bossWord")',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}