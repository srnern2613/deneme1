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
import 'core/theme/draconic_theme.dart'; // T-1: yapısal renkler temadan
import 'core/branding/app_branding.dart';

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

      // P0 (#16): örnek/pratik kelimelerde (cardId <= 0) XP verilmiyor —
      // diğer egzersiz modlarıyla aynı koruma.
      if (cardId > 0) {
        final baseXp = _timeRemaining > 6.0 ? 10 : 8;
        final earnedXp = baseXp * widget.xpMultiplier;

        _totalEarnedXp += earnedXp;
        await XpShopService.instance.addXp(earnedXp);
      }

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
      correctCount: _score,
      wrongCount: _questions.length - _score,
      ignisMomentTitle: ignisMoment?.title,
      ignisMomentMessage: ignisMoment?.message,
      ignisMomentPose: ignisMoment?.pose,
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
    final theme = Theme.of(context).extension<DraconicTheme>()!;

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          title: Text('Ters Test', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: EmptyWordPoolState(
          message: 'Bu testi çözebilmek için önce Kitaplığından birkaç kelime eklemen gerekiyor.',
          onGoToLibrary: widget.onNavigateToLibrary,
        ),
      );
    }

    final correctWord = (_questions[_currentIndex]['word'] ?? '').toString().trim();
    final currentMeaning = (_questions[_currentIndex]['meaning'] ?? '').toString().trim();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ters Test (TR → EN)', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: theme.textPrimary, fontSize: 15)),
            if (widget.xpMultiplier > 1)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '~+10 XP',
                    style: GoogleFonts.outfit(
                      color: theme.textMuted,
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '⚡ ${10 * widget.xpMultiplier} XP (2X Şanslı Mod!)',
                    style: GoogleFonts.outfit(
                      color: theme.primaryAmber,
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
          icon: Icon(Icons.close_rounded, color: theme.textPrimary),
          onPressed: _confirmExit,
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
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textSecondary),
                      ),
                      Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$_streak Seri', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          const SizedBox(width: 12),
                          // NOT: 0xFFA855F7 (mor) bu Premium modun kendi kimlik
                          // rengi — T-1 çekirdek token'larıyla eşlenmiyor,
                          // bilinçli olarak semantik/per-item vurgu (diğer
                          // Premium rozetleriyle aynı istisna kuralı).
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
                      backgroundColor: theme.surfaceDark,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeRemaining > 4.0 ? theme.successEmerald : theme.dangerRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      color: theme.surfaceDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.borderSubtle, width: 1.5),
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
                            color: theme.textPrimary,
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

                        Color borderColor = theme.borderSubtle;
                        Color bgColor = theme.surfaceDark;
                        Color textColor = theme.textPrimary;

                        if (_answered) {
                          if (isCorrectOpt) {
                            borderColor = theme.successEmerald;
                            bgColor = theme.successEmerald.withValues(alpha: 0.15);
                            textColor = theme.successEmerald;
                          } else if (isSelected) {
                            borderColor = theme.dangerRed;
                            bgColor = theme.dangerRed.withValues(alpha: 0.15);
                            textColor = theme.dangerRed;
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

            if (_cheerToast != null) CheerToast(message: _cheerToast),
          ],
        ),
      ),
      ),
    );
  }

  // A-6 (#20): sistem geri tuşu/kenar kaydırma artık kapatma butonuyla AYNI
  // onay akışından geçiyor — flashcards_exercise_screen.dart'taki desenle
  // tutarlı.
  Future<void> _confirmExit() async {
    if (_questions.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        // Kaşını kaldırmış Ignis: "gerçekten gidiyor musun?" 🤨
        icon: Image.asset(
          AppBranding.poseAsset('suspicious'),
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Egzersizden çık?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Kalan soruları tamamlamadan çıkıyorsun. Bu ana kadarki cevapların zaten kaydedildi.',
          style: TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Devam Et')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Çık')),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      Navigator.of(context).pop();
    }
  }
}
