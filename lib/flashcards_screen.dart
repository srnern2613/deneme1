// ============================================================================
// DOSYA ADI: lib/flashcards_screen.dart
// AÇIKLAMA: Entegre Kaynak HUD'lu ve Çakışmasız Pratik Merkezi
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'database_helper.dart';
import 'flashcards_exercise_screen.dart';
import 'quiz_exercise_screen.dart';
import 'match_exercise_screen.dart';
import 'spelling_exercise_screen.dart';
import 'xp_shop_service.dart';
import 'shop_screen.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  List<Map<String, dynamic>> _cards = [];
  bool _isLoading = true;
  int _userGems = 50;
  int _userTotalXp = 100;

  @override
  void initState() {
    super.initState();
    _loadCardsAndStats();
  }

  Future<void> _loadCardsAndStats() async {
    setState(() => _isLoading = true);
    try {
      final cards = await DatabaseHelper.instance.getFlashcards();
      final gems = await XpShopService.instance.getGemsBalance();
      final xp = await XpShopService.instance.getTotalXp();

      if (!mounted) return;
      setState(() {
        _cards = cards;
        _userGems = gems;
        _userTotalXp = xp;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Pratik verileri yüklenirken hata oluştu: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _startSrsExercise() {
    if (_cards.isEmpty) {
      _showEmptyWarning();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => FlashcardsExerciseScreen(cards: _cards)),
    ).then((_) => _loadCardsAndStats());
  }

  void _startQuizExercise() {
    if (_cards.length < 4) {
      _showMinCardsWarning(4);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => QuizExerciseScreen(cards: _cards)),
    ).then((_) => _loadCardsAndStats());
  }

  void _startMatchExercise() {
    if (_cards.length < 4) {
      _showMinCardsWarning(4);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MatchExerciseScreen(cards: _cards)),
    ).then((_) => _loadCardsAndStats());
  }

  void _startSpellingExercise() {
    if (_cards.isEmpty) {
      _showEmptyWarning();
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SpellingExerciseScreen(cards: _cards)),
    ).then((_) => _loadCardsAndStats());
  }

  void _showEmptyWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('⚠️ Pratik yapmak için önce kitap okurken kelime eklemelisin!'),
      ),
    );
  }

  void _showMinCardsWarning(int min) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('⚠️ Bu oyun modu için kelime havuzunda en az $min kelime olmalıdır (Şu an: ${_cards.length}).'),
      ),
    );
  }

  void _openShop() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ShopScreen()),
    ).then((_) => _loadCardsAndStats());
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(PhosphorIcons.swordBold, color: Color(0xFF818CF8), size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kelime Arenası',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_cards.length} Kayıtlı Kelime • Zihnini canlı tut!',
                                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Öğrenme & Oyun Modları',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 14),
                    _buildPracticeCard(
                      icon: PhosphorIcons.lightningBold,
                      title: '4 Şıklı Hızlı Test',
                      desc: 'Kelimenin doğru Türkçe karşılığını 4 seçenek arasından yakala.',
                      reward: '+6 XP',
                      accentColor: const Color(0xFFF59E0B),
                      onTap: _startQuizExercise,
                    ),
                    const SizedBox(height: 12),
                    _buildPracticeCard(
                      icon: PhosphorIcons.cardsBold,
                      title: 'SRS Hafıza Kartları',
                      desc: 'Aralıklı tekrar algoritmasıyla kartları çevir ve hafızanı tazele.',
                      reward: '+5 XP',
                      accentColor: const Color(0xFF10B981),
                      onTap: _startSrsExercise,
                    ),
                    const SizedBox(height: 12),
                    _buildPracticeCard(
                      icon: PhosphorIcons.puzzlePieceBold,
                      title: 'Kelime Eşleştirme',
                      desc: 'İngilizce ve Türkçe kelime bloklarını eşleştirerek tahtayı temizle.',
                      reward: '+10 XP',
                      accentColor: const Color(0xFFA855F7),
                      onTap: _startMatchExercise,
                    ),
                    const SizedBox(height: 12),
                    _buildPracticeCard(
                      icon: PhosphorIcons.headphonesBold,
                      title: 'Dinle & Yaz (Spelling)',
                      desc: 'Telaffuzu dinle, karışık harfler arasından doğru kelimeyi kur.',
                      reward: '+8 XP',
                      accentColor: const Color(0xFF38BDF8),
                      onTap: _startSpellingExercise,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
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
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _openShop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.5),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(PhosphorIcons.lightningBold, color: Colors.orange, size: 15),
                  const SizedBox(width: 4),
                  Text('$_userTotalXp', style: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPracticeCard({
    required IconData icon,
    required String title,
    required String desc,
    required String reward,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              reward,
                              style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: accentColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(PhosphorIcons.caretRightBold, color: Color(0xFF64748B), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}