// ============================================================================
// DOSYA ADI: lib/match_exercise_screen.dart
// AÇIKLAMA: Kombo Çarpanlı, Süreli & Psikolojik Geri Bildirimli Eşleştirme
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';
import 'tts_service.dart';

class MatchItem {
  final String id;
  final String text;
  final bool isEnglish;
  final String pairId;
  bool isMatched;

  MatchItem({
    required this.id,
    required this.text,
    required this.isEnglish,
    required this.pairId,
    this.isMatched = false,
  });
}

class MatchExerciseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;

  const MatchExerciseScreen({super.key, required this.cards});

  @override
  State<MatchExerciseScreen> createState() => _MatchExerciseScreenState();
}

class _MatchExerciseScreenState extends State<MatchExerciseScreen> {
  List<MatchItem> _activeItems = [];
  List<Map<String, dynamic>> _pool = [];

  MatchItem? _selectedItem;
  int _score = 0;
  int _combo = 0;
  int _totalEarnedXp = 0;
  int _timeLeft = 45;
  Timer? _timer;
  String? _cheerToast;

  @override
  void initState() {
    super.initState();
    _restartGame();
  }

  void _restartGame() {
    _pool = List.from(widget.cards)..shuffle();
    _score = 0;
    _combo = 0;
    _totalEarnedXp = 0;
    _timeLeft = 45;
    _selectedItem = null;
    _setupBoard();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft > 1) {
        setState(() => _timeLeft--);
      } else {
        _timer?.cancel();
        _finishGame();
      }
    });
  }

  void _setupBoard() {
    final count = min(4, _pool.length);
    final selectedPairs = _pool.take(count).toList();
    _pool.removeRange(0, count);

    List<MatchItem> items = [];
    for (var card in selectedPairs) {
      final pairId = card['id']?.toString() ?? card['word'];
      items.add(MatchItem(
        id: '${pairId}_en',
        text: card['word'],
        isEnglish: true,
        pairId: pairId,
      ));
      items.add(MatchItem(
        id: '${pairId}_tr',
        text: card['meaning'],
        isEnglish: false,
        pairId: pairId,
      ));
    }

    items.shuffle();
    setState(() => _activeItems = items);
  }

  void _triggerCheer(String msg) {
    setState(() => _cheerToast = msg);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _cheerToast == msg) {
        setState(() => _cheerToast = null);
      }
    });
  }

  void _onItemTapped(MatchItem item) async {
    if (item.isMatched) return;

    HapticFeedback.selectionClick();

    if (item.isEnglish) {
      TtsService.instance.speakWord(item.text);
    }

    if (_selectedItem == null) {
      setState(() => _selectedItem = item);
      return;
    }

    if (_selectedItem!.id == item.id) {
      setState(() => _selectedItem = null);
      return;
    }

    if (_selectedItem!.pairId == item.pairId && _selectedItem!.isEnglish != item.isEnglish) {
      HapticFeedback.mediumImpact();
      _combo++;
      _score += 2;

      final multiplier = _combo >= 6 ? 2 : 1;
      final earnedXp = 4 * multiplier;
      _totalEarnedXp += earnedXp;
      await XpShopService.instance.addXp(earnedXp);

      setState(() {
        _selectedItem!.isMatched = true;
        item.isMatched = true;
        _selectedItem = null;
      });

      if (_combo == 4 || _combo == 8) {
        _triggerCheer(CoachMessages.getFlashcardCheer(_combo) ?? '🔥 Harika Kombo!');
      }

      if (_activeItems.every((i) => i.isMatched)) {
        if (_pool.isNotEmpty) {
          _setupBoard();
        } else {
          _finishGame();
        }
      }
    } else {
      HapticFeedback.heavyImpact();
      _combo = 0;
      _triggerCheer(CoachMessages.getWrongAnswerEncouragement());
      setState(() => _selectedItem = null);
    }
  }

  void _finishGame() {
    _timer?.cancel();
    final totalExpected = max(8, widget.cards.length * 2);
    final feedback = CoachMessages.getFeedback(
      exerciseType: 'match',
      score: _score,
      total: totalExpected,
    );

    CelebrationDialog.show(
      context,
      emoji: feedback.emoji,
      title: feedback.title,
      subtitle: feedback.subtitle,
      earnedXp: _totalEarnedXp,
      earnedGems: _score >= 16 ? 5 : 0,
      actionLabel: feedback.actionLabel,
      onAction: () {
        if (feedback.shouldOfferRetry) {
          setState(() {
            _restartGame();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Eşleştirme', style: TextStyle(fontWeight: FontWeight.bold)),
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
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 6),
                            Text(
                              '$_timeLeft sn',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              '$_combo Kombo',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _activeItems.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.8,
                      ),
                      itemBuilder: (context, index) {
                        final item = _activeItems[index];
                        final isSelected = (_selectedItem?.id == item.id);

                        if (item.isMatched) {
                          return const SizedBox.shrink();
                        }

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _onItemTapped(item),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.primary.withValues(alpha: 0.18)
                                  : (isDark ? const Color(0xFF131B2E) : Colors.white),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              item.text,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? colors.primary : (isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
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