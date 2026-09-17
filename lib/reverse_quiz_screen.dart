// ============================================================================
// DOSYA ADI: lib/reverse_quiz_screen.dart
// AÇIKLAMA: Ters Test (TR → EN) — PREMIUM mod. Türkçe anlamı görüp doğru
//           İngilizce kelimeyi bulma; aktif üretimi (recall) test eder,
//           quiz_exercise_screen.dart'taki 4 şıklı yapıdan türetilmiştir
//           ama soru/cevap yönü ters çevrilmiştir (Hile Korumalı Dinamik
//           xpMultiplier ve Şeffaf Çapalama Tasarımı AYNEN korunmuştur).
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

class ReverseQuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final int xpMultiplier; // Dinamik 2X XP FOMO Koruması
  final VoidCallback? onNavigateToLibrary;

  const ReverseQuizScreen({
    super.key,
    required this.cards,
    this.xpMultiplier = 1,
    this.onNavigateToLibrary,
  });

  @override
  State<ReverseQuizScreen> createState() => _ReverseQuizScreenState();
}

class _ReverseQuizScreenState extends State<ReverseQuizScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _totalEarnedXp = 0;
  String? _selectedOption;
  bool _answered = false;
  List<String> _currentOptions = [];
  String? _cheerToast;

  Timer? _questionTimer;
  double _timeRemaining = 12.0;

  int _sessionLimit = 0;
  String _learningStateFilter = 'ALL';

  static const List<String> _fallbackDistractors = [
    'garden',
    'window',
    'journey',
    'silence',
    'shadow',
    'harbor',
    'stranger',
    'promise',
    'candle',
    'mountain',
  ];

  @override
  void initState() {
    super.initState();
    TtsService.instance.initService();
    _loadSettingsAndInitQuiz();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettingsAndInitQuiz() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      _sessionLimit = prefs.getInt('arena_session_limit') ?? 0;
      _learningStateFilter = prefs.getString('arena_state_filter') ?? 'ALL';

      var filteredCards = widget.cards.where((c) {
        final w = (c['word'] ?? '').toString().trim();
        final m = (c['meaning'] ?? '').toString().trim();
        if (w.isEmpty || m.isEmpty) return false;
        if (_learningStateFilter == 'LEARNING' && c['learning_state'] != 'LEARNING') {
          return false;
        }
        return true;
      }).toList();

      if (_sessionLimit > 0 && filteredCards.length > _sessionLimit) {
        filteredCards = filteredCards.sublist(0, _sessionLimit);
      }

      filteredCards.shuffle();

      if (!mounted) return;
      setState(() {
        _questions = filteredCards;
      });

      _loadOptionsForCurrent();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questions = [];
      });
    }
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _timeRemaining = 12.0;
    _questionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      if (_timeRemaining > 0.1) {
        setState(() => _timeRemaining -= 0.1);
      } else {
        _questionTimer?.cancel();
        _timeOut();
      }
    });
  }

  void _timeOut() async {
    if (_answered || !mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _answered = true;
      _streak = 0;
    });
    _triggerCheer('⏳ Süre doldu! Odaklan ve devam et.');

    final currentCard = _questions[_currentIndex];
    final cardId = currentCard['id'] as int? ?? 0;
    if (cardId > 0) {
      await DatabaseHelper.instance.recordMultiModalResult(
        cardId: cardId,
        isCorrect: false,
        mode: 'reverse_quiz',
      );
    }

    if (!mounted) return;

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      _nextQuestionOrFinish();
    });
  }

  void _loadOptionsForCurrent() {
    if (!mounted) return;
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;

    final currentCard = _questions[_currentIndex];
    final correctWord = (currentCard['word'] ?? '').toString().trim();

    final List<String> distinctOptions = [correctWord];

    final otherWords = widget.cards
        .map((c) => (c['word'] ?? '').toString().trim())
        .where((w) => w.isNotEmpty && w.toLowerCase() != correctWord.toLowerCase())
        .toSet()
        .toList()..shuffle();

    for (var w in otherWords) {
      if (distinctOptions.length >= 4) break;
      if (!distinctOptions.any((opt) => opt.toLowerCase() == w.toLowerCase())) {
        distinctOptions.add(w);
      }
    }

    if (distinctOptions.length < 4) {
      final availableFallbacks = _fallbackDistractors
          .where((f) => !distinctOptions.any((opt) => opt.toLowerCase() == f.toLowerCase()))
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

    _startTimer();
  }

  void _triggerCheer(String msg) {
    if (!mounted) return;
    setState(() => _cheerToast = msg);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _cheerToast == msg) {
        setState(() => _cheerToast = null);
      }
    });
  }

  void _selectOption(String option) async {
    if (_answered || !mounted) return;
    _questionTimer?.cancel();

    final currentCard = _questions[_currentIndex];
    final correctWord = (currentCard['word'] ?? '').toString().trim();
    final isCorrect = (option.toLowerCase() == correctWord.toLowerCase());
    final cardId = currentCard['id'] as int? ?? 0;

    if (!mounted) return;
    setState(() {
      _selectedOption = option;
      _answered = true;
    });

    // Doğru cevap görünür olduğunda telaffuzu duyulsun — hile riski yok,
    // çünkü kullanıcı zaten seçimini yaptı.
    TtsService.instance.speakWord(correctWord);

    if (cardId > 0) {
      await DatabaseHelper.instance.recordMultiModalResult(
        cardId: cardId,
        isCorrect: isCorrect,
        mode: 'reverse_quiz',
      );
    }

    if (!mounted) return;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;

      final baseXp = _timeRemaining > 6.0 ? 10 : 8;
      final earnedXp = baseXp * widget.xpMultiplier;

      _totalEarnedXp += earnedXp;
      await XpShopService.instance.addXp(earnedXp);

      if (!mounted) return;

      final cheer = CoachMessages.getFlashcardCheer(_streak);
      if (cheer != null) {
        _triggerCheer(cheer);
      }
    } else {
      HapticFeedback.heavyImpact();
      _streak = 0;
      _triggerCheer(CoachMessages.getWrongAnswerEncouragement());
    }

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      _nextQuestionOrFinish();
    });
  }

  void _nextQuestionOrFinish() {
    if (!mounted) return;
    if (_currentIndex + 1 < _questions.length) {
      setState(() => _currentIndex++);
      _loadOptionsForCurrent();
    } else {
      _finishReverseQuiz();
    }
  }

  Future<void> _finishReverseQuiz() async {
    if (!mounted) return;

    final feedback = CoachMessages.getFeedback(
      exerciseType: 'reverse_quiz',
      score: _score,
      total: _questions.length,
    );

    final ignisMoment = await IgnisMomentsEngine.instance.getSessionEndMoment();
    if (!mounted) return;

    CelebrationDialog.show(
      context,
      emoji: feedback.emoji,
      title: feedback.title,
      subtitle: feedback.subtitle,
      earnedXp: _totalEarnedXp,
      ignisMomentTitle: ignisMoment?.title,
      ignisMomentMessage: ignisMoment?.message,
      actionLabel: feedback.actionLabel,
      onAction: () {
        if (!mounted) return;
        if (feedback.shouldOfferRetry) {
          setState(() {
            _currentIndex = 0;
            _score = 0;
            _streak = 0;
            _totalEarnedXp = 0;
            _questions.shuffle();
          });
          // _loadOptionsForCurrent() kendi setState'ini ve Timer'ını
          // başlatıyor; nested setState/Timer donma riskini önlemek için
          // DIŞARIDA çağrılır (quiz_exercise_screen.dart ile aynı desen).
          if (!mounted) return;
          _loadOptionsForCurrent();
        } else {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070B14),
          elevation: 0,
          title: Text('Ters Test', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: EmptyWordPoolState(
          message: 'Bu testi çözebilmek için önce Kitaplığından birkaç kelime eklemen gerekiyor.',
          onGoToLibrary: widget.onNavigateToLibrary,
        ),
      );
    }

    final correctWord = (_questions[_currentIndex]['word'] ?? '').toString().trim();
    final currentMeaning = (_questions[_currentIndex]['meaning'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ters Test (TR → EN)', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
            if (widget.xpMultiplier > 1)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '~+10 XP',
                    style: GoogleFonts.outfit(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '⚡ ${10 * widget.xpMultiplier} XP (2X Şanslı Mod!)',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFF59E0B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Soru ${_currentIndex + 1} / ${_questions.length}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF94A3B8)),
                      ),
                      Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$_streak Seri', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(width: 12),
                          const Icon(PhosphorIcons.crownBold, color: Color(0xFFA855F7), size: 16),
                          const SizedBox(width: 2),
                          Text('$_score', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFA855F7))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_timeRemaining / 12.0).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0xFF111827),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeRemaining > 4.0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(PhosphorIcons.magnifyingGlassBold, color: Color(0xFFA855F7), size: 24),
                        const SizedBox(height: 12),
                        Text(
                          currentMeaning,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
                        final isCorrectOpt = (option.toLowerCase() == correctWord.toLowerCase());

                        Color borderColor = const Color(0xFF1F2937);
                        Color bgColor = const Color(0xFF111827);
                        Color textColor = Colors.white;

                        if (_answered) {
                          if (isCorrectOpt) {
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
                                width: isSelected || (_answered && isCorrectOpt) ? 2 : 1,
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
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  offset: _cheerToast != null ? Offset.zero : const Offset(0, -1.5),
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
              ),
          ],
        ),
      ),
    );
  }
}
