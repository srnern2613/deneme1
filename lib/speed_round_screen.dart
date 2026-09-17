// ============================================================================
// DOSYA ADI: lib/speed_round_screen.dart
// AÇIKLAMA: Hız Turu (60 sn) — PREMIUM mod. quiz_exercise_screen.dart'taki
//           4 şıklı test mantığı AYNEN kullanılır, ama soru başına sayaç
//           yerine TEK bir 60 saniyelik oturum sayacı vardır; havuz
//           tükenirse yeniden karılıp devam eder ("süreye karşı maksimum
//           doğru"). Hile Korumalı Dinamik xpMultiplier ve Şeffaf
//           Çapalama Tasarımı AYNEN korunmuştur.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_service.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';
import 'database_helper.dart';
import 'core/design_system/primitives.dart';
import 'core/coach/ignis_moments_engine.dart';

class SpeedRoundScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final int xpMultiplier; // Dinamik 2X XP FOMO Koruması
  final VoidCallback? onNavigateToLibrary;

  const SpeedRoundScreen({
    super.key,
    required this.cards,
    this.xpMultiplier = 1,
    this.onNavigateToLibrary,
  });

  @override
  State<SpeedRoundScreen> createState() => _SpeedRoundScreenState();
}

class _SpeedRoundScreenState extends State<SpeedRoundScreen> {
  static const double _sessionDuration = 60.0;

  List<Map<String, dynamic>> _pool = [];
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  int _totalEarnedXp = 0;
  String? _selectedOption;
  bool _answered = false;
  List<String> _currentOptions = [];
  String? _cheerToast;

  Timer? _sessionTimer;
  double _sessionTimeRemaining = _sessionDuration;
  bool _isRoundOver = false;
  bool _isRoundStarted = false;

  String _learningStateFilter = 'ALL';

  static const List<String> _fallbackDistractors = [
    'başlangıç, ilk adım',
    'görüşme, sohbet, diyalog',
    'dikkatlice bakmak, gözetlemek',
    'içine doğru, dahilinde',
    'kıyı, nehir kenarı, banka',
    'keşfetmek, açığa çıkarmak',
    'anlamak, kavramak, idrak etmek',
    'hızlıca ilerlemek, koşmak',
    'karar vermek, tercih etmek',
  ];

