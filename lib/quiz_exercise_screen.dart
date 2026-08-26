// ============================================================================
// DOSYA ADI: lib/quiz_exercise_screen.dart
// AÇIKLAMA: 4 Şıklı Çoktan Seçmeli Hızlı Kelime Testi & Canlı XP/Ödül Sistemi
// ============================================================================

import 'dart:math';
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
  String? _selectedOption;
  bool _answered = false;
  List<String> _currentOptions = [];
  String? _cheerToast;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.cards)..shuffle();
    _loadOptionsForCurrent();
  }

  void _loadOptionsForCurrent() {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;

    final currentCard = _questions[_currentIndex];
    final correctAnswer = currentCard['meaning'] ?? 'Tanım yok';

    final otherMeanings = widget.cards
        .where((c) => c['meaning'] != correctAnswer)
        .map((c) => c['meaning'] as String)
        .toSet()
        .toList();

    otherMeanings.shuffle();

    final List<String> options = [correctAnswer];
    for (int i = 0; i < min(3, otherMeanings.length); i++) {
      options.add(otherMeanings[i]);
    }

    while (options.length < 4) {
      options.add('Seçenek ${options.length + 1}');
    }

    options.shuffle();

    setState(() {
      _currentOptions = options;
      _selectedOption = null;
      _answered = false;
    });

    final currentWord = currentCard['word'] ?? '';
    TtsService.instance.speakWord(currentWord);
  }

  void _triggerCheer(String msg) {
    setState(() => _cheerToast = msg);
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _cheerToast == msg) {
        setState(() => _cheerToast = null);
      }
    });
  }

  void _selectOption(String option) async {
    if (_answered) return;

    final correctAnswer = _questions[_currentIndex]['meaning'] ?? '';
    final isCorrect = (option == correctAnswer);

    setState(() {
      _selectedOption = option;
      _answered = true;
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;
      await XpShopService.instance.addXp(6);

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
      if (_currentIndex + 1 < _questions.length) {
        setState(() => _currentIndex++);
        _loadOptionsForCurrent();
      } else {
        _finishQuiz();
      }
    });
  }

  void _finishQuiz() {
    CelebrationDialog.show(
      context,
      emoji: '🎯',
      title: 'Hızlı Test Tamamlandı!',
      subtitle: '${_questions.length} sorudan $_score tanesini doğru yanıtladın. Reflekslerin harika!',
      earnedXp: _score * 6,
      actionLabel: 'Süper, Devam Et!',
      onAction: () => Navigator.of(context).pop(),
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
    final correctAnswer = _questions[_currentIndex]['meaning'] ?? '';
    final progress = (_currentIndex + 1) / _questions.length;

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                          const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text('$_score Doğru', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Kelime Kartı
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
                            fontSize: 32,
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
                  const SizedBox(height: 24),

                  // 4 Seçenek
                  Expanded(
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentOptions.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: borderColor, width: isSelected || (_answered && isCorrect) ? 2 : 1),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: borderColor.withValues(alpha: 0.2),
                                  child: Text(
                                    ['A', 'B', 'C', 'D'][index],
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 15,
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