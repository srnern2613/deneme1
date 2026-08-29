// ============================================================================
// DOSYA ADI: lib/flashcards_exercise_screen.dart
// AÇIKLAMA: %38 Swipe Eşiği Korumalı, Çift Tetikleme Kilitli,
//           Bağlamsal Öğrenme, Dinamik Renkli Seans Sonu ve Güvenli Mini-Review
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tts_service.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';
import 'database_helper.dart';
import 'dictionary_service.dart';

class FlashcardsExerciseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final bool isReviewOnly;

  const FlashcardsExerciseScreen({
    super.key, 
    required this.cards,
    this.isReviewOnly = false,
  });

  @override
  State<FlashcardsExerciseScreen> createState() => _FlashcardsExerciseScreenState();
}

class _FlashcardsExerciseScreenState extends State<FlashcardsExerciseScreen> {
  late List<Map<String, dynamic>> _remainingCards;
  final List<Map<String, dynamic>> _struggledCards = [];

  int _knownCount = 0;
  int _hardCount = 0;
  int _reviewCount = 0;
  int _initialTotal = 0;
  int _consecutiveKnownStreak = 0;
  int _totalEarnedXp = 0;

  String? _cheerMessage;
  bool _isFlipped = false;
  bool _showHint = false;
  bool _celebrationShown = false;
  bool _isProcessing = false;

  final Map<String, WordDefinitionResult?> _definitionCache = {};

  static const Map<String, String> _posTranslations = {
    'noun': 'İSİM',
    'verb': 'FİİL',
    'adjective': 'SIFAT',
    'adverb': 'ZARF',
    'pronoun': 'ZAMİR',
    'preposition': 'EDAT',
    'conjunction': 'BAĞLAÇ',
    'interjection': 'ÜNLEM',
    'determiner': 'BELİRTEÇ',
    'article': 'TANIMLIK',
    'phrase': 'DEYİM / İFADE',
  };

