// ============================================================================
// DOSYA ADI: lib/quiz_exercise_screen.dart
// AÇIKLAMA: Anlam Çakışması ve Boşluk Korumalı 4 Şıklı Hızlı Test
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tts_service.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';

class QuizExerciseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;

  const QuizExerciseScreen({super.key, required this.cards});

  @override
  State<QuizExerciseScreen> createState() => _QuizExerciseScreenState();
}

class _QuizExerciseScreenState extends State<QuizExerciseScreen> {
  late List<Map<String, dynamic>> _questions;
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _totalEarnedXp = 0;
  String? _selectedOption;
  bool _answered = false;
  List<String> _currentOptions = [];
  String? _cheerToast;

  Timer? _questionTimer;
  double _timeRemaining = 10.0;

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
    _questions = widget.cards.where((c) {
      final w = (c['word'] ?? '').toString().trim();
      final m = (c['meaning'] ?? '').toString().trim();
      return w.isNotEmpty && m.isNotEmpty;
    }).toList()..shuffle();

    _loadOptionsForCurrent();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _timeRemaining = 10.0;
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

  void _timeOut() {
    if (_answered) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _answered = true;
      _streak = 0;
    });
    _triggerCheer('⏳ Süre doldu! Odaklan ve devam et.');

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      _nextQuestionOrFinish();
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
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;

    final currentCard = _questions[_currentIndex];
    final correctAnswer = (currentCard['meaning'] ?? '').toString().trim();

    final List<String> distinctOptions = [correctAnswer];

    // 1. Kullanıcının mevcut diğer kelimelerinden benzer olmayanları topla
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

    // 2. Yetersizse fallback listesinden ekle
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

    setState(() {
      _currentOptions = distinctOptions;
      _selectedOption = null;
      _answered = false;
    });

    final currentWord = currentCard['word'] ?? '';
    TtsService.instance.speakWord(currentWord);
    _startTimer();
  }

  void _triggerCheer(String msg) {
    setState(() => _cheerToast = msg);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _cheerToast == msg) {
        setState(() => _cheerToast = null);
      }
    });
  }

  void _selectOption(String option) async {
    if (_answered) return;
    _questionTimer?.cancel();

    final correctAnswer = (_questions[_currentIndex]['meaning'] ?? '').toString().trim();
    final isCorrect = (option == correctAnswer);

    setState(() {
      _selectedOption = option;
      _answered = true;
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;

      final earnedXp = _timeRemaining > 4.5 ? 8 : 6;
      _totalEarnedXp += earnedXp;
      await XpShopService.instance.addXp(earnedXp);

      final cheer = CoachMessages.getFlashcardCheer(_streak);
      if (cheer != null) {
        _triggerCheer(cheer);
      }
    } else {
      HapticFeedback.heavyImpact();
      _streak = 0;
      _triggerCheer(CoachMessages.getWrongAnswerEncouragement());
    }

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _nextQuestionOrFinish();
    });
  }

  void _nextQuestionOrFinish() {
    if (_currentIndex + 1 < _questions.length) {
      setState(() => _currentIndex++);
      _loadOptionsForCurrent();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    final feedback = CoachMessages.getFeedback(
      exerciseType: 'quiz',
      score: _score,
      total: _questions.length,
    );

    CelebrationDialog.show(
      context,
      emoji: feedback.emoji,
      title: feedback.title,
      subtitle: feedback.subtitle,
      earnedXp: _totalEarnedXp,
      earnedGems: _score >= (_questions.length * 0.8) ? 5 : 0,
      actionLabel: feedback.actionLabel,
      onAction: () {
        if (feedback.shouldOfferRetry) {
          setState(() {
            _currentIndex = 0;
            _score = 0;
            _streak = 0;
            _totalEarnedXp = 0;
            _questions.shuffle();
            _loadOptionsForCurrent();
          });
        } else {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hızlı Test')),
        body: const Center(child: Text('Test edilecek kelime bulunamadı.')),
      );
    }

    final currentWord = _questions[_currentIndex]['word'] ?? '';
    final correctAnswer = (_questions[_currentIndex]['meaning'] ?? '').toString().trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('4 Şıklı Hızlı Test', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$_streak Seri', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                          Text('$_score', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_timeRemaining / 10.0).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _timeRemaining > 3.0 ? const Color(0xFF10B981) : Colors.redAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentWord,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(backgroundColor: colors.primary.withValues(alpha: 0.12)),
                          icon: Icon(Icons.volume_up_rounded, color: colors.primary),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            TtsService.instance.speakWord(currentWord);
                          },
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
                        final isCorrect = (option == correctAnswer);

                        Color borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
                        Color bgColor = isDark ? const Color(0xFF131B2E) : Colors.white;
                        Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

                        if (_answered) {
                          if (isCorrect) {
                            borderColor = const Color(0xFF10B981);
                            bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
                            textColor = const Color(0xFF10B981);
                          } else if (isSelected) {
                            borderColor = Colors.red;
                            bgColor = Colors.red.withValues(alpha: 0.15);
                            textColor = Colors.red;
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