// ============================================================================
// DOSYA ADI: lib/spelling_exercise_screen.dart
// AÇIKLAMA: Dinle & Yaz (Spelling) & Çok Boyutlu Modalite/Boss Entegreli Mod
// GÖREVLER & DÜZELTMELER:
//   1. Modalite Entegrasyonu: 'recordMultiModalResult(mode: "spelling")' üzerinden atomik kayıt.
//   2. Boss Tetikleme: Hatalı harf diziliminde kelimenin hata sayacı güncellenir.
//   3. Çok Boyutlu Mastery: Başarılı yazımlar 'modes_passed' alanına 'spelling' olarak işlenir.
//   4. Harf/sembol koruması ve dinamik klavye yapısı korundu.
//   5. Semantik Renk Standardı: %70-80 koyu zemin (#070B14), %10-20 panel (#111827).
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'database_helper.dart';
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
  int _hintsUsedInWord = 0;
  int _totalEarnedXp = 0;

  List<LetterBlock> _availableLetters = [];
  List<LetterBlock> _placedLetters = [];
  bool _isAnswerChecked = false;
  bool _isCorrect = false;
  String? _cheerToast;

  @override
  void initState() {
    super.initState();
    TtsService.instance.initService();
    // KORUMA: İçinde en az bir İngilizce harf barındırmayan kartları ele
    _questions = widget.cards.where((c) {
      final w = (c['word'] ?? '').toString().trim().toUpperCase();
      final clean = w.replaceAll(RegExp(r'[^A-Z]'), '');
      return clean.isNotEmpty;
    }).toList()..shuffle();

    _loadCurrentWord();
  }

  void _loadCurrentWord() {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;

    _hintsUsedInWord = 0;
    final rawWord = (_questions[_currentIndex]['word'] ?? '').toString().trim().toUpperCase();
    final cleanWord = rawWord.replaceAll(RegExp(r'[^A-Z]'), '');

    if (cleanWord.isEmpty) {
      if (_currentIndex + 1 < _questions.length) {
        _currentIndex++;
        _loadCurrentWord();
      }
      return;
    }

    // 1. Hedef kelimenin harf bloklarını oluştur
    List<LetterBlock> blocks = [];
    for (int i = 0; i < cleanWord.length; i++) {
      blocks.add(LetterBlock(id: i, letter: cleanWord[i]));
    }

    // 2. 2 veya 3 adet rastgele çeldirici harf ekle
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random();
    final extraCount = cleanWord.length <= 4 ? 3 : 2;

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

  void _useHint() {
    if (_isAnswerChecked) return;

    final targetWord = (_questions[_currentIndex]['word'] ?? '')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');

    final int targetIndex = _placedLetters.length;
    if (targetIndex >= targetWord.length) return;

    final String requiredChar = targetWord[targetIndex];

    final matchingIndex = _availableLetters.indexWhere(
      (b) => !b.isUsed && b.letter == requiredChar,
    );

    if (matchingIndex != -1) {
      final matchingBlock = _availableLetters[matchingIndex];
      HapticFeedback.selectionClick();
      setState(() {
        _hintsUsedInWord++;
        matchingBlock.isUsed = true;
        _placedLetters.add(matchingBlock);
      });

      if (_placedLetters.length == targetWord.length) {
        _checkAnswer(targetWord);
      }
    }
  }

  void _onLetterTap(LetterBlock block) {
    if (_isAnswerChecked || block.isUsed) return;

    final targetWord = (_questions[_currentIndex]['word'] ?? '')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');

    if (_placedLetters.length >= targetWord.length) return;

    HapticFeedback.selectionClick();
    setState(() {
      block.isUsed = true;
      _placedLetters.add(block);
    });

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
    final currentCard = _questions[_currentIndex];
    final cardId = currentCard['id'] as int? ?? 0;

    setState(() {
      _isAnswerChecked = true;
      _isCorrect = correct;
    });

    // 🎯 ÇOK BOYUTLU MODALİTE & BOSS ENTEGRASYONU
    if (cardId > 0) {
      await DatabaseHelper.instance.recordMultiModalResult(
        cardId: cardId,
        isCorrect: correct,
        mode: 'spelling',
      );
    }

    if (correct) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;
      final earnedXp = _hintsUsedInWord > 0 ? 5 : 8;
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
    final feedback = CoachMessages.getFeedback(
      exerciseType: 'spelling',
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
            _loadCurrentWord();
          });
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
          title: Text('Dinle & Yaz', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text('Pratik yapılacak geçerli kelime bulunamadı.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
        ),
      );
    }

    final currentCard = _questions[_currentIndex];
    final meaning = currentCard['meaning'] ?? 'Tanım yok';
    final currentWordText = currentCard['word'] ?? '';
    final progress = (_currentIndex + 1) / _questions.length;
    final targetWord = currentWordText.toString().trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Dinle & Yaz (Spelling)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIcons.lightbulbBold, color: Color(0xFFF59E0B)),
            tooltip: 'İpucu Al',
            onPressed: _useHint,
          ),
        ],
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
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF94A3B8)),
                      ),
                      Row(
                        children: [
                          const Icon(PhosphorIcons.lightningBold, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 4),
                          Text('$_score Doğru', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
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
                      backgroundColor: const Color(0xFF111827),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Dinleme & Anlam Kartı
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            padding: const EdgeInsets.all(14),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF070B14), size: 28),
                          tooltip: 'Tekrar Dinle',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            TtsService.instance.speakWord(currentWordText);
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '“$meaning”',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Harf Slotları
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(targetWord.length, (index) {
                      final hasLetter = index < _placedLetters.length;
                      final letterBlock = hasLetter ? _placedLetters[index] : null;

                      Color boxBorderColor = const Color(0xFF1F2937);
                      Color boxBgColor = const Color(0xFF111827);

                      if (_isAnswerChecked) {
                        boxBorderColor = _isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                        boxBgColor = (_isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.15);
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
                              color: hasLetter ? const Color(0xFF38BDF8) : boxBorderColor,
                              width: hasLetter ? 2 : 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            hasLetter ? letterBlock!.letter : '',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
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
                              color: const Color(0xFF111827),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF1F2937),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              block.letter,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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