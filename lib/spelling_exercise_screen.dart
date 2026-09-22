// ============================================================================
// DOSYA ADI: lib/spelling_exercise_screen.dart
// AÇIKLAMA: Dinle & Yaz (Spelling) & Çok Boyutlu Modalite/Boss Entegreli Mod
//           (Hile Korumalı Dinamik xpMultiplier ve Şeffaf Çapalama Tasarımı)
// ============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import 'tts_service.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';
import 'core/design_system/primitives.dart';
import 'core/coach/ignis_moments_engine.dart';
import 'core/theme/draconic_theme.dart'; // T-1: yapısal renkler temadan

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
  final int xpMultiplier; // Dinamik 2X XP FOMO Koruması
  final VoidCallback? onNavigateToLibrary;

  const SpellingExerciseScreen({
    super.key,
    required this.cards,
    this.xpMultiplier = 1,
    this.onNavigateToLibrary,
  });

  @override
  State<SpellingExerciseScreen> createState() => _SpellingExerciseScreenState();
}

class _SpellingExerciseScreenState extends State<SpellingExerciseScreen> {
  List<Map<String, dynamic>> _questions = [];
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
  bool _isLoading = true;

  int _sessionLimit = 0;
  String _learningStateFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    TtsService.instance.initService();
    _loadSettingsAndInitQuestions();
  }

  Future<void> _loadSettingsAndInitQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      _sessionLimit = prefs.getInt('arena_session_limit') ?? 0;
      _learningStateFilter = prefs.getString('arena_state_filter') ?? 'ALL';

      var filteredCards = widget.cards.where((c) {
        final w = (c['word'] ?? '').toString().trim().toUpperCase();
        final clean = w.replaceAll(RegExp(r'[^A-Z]'), '');
        if (clean.isEmpty) return false;
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
        _isLoading = false;
      });

      _loadCurrentWord();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadCurrentWord() {
    if (!mounted) return;
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

    List<LetterBlock> blocks = [];
    for (int i = 0; i < cleanWord.length; i++) {
      blocks.add(LetterBlock(id: i, letter: cleanWord[i]));
    }

    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = Random();
    final extraCount = cleanWord.length <= 4 ? 3 : 2;

    for (int i = 0; i < extraCount; i++) {
      final extraChar = alphabet[rand.nextInt(alphabet.length)];
      blocks.add(LetterBlock(id: 100 + i, letter: extraChar));
    }

    blocks.shuffle();

    if (!mounted) return;
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
    if (!mounted) return;
    setState(() => _cheerToast = msg);
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _cheerToast == msg) {
        setState(() => _cheerToast = null);
      }
    });
  }

  void _useHint() {
    if (_isAnswerChecked || !mounted) return;

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
      if (!mounted) return;
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
    if (_isAnswerChecked || block.isUsed || !mounted) return;

    final targetWord = (_questions[_currentIndex]['word'] ?? '')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');

    if (_placedLetters.length >= targetWord.length) return;

    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      block.isUsed = true;
      _placedLetters.add(block);
    });

    if (_placedLetters.length == targetWord.length) {
      _checkAnswer(targetWord);
    }
  }

  void _onPlacedLetterTap(LetterBlock block) {
    if (_isAnswerChecked || !mounted) return;

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

    if (!mounted) return;
    setState(() {
      _isAnswerChecked = true;
      _isCorrect = correct;
    });

    if (cardId > 0) {
      await DatabaseHelper.instance.recordMultiModalResult(
        cardId: cardId,
        isCorrect: correct,
        mode: 'spelling',
      );
    }

    if (!mounted) return; 

    if (correct) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;
      
      final baseXp = _hintsUsedInWord > 0 ? 5 : 8;
      final earnedXp = baseXp * widget.xpMultiplier;

      // P0-D: örnek kelime havuzuyla (negatif cardId) yapılan deneme
      // pratiği XP kazandırmasın — sadece gerçek kelimeler XP verir.
      if (cardId > 0) {
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
      if (_currentIndex + 1 < _questions.length) {
        setState(() => _currentIndex++);
        _loadCurrentWord();
      } else {
        _finishSpelling();
      }
    });
  }

  Future<void> _finishSpelling() async {
    if (!mounted) return;

    final feedback = CoachMessages.getFeedback(
      exerciseType: 'spelling',
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
          // _loadCurrentWord() kendi setState'ini tetikliyor; iç içe
          // (nested) setState çağrısından kaçınmak için DIŞARIDA çağrılır.
          if (!mounted) return;
          _loadCurrentWord();
        } else {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<DraconicTheme>()!;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          title: Text('Dinle & Yaz', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: CircularProgressIndicator(color: theme.infoTeal),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          title: Text('Dinle & Yaz', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: EmptyWordPoolState(
          message: 'Yazım pratiği için Kitaplığında geçerli bir kelime bulunamadı.',
          onGoToLibrary: widget.onNavigateToLibrary,
        ),
      );
    }

    final currentCard = _questions[_currentIndex];
    final meaning = currentCard['meaning'] ?? 'Tanım yok';
    final currentWordText = currentCard['word'] ?? '';
    final progress = (_currentIndex + 1) / _questions.length;
    final targetWord = currentWordText.toString().trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

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
            Text('Dinle & Yaz', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: theme.textPrimary, fontSize: 16)),
            if (widget.xpMultiplier > 1)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '~+8 XP',
                    style: GoogleFonts.outfit(
                      color: theme.textMuted,
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '⚡ ${8 * widget.xpMultiplier} XP (2X Şanslı Mod!)',
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
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.lightbulbBold, color: theme.primaryAmber),
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
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textSecondary),
                      ),
                      Row(
                        children: [
                          Icon(PhosphorIcons.lightningBold, color: theme.primaryAmber, size: 16),
                          const SizedBox(width: 4),
                          Text('$_score Doğru', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.primaryAmber)),
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
                      backgroundColor: theme.surfaceDark,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.infoTeal),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    decoration: BoxDecoration(
                      color: theme.surfaceDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.borderSubtle, width: 1.5),
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
                            backgroundColor: theme.infoTeal,
                            padding: const EdgeInsets.all(14),
                          ),
                          icon: Icon(Icons.volume_up_rounded, color: theme.background, size: 28),
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
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(targetWord.length, (index) {
                      final hasLetter = index < _placedLetters.length;
                      final letterBlock = hasLetter ? _placedLetters[index] : null;

                      Color boxBorderColor = theme.borderSubtle;
                      Color boxBgColor = theme.surfaceDark;

                      if (_isAnswerChecked) {
                        boxBorderColor = _isCorrect ? theme.successEmerald : theme.dangerRed;
                        boxBgColor = (_isCorrect ? theme.successEmerald : theme.dangerRed).withValues(alpha: 0.15);
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
                              color: hasLetter ? theme.infoTeal : boxBorderColor,
                              width: hasLetter ? 2 : 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            hasLetter ? letterBlock!.letter : '',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),

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
                              color: theme.surfaceDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.borderSubtle,
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
                                color: theme.textPrimary,
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