  @override
  void initState() {
    super.initState();
    TtsService.instance.initService();
    _loadSettingsAndInitPool();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettingsAndInitPool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      _learningStateFilter = prefs.getString('arena_state_filter') ?? 'ALL';

      // NOT: Hız Turu bilinçli olarak `arena_session_limit`'i UYGULAMAZ —
      // "süreye karşı maksimum doğru" fikri sabit sayıda soruyla çelişir;
      // havuz bitince yeniden karılıp devam eder.
      var filteredCards = widget.cards.where((c) {
        final w = (c['word'] ?? '').toString().trim();
        final m = (c['meaning'] ?? '').toString().trim();
        if (w.isEmpty || m.isEmpty) return false;
        if (_learningStateFilter == 'LEARNING' && c['learning_state'] != 'LEARNING') {
          return false;
        }
        return true;
      }).toList();

      filteredCards.shuffle();

      if (!mounted) return;
      setState(() {
        _pool = filteredCards;
        _questions = List<Map<String, dynamic>>.from(filteredCards);
      });

      if (_pool.isNotEmpty) {
        _loadOptionsForCurrent();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pool = [];
        _questions = [];
      });
    }
  }

  void _startRound() {
    if (_pool.isEmpty || _isRoundStarted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isRoundStarted = true;
      _sessionTimeRemaining = _sessionDuration;
    });
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      if (_sessionTimeRemaining > 0.1) {
        setState(() => _sessionTimeRemaining -= 0.1);
      } else {
        _sessionTimer?.cancel();
        _finishSpeedRound();
      }
    });
  }

  bool _isTooSimilar(String opt1, String opt2) {
    final clean1 = opt1.toLowerCase().replaceAll(RegExp(r'[^a-zçğıöşü]'), ' ').trim();
    final clean2 = opt2.toLowerCase().replaceAll(RegExp(r'[^a-zçğıöşü]'), ' ').trim();
    if (clean1 == clean2) return true;

    final words1 = clean1.split(' ').where((w) => w.length > 2).toSet();
    final words2 = clean2.split(' ').where((w) => w.length > 2).toSet();
    return words1.intersection(words2).isNotEmpty;
  }

  void _loadOptionsForCurrent() {
    if (!mounted) return;
    if (_questions.isEmpty) return;
    if (_currentIndex >= _questions.length) {
      // Havuz tükendi — yeniden karıp baştan devam et ("maksimum doğru" fikri
      // sabit soru sayısıyla değil, süreyle sınırlı).
      _questions = List<Map<String, dynamic>>.from(_pool)..shuffle();
      _currentIndex = 0;
    }

    final currentCard = _questions[_currentIndex];
    final correctAnswer = (currentCard['meaning'] ?? '').toString().trim();

    final List<String> distinctOptions = [correctAnswer];

    final otherMeanings = widget.cards
        .map((c) => (c['meaning'] ?? '').toString().trim())
        .where((m) => m.isNotEmpty && m != correctAnswer)
        .toSet()
        .toList()..shuffle();

    for (var m in otherMeanings) {
      if (distinctOptions.length >= 4) break;
      if (!distinctOptions.any((opt) => _isTooSimilar(opt, m))) {
        distinctOptions.add(m);
      }
    }

    if (distinctOptions.length < 4) {
      final availableFallbacks = _fallbackDistractors
          .where((f) => !distinctOptions.any((opt) => _isTooSimilar(opt, f)))
          .toList()..shuffle();

      for (var fallback in availableFallbacks) {
        if (distinctOptions.length >= 4) break;
        distinctOptions.add(fallback);
      }
    }

    distinctOptions.shuffle();

    if (!mounted) return;
    setState(() {
      _currentOptions = distinctOptions;
      _selectedOption = null;
      _answered = false;
    });
  }

  void _triggerCheer(String msg) {
    if (!mounted) return;
    setState(() => _cheerToast = msg);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && _cheerToast == msg) {
        setState(() => _cheerToast = null);
      }
    });
  }

  void _selectOption(String option) async {
    if (_answered || !mounted || !_isRoundStarted || _isRoundOver) return;

    final currentCard = _questions[_currentIndex];
    final correctAnswer = (currentCard['meaning'] ?? '').toString().trim();
    final isCorrect = (option == correctAnswer);
    final cardId = currentCard['id'] as int? ?? 0;

    if (!mounted) return;
    setState(() {
      _selectedOption = option;
      _answered = true;
    });

    if (cardId > 0) {
      unawaited(DatabaseHelper.instance.recordMultiModalResult(
        cardId: cardId,
        isCorrect: isCorrect,
        mode: 'speed_round',
      ));
    }

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;

      final earnedXp = 4 * widget.xpMultiplier;
      _totalEarnedXp += earnedXp;
      unawaited(XpShopService.instance.addXp(earnedXp));

      final cheer = CoachMessages.getFlashcardCheer(_streak);
      if (cheer != null) {
        _triggerCheer(cheer);
      }
    } else {
      HapticFeedback.heavyImpact();
      _streak = 0;
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _isRoundOver) return;
      setState(() => _currentIndex++);
      _loadOptionsForCurrent();
    });
  }

  Future<void> _finishSpeedRound() async {
    if (!mounted || _isRoundOver) return;
    setState(() => _isRoundOver = true);
    HapticFeedback.heavyImpact();

    final feedback = CoachMessages.getFeedback(
      exerciseType: 'speed_round',
      score: _score,
      total: _score > 0 ? _score : 1,
    );

    final ignisMoment = await IgnisMomentsEngine.instance.getSessionEndMoment();
    if (!mounted) return;

    CelebrationDialog.show(
      context,
      emoji: feedback.emoji,
      title: '⚡ $_score Doğru!',
      subtitle: _bestStreak >= 5
          ? 'En uzun serin: $_bestStreak 🔥 — ${feedback.subtitle}'
          : feedback.subtitle,
      earnedXp: _totalEarnedXp,
      ignisMomentTitle: ignisMoment?.title,
      ignisMomentMessage: ignisMoment?.message,
      ignisMomentPose: ignisMoment?.pose,
      actionLabel: 'Tekrar Dene ⚡',
      onAction: () {
        if (!mounted) return;
        setState(() {
          _currentIndex = 0;
          _score = 0;
          _streak = 0;
          _bestStreak = 0;
          _totalEarnedXp = 0;
          _isRoundOver = false;
          _isRoundStarted = false;
          _questions = List<Map<String, dynamic>>.from(_pool)..shuffle();
        });
        if (!mounted) return;
        _loadOptionsForCurrent();
      },
      secondaryActionLabel: 'Çık',
      onSecondaryAction: () {
        if (!mounted) return;
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pool.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070B14),
          elevation: 0,
          title: Text('Hız Turu', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: EmptyWordPoolState(
          message: 'Bu turu çözebilmek için önce Kitaplığından birkaç kelime eklemen gerekiyor.',
          onGoToLibrary: widget.onNavigateToLibrary,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Hız Turu ⚡', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: !_isRoundStarted ? _buildStartOverlay() : _buildRoundBody(),
      ),
    );
  }

  Widget _buildStartOverlay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorIcons.timerBold, color: Color(0xFFF59E0B), size: 56),
            const SizedBox(height: 18),
            Text(
              '60 Saniyen Var!',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
            ),
            const SizedBox(height: 10),
            Text(
              'Süre dolana kadar mümkün olduğunca çok doğru cevap ver. Havuz biterse otomatik karılır, durmadan devam eder.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: const Color(0xFF070B14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _startRound,
                child: Text('BAŞLA ⚡', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundBody() {
    if (_questions.isEmpty || _currentIndex >= _questions.length) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B)));
    }

    final currentWord = _questions[_currentIndex]['word'] ?? '';
    final correctAnswer = (_questions[_currentIndex]['meaning'] ?? '').toString().trim();

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(PhosphorIcons.timerBold, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_sessionTimeRemaining.ceil()}s',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFFF59E0B)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('$_streak Seri', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 12),
                      const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 2),
                      Text('$_score', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_sessionTimeRemaining / _sessionDuration).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFF111827),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _sessionTimeRemaining > 15.0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
                ),
                child: Text(
                  currentWord,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _currentOptions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final option = _currentOptions[index];
                    final isSelected = (_selectedOption == option);
                    final isCorrect = (option == correctAnswer);

                    Color borderColor = const Color(0xFF1F2937);
                    Color bgColor = const Color(0xFF111827);
                    Color textColor = Colors.white;

                    if (_answered) {
                      if (isCorrect) {
                        borderColor = const Color(0xFF10B981);
                        bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
                        textColor = const Color(0xFF10B981);
                      } else if (isSelected) {
                        borderColor = const Color(0xFFEF4444);
                        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
                        textColor = const Color(0xFFEF4444);
                      }
                    }

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _answered ? null : () => _selectOption(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: borderColor,
                            width: isSelected || (_answered && isCorrect) ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: borderColor.withValues(alpha: 0.2),
                              child: Text(
                                ['A', 'B', 'C', 'D'][index],
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        if (_cheerToast != null)
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _cheerToast!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}