  String _formatTurkishPos(String? pos) {
    if (pos == null || pos.trim().isEmpty) return '';
    final clean = pos.trim().toLowerCase();
    return _posTranslations[clean] ?? pos.toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _remainingCards = List.from(widget.cards)..shuffle();
    _initialTotal = _remainingCards.length;
    _prefetchCurrentCardDetails();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  void _prefetchCurrentCardDetails() {
    if (_remainingCards.isEmpty) return;
    final word = _remainingCards.first['word']?.toString().trim().toLowerCase() ?? '';
    if (word.isNotEmpty && !_definitionCache.containsKey(word)) {
      DictionaryService.instance.fetchWordMeaning(word).then((result) {
        if (mounted) {
          setState(() {
            _definitionCache[word] = result;
          });
        }
      }).catchError((_) {});
    }
  }

  void _triggerCheer(String message) {
    setState(() => _cheerMessage = message);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _cheerMessage == message) {
        setState(() => _cheerMessage = null);
      }
    });
  }

  void _handleSrsRating(int rating) {
    if (_remainingCards.isEmpty || _isProcessing) return;

    _isProcessing = true;
    TtsService.instance.stop();

    if (rating == 2) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }

    final currentCard = _remainingCards.first;
    final int cardId = currentCard['id'] as int? ?? 0;
    int currentReps = currentCard['repetitions'] as int? ?? 0;
    int currentInterval = currentCard['interval'] as int? ?? 1;

    int newReps = currentReps;
    int newInterval = currentInterval;
    int xpGain = 0;

    if (rating == 0) {
      newReps = 0;
      newInterval = 1;
      _consecutiveKnownStreak = 0;
      _reviewCount++;
      _struggledCards.add(currentCard);

      if (_reviewCount % 3 == 0) {
        _triggerCheer(CoachMessages.getWrongAnswerEncouragement());
      }
    } else if (rating == 1) {
      _hardCount++;
      _consecutiveKnownStreak = 0;
      _struggledCards.add(currentCard);
      newReps += 1;
      newInterval = (currentInterval * 1.3).round().clamp(1, 30);
      xpGain = 4;
    } else {
      _knownCount++;
      _consecutiveKnownStreak++;
      newReps += 1;
      newInterval = (currentInterval * 2.4).round().clamp(3, 120);
      xpGain = 6;

      final cheer = CoachMessages.getFlashcardCheer(_consecutiveKnownStreak);
      if (cheer != null) {
        _triggerCheer(cheer);
      }
    }

    if (!widget.isReviewOnly) {
      if (xpGain > 0) {
        _totalEarnedXp += xpGain;
        XpShopService.instance.addXp(xpGain).catchError((_) => 0);
      }

      if (cardId > 0) {
        DatabaseHelper.instance.updateFlashcardSrsProgress(
          cardId: cardId,
          repetitions: newReps,
          interval: newInterval,
        ).catchError((_) {});
      }
    }

    setState(() {
      _remainingCards.removeAt(0);
      _isFlipped = false;
      _showHint = false;
      _isProcessing = false;
    });

    _prefetchCurrentCardDetails();

    if (_remainingCards.isEmpty && !_celebrationShown) {
      _celebrationShown = true;
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        _finishSrs();
      });
    }
  }

  void _finishSrs() {
    if (widget.isReviewOnly) {
      Navigator.of(context).pop();
      return;
    }

    final feedback = CoachMessages.getFeedback(
      exerciseType: 'srs',
      score: _knownCount,
      total: _initialTotal,
    );

    final needsReviewCount = _reviewCount + _hardCount;

    CelebrationDialog.show(
      context,
      emoji: feedback.emoji,
      title: feedback.title,
      subtitle: feedback.subtitle,
      themeColor: feedback.themeColor,
      earnedXp: _totalEarnedXp,
      earnedGems: _knownCount == _initialTotal && _initialTotal >= 5 ? 5 : 0,
      totalWordsReviewed: _initialTotal,
      strengthenedWords: _knownCount,
      needsReviewWords: needsReviewCount,
      actionLabel: feedback.actionLabel,
      onAction: () {
        Navigator.of(context).pop();
      },
      secondaryActionLabel: needsReviewCount > 0 
          ? '🧠 Zorlandıklarımı Gör ($needsReviewCount kelime)' 
          : null,
      onSecondaryAction: needsReviewCount > 0 
          ? () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardsExerciseScreen(
                    cards: List.from(_struggledCards),
                    isReviewOnly: true,
                  ),
                ),
              );
            }
          : null,
    );
  }

  String _getEstimatedSessionTime() {
    int totalSec = _initialTotal * 15;
    int minutes = (totalSec / 60).ceil();
    return '~$minutes dk';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.isReviewOnly ? 'Kelimeleri Gözden Geçir' : 'Bugünün Tekrarı',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text(
              '$_initialTotal kelime • ${_getEstimatedSessionTime()}',
              style: TextStyle(fontSize: 11.5, color: colors.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _remainingCards.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _buildExerciseView(colors, textStyles),

            if (_cheerMessage != null)
              Positioned(
                top: 10,
                left: 20,
                right: 20,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 250),
                  offset: _cheerMessage != null ? Offset.zero : const Offset(0, -1.5),
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
                      _cheerMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseView(ColorScheme colors, TextTheme textStyles) {
    final currentCard = _remainingCards.first;
    final String currentWord = currentCard['word'] ?? '';
    final String? contextSentence = currentCard['context_sentence'] as String?;
    final String bookTitle = (currentCard['book_title'] as String?)?.trim().isNotEmpty == true 
        ? currentCard['book_title'] 
        : 'Kütüphanem';
    final String? chapterInfo = currentCard['chapter_info'] as String?;

    final int currentIndex = _initialTotal - _remainingCards.length + 1;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final wordKey = currentWord.trim().toLowerCase();
    final defData = _definitionCache[wordKey];

    String effectiveMeaning = (currentCard['meaning'] as String? ?? '').trim();
    if (effectiveMeaning.isEmpty && defData != null) {
      effectiveMeaning = defData.primaryMeaning;
    }

    final String rawPos = defData?.partOfSpeech ?? '';
    final String formattedPos = _formatTurkishPos(rawPos);

    final bool hasValidContext = contextSentence != null && contextSentence.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kelime $currentIndex / $_initialTotal',
                style: textStyles.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green[600], size: 16),
                  const SizedBox(width: 4),
                  Text('$_knownCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 10),
                  Icon(Icons.replay_circle_filled_rounded, color: colors.error, size: 16),
                  const SizedBox(width: 4),
                  Text('$_reviewCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (currentIndex - 1) / _initialTotal,
            borderRadius: BorderRadius.circular(8),
            minHeight: 5,
          ),
          const SizedBox(height: 14),

          Expanded(
            child: Dismissible(
              key: ValueKey('${currentCard['id']}_$currentIndex'),
              // Sadece kart açıkken kaydırmaya izin verilir
              direction: _isFlipped && !_isProcessing
                  ? DismissDirection.horizontal 
                  : DismissDirection.none,
              // %38 minimum sürükleme eşiği
              dismissThresholds: const {
                DismissDirection.startToEnd: 0.38,
                DismissDirection.endToStart: 0.38,
              },
              confirmDismiss: (direction) async {
                if (_isProcessing) return false;
                return true;
              },
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  _handleSrsRating(2); // Sağa = Bildim
                } else {
                  _handleSrsRating(0); // Sola = Tekrar
                }
              },
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 30),
                    SizedBox(width: 8),
                    Text('BİLDİM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('TEKRAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    SizedBox(width: 8),
                    Icon(Icons.replay_rounded, color: Colors.white, size: 30),
                  ],
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  if (_isProcessing) return;
                  HapticFeedback.selectionClick();
                  setState(() => _isFlipped = !_isFlipped);
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : colors.outlineVariant.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.menu_book_rounded, size: 13, color: colors.primary),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        '$bookTitle ${chapterInfo != null ? '• $chapterInfo' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: colors.primary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: colors.primary.withValues(alpha: 0.12),
                                padding: const EdgeInsets.all(8),
                              ),
                              icon: Icon(Icons.volume_up_rounded, color: colors.primary, size: 22),
                              tooltip: 'Telaffuzu Dinle',
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                TtsService.instance.speakWord(currentWord);
                              },
                            ),
                          ],
                        ),

                        const Spacer(),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentWord,
                              textAlign: TextAlign.center,
                              style: textStyles.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            if (formattedPos.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                formattedPos,
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                            if (_isFlipped) ...[
                              const SizedBox(height: 12),
                              Text(
                                effectiveMeaning.isNotEmpty ? effectiveMeaning : 'anlam yükleniyor...',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const Spacer(),

                        if (hasValidContext) ...[
                          if (!_isFlipped) ...[
                            if (!_showHint)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  backgroundColor: colors.primary.withValues(alpha: 0.08),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                                label: const Text('Kitaptan İpucu Gör', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _showHint = true);
                                },
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '“${contextSentence.replaceAll(RegExp(RegExp.escape(currentWord), caseSensitive: false), '___')}”',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                '“$contextSentence”',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 5),
                            Text(
                              _isFlipped ? 'Gizlemek için dokun' : 'Cevabı görmek için dokun',
                              style: TextStyle(fontSize: 11.5, color: colors.onSurface.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (!_isFlipped)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.flip_rounded, size: 20),
                label: const Text('Cevabı Göster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () {
                  if (_isProcessing) return;
                  HapticFeedback.selectionClick();
                  setState(() => _isFlipped = true);
                },
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildNaturalSrsButton(
                    title: 'Tekrar',
                    sub: 'Hatırlayamadım',
                    color: Colors.red.shade400,
                    icon: Icons.replay_rounded,
                    onTap: () => _handleSrsRating(0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNaturalSrsButton(
                    title: 'Zor',
                    sub: 'Zorlandım',
                    color: Colors.orange.shade400,
                    icon: Icons.timelapse_rounded,
                    onTap: () => _handleSrsRating(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildNaturalSrsButton(
                    title: 'Bildim',
                    sub: 'Rahat hatırladım',
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_rounded,
                    onTap: () => _handleSrsRating(2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNaturalSrsButton({
    required String title,
    required String sub,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.85)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}