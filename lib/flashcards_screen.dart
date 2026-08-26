// ============================================================================
// DOSYA ADI: lib/flashcards_screen.dart
// AÇIKLAMA: Pratik & Oyunlar Merkezi (Quiz, SRS Kartları, Eşleştirme, Dinle & Yaz)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';
import 'flashcards_exercise_screen.dart';
import 'quiz_exercise_screen.dart';
import 'xp_shop_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pratik & Antrenman', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '$_userGems',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.cyan[700]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '$_userTotalXp',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.amber),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Bilgi Kartı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('🧠', style: TextStyle(fontSize: 30)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kelime Arenası',
                                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_cards.length} Kayıtlı Kelime • Her gün pratik yap!',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Öğrenme & Oyun Modları',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 12),

                  // 1. DÖRT ŞIKLI HIZLI QUIZ
                  _buildPracticeCard(
                    emoji: '⚡',
                    title: '4 Şıklı Hızlı Test',
                    desc: 'Kelimenin doğru Türkçe karşılığını 4 seçenek arasından yakala.',
                    reward: '+6 XP',
                    badgeColor: Colors.amber,
                    isDark: isDark,
                    onTap: _startQuizExercise,
                  ),
                  const SizedBox(height: 12),

                  // 2. KLASİK SRS HAFIZA KARTLARI
                  _buildPracticeCard(
                    emoji: '📇',
                    title: 'SRS Hafıza Kartları',
                    desc: 'Aralıklı tekrar algoritmasıyla kartları çevir ve hafızanı tazele.',
                    reward: '+5 XP',
                    badgeColor: Colors.green,
                    isDark: isDark,
                    onTap: _startSrsExercise,
                  ),
                  const SizedBox(height: 12),

                  // 3. KELİME EŞLEŞTİRME (Match)
                  _buildPracticeCard(
                    emoji: '🧩',
                    title: 'Kelime Eşleştirme',
                    desc: 'İngilizce ve Türkçe kelime bloklarını eşleştirerek tahtayı temizle.',
                    reward: '+10 XP',
                    badgeColor: Colors.purple,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🧩 Kelime Eşleştirme modu hazırlanıyor!')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // 4. DİNLE & YAZ (Spelling)
                  _buildPracticeCard(
                    emoji: '🎧',
                    title: 'Dinle & Yaz (Spelling)',
                    desc: 'Telaffuzu dinle, karışık harfler arasından doğru kelimeyi kur.',
                    reward: '+8 XP',
                    badgeColor: Colors.blue,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎧 Dinle & Yaz modu hazırlanıyor!')),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildPracticeCard({
    required String emoji,
    required String title,
    required String desc,
    required String reward,
    required Color badgeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
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
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 26)),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              reward,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}