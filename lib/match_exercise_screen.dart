// ============================================================================
// DOSYA ADI: lib/match_exercise_screen.dart
// AÇIKLAMA: Kelime Eşleştirme & Çok Boyutlu Modalite/Boss Entegreli Oyun
// GÖREVLER & DÜZELTMELER:
//   1. Modalite Entegrasyonu: 'recordMultiModalResult(mode: "match")' üzerinden atomik kayıt.
//   2. Boss Tetikleme: Hatalı eşleşmelerde ilgili kelimenin hata sayacı güncellenir.
//   3. Çok Boyutlu Mastery: Başarılı eşleştirmeler 'modes_passed' alanına 'match' olarak işlenir.
//   4. Boş anlam filtrelemesi ve dinamik grid yapısı korundu.
//   5. Semantik Renk Standardı: %70-80 koyu zemin (#070B14), %10-20 panel (#111827).
// ============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
    TtsService.instance.initService();
    _restartGame();
  }

  void _restartGame() {
    // Sadece hem kelimesi hem de anlamı dolu olan kartları havuza al
    _pool = widget.cards.where((c) {
      final w = (c['word'] ?? '').toString().trim();
      final m = (c['meaning'] ?? '').toString().trim();
      return w.isNotEmpty && m.isNotEmpty && m != 'Tanım yok';
    }).toList()..shuffle();

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

    // Doğru eşleşme kontrolü
    if (_selectedItem!.pairId == item.pairId && _selectedItem!.isEnglish != item.isEnglish) {
      HapticFeedback.mediumImpact();
      _combo++;
      _score += 2;

      // 🎯 ÇOK BOYUTLU MODALİTE BAŞARISI KAYDI
      if (item.cardId > 0) {
        DatabaseHelper.instance.recordMultiModalResult(
          cardId: item.cardId,
          isCorrect: true,
          mode: 'match',
        );
      }

      final multiplier = _combo >= 6 ? 2 : 1;
      final earnedXp = 4 * multiplier;
      _totalEarnedXp += earnedXp;
      await XpShopService.instance.addXp(earnedXp);

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
      // 🔴 Yanlış eşleşme: Hata bildirimi ve Boss adaylığı tetiklemesi
      HapticFeedback.heavyImpact();
      _combo = 0;
      _triggerCheer(CoachMessages.getWrongAnswerEncouragement());

      if (_selectedItem!.cardId > 0) {
        DatabaseHelper.instance.recordMultiModalResult(
          cardId: _selectedItem!.cardId,
          isCorrect: false,
          mode: 'match',
        );
      }

      setState(() => _selectedItem = null);
    }
  }

  void _finishGame() {
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
        title: Text(
          'Kelime Eşleştirme',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18),
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