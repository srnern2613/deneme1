// ============================================================================
// DOSYA ADI: lib/flashcards_screen.dart
// AÇIKLAMA: Pratik ve Oyun Modları Ekranı (2x2 Grid Mimarisi, Neon Glow Arena, 
//            Gradyan Ayarlar, Minimum Kart Emniyeti ve Asenkron Zırh)
// ============================================================================

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
import 'shop_screen.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _bossCards = [];
  bool _isLoading = true;

  // Arena Ayarları Değişkenleri
  int _sessionLimit = 0; // 0 = Tümü, aksi takdirde 10, 20, 30
  String _learningStateFilter = 'ALL'; // 'ALL' veya 'LEARNING'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettingsAndCards();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettingsAndCards();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSettingsAndCards();
  }

  Future<void> _loadSettingsAndCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      
      setState(() {
        _sessionLimit = prefs.getInt('arena_session_limit') ?? 0;
        _learningStateFilter = prefs.getString('arena_state_filter') ?? 'ALL';
      });

      await _loadCardsAndStats();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCardsAndStats() async {
    try {
      var cards = await DatabaseHelper.instance.getActivePracticeCards();
      final bossCards = await DatabaseHelper.instance.getActiveBossCards(limit: 3);
      await XpShopService.instance.getGemsBalance();
      await XpShopService.instance.getTotalXp();

      if (!mounted) return;

      // Durum Filtresi Uygula
      if (_learningStateFilter == 'LEARNING') {
        cards = cards.where((c) => c['learning_state'] == 'LEARNING').toList();
      }

      // Seans Limiti Uygula
      if (_sessionLimit > 0 && cards.length > _sessionLimit) {
        cards = cards.sublist(0, _sessionLimit);
      }

      if (!mounted) return;
      setState(() {
        _cards = cards;
        _bossCards = bossCards;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // --- ARENA AYARLARI (GRADYAN AKTİF DURUMLAR) ---
  void _openArenaSettings() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(2),
                      ),
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
                  const SizedBox(height: 28),
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
                      child: Text('Kaydet ve Uygula', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14)),
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

  void _startSrsExercise() {
    if (_cards.isEmpty) {
      _showEmptyWarning();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => FlashcardsExerciseScreen(cards: _cards)),
    ).then((_) {
      if (!mounted) return;
      _loadCardsAndStats();
    });
  }

  void _startQuizExercise() {
    if (_cards.length < 4) {
      _showMinCardsWarning(4);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => QuizExerciseScreen(cards: _cards)),
    ).then((_) {
      if (!mounted) return;
      _loadCardsAndStats();
    });
  }

  void _startMatchExercise() {
    if (_cards.length < 4) {
      _showMinCardsWarning(4);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MatchExerciseScreen(cards: _cards)),
    ).then((_) {
      if (!mounted) return;
      _loadCardsAndStats();
    });
  }

  void _startSpellingExercise() {
    if (_cards.isEmpty) {
      _showEmptyWarning();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SpellingExerciseScreen(cards: _cards)),
    ).then((_) {
      if (!mounted) return;
      _loadCardsAndStats();
    });
  }

  void _startBossBattle(Map<String, dynamic> bossCard) {
    HapticFeedback.heavyImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordBossBattleScreen(bossCard: bossCard),
      ),
    ).then((_) {
      if (!mounted) return;
      _loadCardsAndStats();
    });
  }

  void _showEmptyWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('⚠️ Pratik yapmak için önce kitap okurken kelime eklemelisin!'),
      ),
    );
  }

  void _showMinCardsWarning(int min) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('⚠️ Bu oyun modu için öğrenme havuzunda en az $min kelime olmalıdır (Şu an: ${_cards.length}).'),
      ),
    );
  }

  void _openShop() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ShopScreen()),
    ).then((_) {
      if (!mounted) return;
      _loadCardsAndStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCardsAndStats();
    });

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
                    
                    // --- NEON GLOW EFEKTLİ ARENA KARTI ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24), // Artırılmış dolgu (Padding)
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(PhosphorIcons.swordBold, color: Color(0xFFF59E0B), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kelime Arenası',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_cards.length} Aktif Pratik Kartı • Zihnini canlı tut!',
                                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _openArenaSettings,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: const Icon(PhosphorIcons.slidersBold, color: Color(0xFF38BDF8), size: 18),
                            ),
                          ),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .boxShadow(
                       begin: BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.0), blurRadius: 0),
                       end: BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 4),
                       duration: 1500.ms,
                     ),
                     
                    const SizedBox(height: 24),
                    Text(
                      'Öğrenme & Oyun Modları',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 14),
                    
                    // --- 2x2 GRID (IZGARA) MİMARİSİ ---
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85, // Kartın karesel/dikey estetiği
                      children: [
                        _buildGridPracticeCard(
                          icon: PhosphorIcons.lightningBold,
                          title: 'Hızlı Test',
                          desc: '4 seçenek arasından doğru anlamı yakala.',
                          reward: '+6 XP',
                          accentColor: const Color(0xFFF59E0B),
                          onTap: _startQuizExercise,
                        ),
                        _buildGridPracticeCard(
                          icon: PhosphorIcons.cardsBold,
                          title: 'SRS Hafıza',
                          desc: 'Aralıklı tekrar algoritması ile kart çevir.',
                          reward: '+5 XP',
                          accentColor: const Color(0xFF10B981),
                          onTap: _startSrsExercise,
                        ),
                        _buildGridPracticeCard(
                          icon: PhosphorIcons.puzzlePieceBold,
                          title: 'Eşleştirme',
                          desc: 'Blokları eşleştirerek tahtayı temizle.',
                          reward: '+10 XP',
                          accentColor: const Color(0xFF6366F1),
                          onTap: _startMatchExercise,
                        ),
                        _buildGridPracticeCard(
                          icon: PhosphorIcons.headphonesBold,
                          title: 'Dinle & Yaz',
                          desc: 'Telaffuzu dinle, kelimeyi doğru yaz.',
                          reward: '+8 XP',
                          accentColor: const Color(0xFF38BDF8),
                          onTap: _startSpellingExercise,
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

  // --- GRID (IZGARA) UYUMLU YENİ KART TASARIMI ---
  Widget _buildGridPracticeCard({
    required IconData icon,
    required String title,
    required String desc,
    required String reward,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reward,
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: accentColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
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

  Widget _buildModernHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pratik',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            Text(
              'Kelime Arenası & Oyunlar',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Row(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: XpShopService.instance.gemsNotifier,
              builder: (context, gems, _) {
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openShop,
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
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF59E0B))),
                  child: Row(
                    children: [
                      const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 15),
                      const SizedBox(width: 4),
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
}