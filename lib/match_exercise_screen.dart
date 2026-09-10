// ============================================================================
// DOSYA ADI: lib/match_exercise_screen.dart
// AÇIKLAMA: Kelime Eşleştirme & Çok Boyutlu Modalite/Boss Entegreli Oyun
//           (Hile Korumalı xpMultiplier Zırhı ve Şeffaf 2X Çapalama Tasarımı)
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';
import 'tts_service.dart';

class MatchItem {
  final String id;
  final String text;
  final bool isEnglish;
  final String pairId;
  final int cardId;

  MatchItem({
    required this.id,
    required this.text,
    required this.isEnglish,
    required this.pairId,
    required this.cardId,
  });
}

class MatchExerciseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final int xpMultiplier; // Dinamik 2X XP FOMO Koruması

  const MatchExerciseScreen({
    super.key, 
    required this.cards,
    this.xpMultiplier = 1,
  });

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
  bool _isLoading = true;

  int _sessionLimit = 0;
  String _learningStateFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    TtsService.instance.initService();
    _loadSettingsAndInitGame();
  }

  Future<void> _loadSettingsAndInitGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      _sessionLimit = prefs.getInt('arena_session_limit') ?? 0;
      _learningStateFilter = prefs.getString('arena_state_filter') ?? 'ALL';

      var filteredCards = widget.cards.where((c) {
        final w = (c['word'] ?? '').toString().trim();
        final m = (c['meaning'] ?? '').toString().trim();
        if (w.isEmpty || m.isEmpty || m == 'Tanım yok') return false;
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
        _pool = filteredCards;
        _score = 0;
        _combo = 0;
        _totalEarnedXp = 0;
        _timeLeft = 45;
        _selectedItem = null;
        _isLoading = false;
      });

      _setupBoard();
      _startTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _restartGame() {
    _loadSettingsAndInitGame();
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
    if (!mounted) return;
    final count = min(3, _pool.length);
    final selectedPairs = _pool.take(count).toList();
    _pool.removeRange(0, count);

    List<MatchItem> items = [];
    for (var card in selectedPairs) {
      final pairId = card['id']?.toString() ?? card['word'];
      final cardDbId = card['id'] as int? ?? 0;

      items.add(MatchItem(
        id: '${pairId}_en',
        text: (card['word'] ?? '').toString().trim(),
        isEnglish: true,
        pairId: pairId,
        cardId: cardDbId,
      ));
      items.add(MatchItem(
        id: '${pairId}_tr',
        text: (card['meaning'] ?? '').toString().trim(),
        isEnglish: false,
        pairId: pairId,
        cardId: cardDbId,
      ));
    }

    items.shuffle();
    if (!mounted) return;
    setState(() => _activeItems = items);
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

  void _onItemTapped(MatchItem item) async {
    HapticFeedback.selectionClick();

    if (item.isEnglish) {
      TtsService.instance.speakWord(item.text);
    }

    if (_selectedItem == null) {
      if (!mounted) return;
      setState(() => _selectedItem = item);
      return;
    }

    if (_selectedItem!.id == item.id) {
      if (!mounted) return;
      setState(() => _selectedItem = null);
      return;
    }

    // Doğru eşleşme kontrolü
    if (_selectedItem!.pairId == item.pairId && _selectedItem!.isEnglish != item.isEnglish) {
      HapticFeedback.mediumImpact();
      _combo++;
      _score += 2;

      if (item.cardId > 0) {
        await DatabaseHelper.instance.recordMultiModalResult(
          cardId: item.cardId,
          isCorrect: true,
          mode: 'match',
        );
      }

      if (!mounted) return;

      final comboMultiplier = _combo >= 6 ? 2 : 1;
      final earnedXp = (4 * comboMultiplier) * widget.xpMultiplier; 
      _totalEarnedXp += earnedXp;
      await XpShopService.instance.addXp(earnedXp);

      if (!mounted) return;

      final firstId = _selectedItem!.id;
      final secondId = item.id;

      setState(() {
        _selectedItem = null;
        _activeItems.removeWhere((i) => i.id == firstId || i.id == secondId);
      });

      if (_combo == 4 || _combo == 8) {
        _triggerCheer(CoachMessages.getFlashcardCheer(_combo) ?? '🔥 Harika Kombo!');
      }

      if (_activeItems.isEmpty) {
        if (_pool.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _setupBoard();
          });
        } else {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) _finishGame();
          });
        }
      }
    } else {
      HapticFeedback.heavyImpact();
      _combo = 0;
      _triggerCheer(CoachMessages.getWrongAnswerEncouragement());

      if (_selectedItem!.cardId > 0) {
        await DatabaseHelper.instance.recordMultiModalResult(
          cardId: _selectedItem!.cardId,
          isCorrect: false,
          mode: 'match',
        );
      }

      if (!mounted) return;
      setState(() => _selectedItem = null);
    }
  }

  void _finishGame() {
    if (!mounted) return;
    _timer?.cancel();
    final totalExpected = max(6, widget.cards.length * 2);
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
      earnedGems: _score >= 12 ? 5 : 0,
      actionLabel: feedback.actionLabel,
      onAction: () {
        if (!mounted) return;
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070B14),
          elevation: 0,
          title: Text('Kelime Eşleştirme', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (_activeItems.isEmpty && _pool.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070B14),
          elevation: 0,
          title: Text('Kelime Eşleştirme', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text('Eşleştirilecek geçerli kelime bulunamadı.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kelime Eşleştirme', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
            if (widget.xpMultiplier > 1)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '~+4 XP', 
                    style: GoogleFonts.outfit(
                      color: Colors.grey.shade500, 
                      fontSize: 10, 
                      decoration: TextDecoration.lineThrough,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '⚡ ${4 * widget.xpMultiplier} XP (2X Şanslı Mod!)', 
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFF59E0B), 
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
          icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(PhosphorIcons.timerBold, size: 16, color: Color(0xFFEF4444)),
                            const SizedBox(width: 6),
                            Text(
                              '$_timeLeft sn',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              '$_combo Kombo',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFA855F7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: Center(
                      child: GridView.builder(
                        shrinkWrap: true,
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

                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => _onItemTapped(item),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6366F1).withValues(alpha: 0.22)
                                    : const Color(0xFF111827),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF1F2937),
                                  width: isSelected ? 2 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
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
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF818CF8) : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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