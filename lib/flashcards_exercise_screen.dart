// ==============================================================
// flashcards_exercise_screen.dart
// --------------------------------------------------------------
// SES DESTEKLİ SRS EGZERSİZİ + CANLI KOÇLUK MESAJLARI (STREAK CHEERS)
// ==============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tts_service.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';

class FlashcardsExerciseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;

  const FlashcardsExerciseScreen({super.key, required this.cards});

  @override
  State<FlashcardsExerciseScreen> createState() => _FlashcardsExerciseScreenState();
}

class _FlashcardsExerciseScreenState extends State<FlashcardsExerciseScreen> {
  late List<Map<String, dynamic>> _remainingCards;

  int _knownCount = 0;
  int _reviewCount = 0;
  int _initialTotal = 0;
  int _consecutiveKnownStreak = 0;
  String? _cheerMessage;
  bool _isFlipped = false;
  bool _celebrationShown = false;

  @override
  void initState() {
    super.initState();
    _remainingCards = List.from(widget.cards)..shuffle();
    _initialTotal = _remainingCards.length;
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  void _triggerCheer(String message) {
    setState(() => _cheerMessage = message);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _cheerMessage == message) {
        setState(() => _cheerMessage = null);
      }
    });
  }

  Future<void> _handleCardDismiss(DismissDirection direction) async {
    TtsService.instance.stop();
    if (direction == DismissDirection.startToEnd) {
      await XpShopService.instance.addXp(5);
      
      _consecutiveKnownStreak++;
      final cheer = CoachMessages.getFlashcardCheer(_consecutiveKnownStreak);
      if (cheer != null) {
        _triggerCheer(cheer);
      }

      setState(() {
        _knownCount++;
        _remainingCards.removeAt(0);
        _isFlipped = false;
      });
    } else {
      _consecutiveKnownStreak = 0;
      if (_reviewCount % 3 == 0 && _reviewCount > 0) {
        _triggerCheer(CoachMessages.getWrongAnswerEncouragement());
      }
      setState(() {
        _reviewCount++;
        _remainingCards.removeAt(0);
        _isFlipped = false;
      });
    }

    if (_remainingCards.isEmpty && !_celebrationShown) {
      _celebrationShown = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        CelebrationDialog.show(
          context,
          emoji: '🎯',
          title: 'Kelime Egzersizi Tamam!',
          subtitle: '$_initialTotal kelimeden $_knownCount tanesini eksiksiz bildin. Hafıza kasların güçleniyor!',
          earnedXp: _knownCount * 5,
          actionLabel: 'Harika!',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Egzersizi'),
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
                ? _buildCompletionView(colors, textStyles)
                : _buildExerciseView(colors, textStyles),

            // CANLI KOÇLUK BANNERI
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
    final int currentIndex = _initialTotal - _remainingCards.length + 1;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kart $currentIndex / $_initialTotal',
                style: textStyles.titleMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green[600], size: 18),
                  const SizedBox(width: 4),
                  Text('$_knownCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Icon(Icons.replay_circle_filled_rounded, color: colors.error, size: 18),
                  const SizedBox(width: 4),
                  Text('$_reviewCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (currentIndex - 1) / _initialTotal,
            borderRadius: BorderRadius.circular(8),
            minHeight: 6,
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Dismissible(
              key: ValueKey(currentCard['id'] ?? currentWord),
              direction: DismissDirection.horizontal,
              onDismissed: _handleCardDismiss,
              
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: Colors.green[600],
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.thumb_up_rounded, color: Colors.white, size: 32),
                    SizedBox(width: 10),
                    Text(
                      'BİLDİM (+5 XP)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
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
                    Text(
                      'TEKRAR ET',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.replay_rounded, color: Colors.white, size: 32),
                  ],
                ),
              ),

              child: GestureDetector(
                onTap: () => setState(() => _isFlipped = !_isFlipped),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : colors.outlineVariant.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text(
                                _isFlipped ? 'TÜRKÇE ANLAMI' : 'İNGİLİZCE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isFlipped ? colors.onPrimaryContainer : colors.onSecondaryContainer,
                                ),
                              ),
                              backgroundColor: _isFlipped ? colors.primaryContainer : colors.secondaryContainer,
                            ),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: colors.primary.withValues(alpha: 0.12),
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

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _isFlipped
                                ? (currentCard['meaning'] ?? '')
                                : currentWord,
                            key: ValueKey(_isFlipped),
                            textAlign: TextAlign.center,
                            style: textStyles.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _isFlipped
                                  ? colors.primary
                                  : (isDark ? const Color(0xFFF8FAFC) : colors.onSurface),
                            ),
                          ),
                        ),
                        const Spacer(),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(width: 6),
                            Text(
                              _isFlipped ? 'Gizlemek için dokunun' : 'Anlamı görmek için dokunun',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
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
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(Icons.close_rounded, color: colors.error),
                  label: Text('Bilemedim', style: TextStyle(color: colors.error)),
                  onPressed: () => _handleCardDismiss(DismissDirection.endToStart),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text('Bildim', style: TextStyle(color: Colors.white)),
                  onPressed: () => _handleCardDismiss(DismissDirection.startToEnd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView(ColorScheme colors, TextTheme textStyles) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: isDark ? const Color(0xFF064E3B) : Colors.green[100],
              child: Icon(Icons.emoji_events_rounded, size: 54, color: isDark ? Colors.green[300] : Colors.green[700]),
            ),
            const SizedBox(height: 24),
            Text('Tebrikler! 🎉', style: textStyles.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Egzersiz tamamlandı. XP seviyen yükseldi!',
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : colors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildResultStat('Toplam', '$_initialTotal', colors.primary, isDark),
                  _buildResultStat('Bildim', '$_knownCount', Colors.green[600]!, isDark),
                  _buildResultStat('Tekrar', '$_reviewCount', colors.error, isDark),
                  _buildResultStat('Kazanılan XP', '+${_knownCount * 5} ⚡', Colors.amber[800]!, isDark),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Egzersizi Tekrarla'),
                onPressed: () {
                  setState(() {
                    _remainingCards = List.from(widget.cards)..shuffle();
                    _knownCount = 0;
                    _reviewCount = 0;
                    _isFlipped = false;
                    _celebrationShown = false;
                    _consecutiveKnownStreak = 0;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Kartlarıma Dön'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
          ),
        ),
      ],
    );
  }
}