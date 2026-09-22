// ============================================================================
// DOSYA ADI: lib/cloze_exercise_screen.dart
// AÇIKLAMA: Cümlede Boşluk Doldurma (Cloze) — ÜCRETSİZ Vitrin Modu.
//           Kullanıcının kendi kitabından gelen gerçek cümle içinde hedef
//           kelime boşluk bırakılır; 4 İngilizce kelime seçeneğinden doğrusu
//           bulunur. Quiz modundaki (quiz_exercise_screen.dart) çeldirici/anti-
//           hile desenleri AYNEN uygulanmıştır (Hile Korumalı Dinamik
//           xpMultiplier ve Şeffaf Çapalama Tasarımı).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';
import 'database_helper.dart';
import 'core/design_system/primitives.dart';
import 'core/coach/ignis_moments_engine.dart';
import 'core/theme/draconic_theme.dart'; // T-1: yapısal renkler temadan

class ClozeExerciseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final int xpMultiplier; // Dinamik 2X XP FOMO Koruması
  final VoidCallback? onNavigateToLibrary;

  const ClozeExerciseScreen({
    super.key,
    required this.cards,
    this.xpMultiplier = 1,
    this.onNavigateToLibrary,
  });

  @override
  State<ClozeExerciseScreen> createState() => _ClozeExerciseScreenState();
}

class _ClozeExerciseScreenState extends State<ClozeExerciseScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _totalEarnedXp = 0;
  String? _selectedOption;
  bool _answered = false;
  List<String> _currentOptions = [];
  String _blankedSentence = '';
  String? _cheerToast;
  bool _isLoading = true;

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
    _loadSettingsAndInitQuestions();
  }

  RegExp _wordPattern(String word) {
    return RegExp(r'\b' + RegExp.escape(word.trim()) + r'\b', caseSensitive: false);
  }

  Future<void> _loadSettingsAndInitQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      _sessionLimit = prefs.getInt('arena_session_limit') ?? 0;
      _learningStateFilter = prefs.getString('arena_state_filter') ?? 'ALL';

      // Sadece context_sentence dolu VE cümle içinde kelimenin gerçekten
      // geçtiği kartlar bu moda girebilir — aksi halde boşluk açılamaz.
      var filteredCards = widget.cards.where((c) {
        final w = (c['word'] ?? '').toString().trim();
        final m = (c['meaning'] ?? '').toString().trim();
        final sentence = (c['context_sentence'] ?? '').toString().trim();
        if (w.isEmpty || m.isEmpty || sentence.isEmpty) return false;
        if (!_wordPattern(w).hasMatch(sentence)) return false;
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

      _loadOptionsForCurrent();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questions = [];
        _isLoading = false;
      });
    }
  }

  void _loadOptionsForCurrent() {
    if (!mounted) return;
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;

    final currentCard = _questions[_currentIndex];
    final correctWord = (currentCard['word'] ?? '').toString().trim();
    final sentence = (currentCard['context_sentence'] ?? '').toString().trim();

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
      _blankedSentence = sentence.replaceFirst(_wordPattern(correctWord), '_____');
      _selectedOption = null;
      _answered = false;
    });
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

    final currentCard = _questions[_currentIndex];
    final correctWord = (currentCard['word'] ?? '').toString().trim();
    final isCorrect = (option.toLowerCase() == correctWord.toLowerCase());
    final cardId = currentCard['id'] as int? ?? 0;

    if (!mounted) return;
    setState(() {
      _selectedOption = option;
      _answered = true;
    });

    if (cardId > 0) {
      await DatabaseHelper.instance.recordMultiModalResult(
        cardId: cardId,
        isCorrect: isCorrect,
        mode: 'cloze',
      );
    }

    if (!mounted) return;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;

      final earnedXp = 7 * widget.xpMultiplier;
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

    Future.delayed(const Duration(milliseconds: 1300), () {
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
      _finishCloze();
    }
  }

  Future<void> _finishCloze() async {
    if (!mounted) return;

    final feedback = CoachMessages.getFeedback(
      exerciseType: 'cloze',
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
          // _loadOptionsForCurrent() kendi setState'ini tetikliyor; iç içe
          // (nested) setState çağrısından kaçınmak için DIŞARIDA çağrılır.
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          title: Text('Cümlede Boşluk Doldurma', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        body: Center(
          child: CircularProgressIndicator(color: theme.successEmerald),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.background,
          elevation: 0,
          title: Text('Cümlede Boşluk Doldurma', style: GoogleFonts.outfit(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        body: EmptyWordPoolState(
          message: 'Bu mod, kelimenin kitabındaki gerçek cümlesini kullanır. Cümle bilgisi olan yeterli kelime bulunamadı — kitaplığından okumaya devam et.',
          onGoToLibrary: widget.onNavigateToLibrary,
        ),
      );
    }

    final correctWord = (_questions[_currentIndex]['word'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cümlede Boşluk Doldurma', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: theme.textPrimary, fontSize: 14)),
            if (widget.xpMultiplier > 1)
              Text(
                '⚡ ${7 * widget.xpMultiplier} XP (2X Şanslı Mod!)',
                style: GoogleFonts.outfit(color: theme.primaryAmber, fontSize: 10.5, fontWeight: FontWeight.w900),
              ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.textPrimary),
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
                        'Cümle ${_currentIndex + 1} / ${_questions.length}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: theme.textSecondary),
                      ),
                      Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text('$_streak Seri', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.textPrimary)),
                          const SizedBox(width: 12),
                          Icon(PhosphorIcons.lightningBold, color: theme.successEmerald, size: 16),
                          const SizedBox(width: 2),
                          Text('$_score', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.successEmerald)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 22),
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
                        Icon(PhosphorIcons.bookOpenTextBold, color: theme.successEmerald, size: 26),
                        const SizedBox(height: 14),
                        Text(
                          _blankedSentence,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                            color: theme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

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
    );
  }
}
