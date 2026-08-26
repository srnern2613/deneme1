// ============================================================================
// DOSYA ADI: lib/spelling_exercise_screen.dart
// AÇIKLAMA: Dinle & Yaz (Harf Blokları ile Kelime İnşa Etme & Telaffuz Pratiği)
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tts_service.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';

class LetterBlock {
  final int id;
  final String letter;
  bool isUsed;

  LetterBlock({
    required this.id,
    required this.letter,
    this.isUsed = false,
  });
}

class SpellingExerciseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;

  const SpellingExerciseScreen({super.key, required this.cards});

  @override
  State<SpellingExerciseScreen> createState() => _SpellingExerciseScreenState();
}

class _SpellingExerciseScreenState extends State<SpellingExerciseScreen> {
  late List<Map<String, dynamic>> _questions;
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;

  List<LetterBlock> _availableLetters = [];
  List<LetterBlock> _placedLetters = [];
  bool _isAnswerChecked = false;
  bool _isCorrect = false;
  String? _cheerToast;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.cards)..shuffle();
    _loadCurrentWord();
  }

  void _loadCurrentWord() {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;

    final rawWord = (_questions[_currentIndex]['word'] ?? '').toString().trim().toUpperCase();
    final cleanWord = rawWord.replaceAll(RegExp(r'[^A-Z]'), '');

    List<LetterBlock> blocks = [];
    for (int i = 0; i < cleanWord.length; i++) {
      blocks.add(LetterBlock(id: i, letter: cleanWord[i]));
    }

    // Ekstra 2-3 yanıltıcı harf ekleyerek pratik zorluğunu dengele
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random();
    final extraCount = min(3, 8 - min(blocks.length, 5));
    for (int i = 0; i < extraCount; i++) {
      final extraChar = alphabet[rand.nextInt(alphabet.length)];
      blocks.add(LetterBlock(id: 100 + i, letter: extraChar));
    }

    blocks.shuffle();

    setState(() {
      _availableLetters = blocks;
      _placedLetters = [];
      _isAnswerChecked = false;
      _isCorrect = false;
    });

    final currentWordText = _questions[_currentIndex]['word'] ?? '';
    TtsService.instance.speakWord(currentWordText);
  }

  void _triggerCheer(String msg) {
    setState(() => _cheerToast = msg);
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _cheerToast == msg) {
        setState(() => _cheerToast = null);
      }
    });
  }

  void _onLetterTap(LetterBlock block) {
    if (_isAnswerChecked || block.isUsed) return;

    HapticFeedback.selectionClick();
    setState(() {
      block.isUsed = true;
      _placedLetters.add(block);
    });

    final targetWord = (_questions[_currentIndex]['word'] ?? '')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');

    if (_placedLetters.length == targetWord.length) {
      _checkAnswer(targetWord);
    }
  }

  void _onPlacedLetterTap(LetterBlock block) {
    if (_isAnswerChecked) return;

    HapticFeedback.selectionClick();
    setState(() {
      block.isUsed = false;
      _placedLetters.remove(block);
    });
  }

  void _checkAnswer(String targetWord) async {
    final userWord = _placedLetters.map((b) => b.letter).join();
    final correct = (userWord == targetWord);

    setState(() {
      _isAnswerChecked = true;
      _isCorrect = correct;
    });

    if (correct) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;
      await XpShopService.instance.addXp(8);

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
      if (_currentIndex + 1 < _questions.length) {
        setState(() => _currentIndex++);
        _loadCurrentWord();
      } else {
        _finishSpelling();
      }
    });
  }

  void _finishSpelling() {
    CelebrationDialog.show(
      context,
      emoji: '🎧',
      title: 'Dinle & Yaz Tamamlandı!',
      subtitle: '${_questions.length} kelimeden $_score tanesini harf harf doğru yazdın. Telaffuz ve hafıza mükemmel!',
      earnedXp: _score * 8,
      actionLabel: 'Harika!',
      onAction: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dinle & Yaz')),
        body: const Center(child: Text('Pratik yapılacak kelime bulunamadı.')),
      );
    }

    final currentCard = _questions[_currentIndex];
    final meaning = currentCard['meaning'] ?? 'Tanım yok';
    final currentWordText = currentCard['word'] ?? '';
    final progress = (_currentIndex + 1) / _questions.length;

    final targetWord = currentWordText.toString().trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dinle & Yaz (Spelling)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        'Kelime ${_currentIndex + 1} / ${_questions.length}',
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
                  const SizedBox(height: 20),

                  // Ses ve İpucu Kartı
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: colors.primary,
                            padding: const EdgeInsets.all(16),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 30),
                          tooltip: 'Tekrar Dinle',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            TtsService.instance.speakWord(currentWordText);
                          },
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '“$meaning”',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Harf Yuvaları / Yazılan Harfler
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(targetWord.length, (index) {
                      final hasLetter = index < _placedLetters.length;
                      final letterBlock = hasLetter ? _placedLetters[index] : null;

                      Color boxBorderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
                      Color boxBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

                      if (_isAnswerChecked) {
                        boxBorderColor = _isCorrect ? const Color(0xFF10B981) : Colors.red;
                        boxBgColor = (_isCorrect ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.15);
                      }

                      return GestureDetector(
                        onTap: hasLetter ? () => _onPlacedLetterTap(letterBlock!) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 44,
                          height: 52,
                          decoration: BoxDecoration(
                            color: boxBgColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: hasLetter ? colors.primary : boxBorderColor,
                              width: hasLetter ? 2 : 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            hasLetter ? letterBlock!.letter : '',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),

                  // Seçilebilir Harf Blokları
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: _availableLetters.map((block) {
                      return Opacity(
                        opacity: block.isUsed ? 0.25 : 1.0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: block.isUsed ? null : () => _onLetterTap(block),
                          child: Container(
                            width: 50,
                            height: 54,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              block.letter,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
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