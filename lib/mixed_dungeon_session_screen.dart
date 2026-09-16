// ============================================================================
// DOSYA ADI: lib/mixed_dungeon_session_screen.dart
// AÇIKLAMA: Ejderha Rotası V2 — Faz 3. "Zindana Gir" ana butonunun açtığı
// Otomatik Karma (Mixed) FSRS Zindan Oturumu. FsrsRepository'den gelen
// vadesi gelmiş (due) kartlar sırayla işlenir; her kartta rastgele bir soru
// tipi (Hızlı Test / Eşleştirme / Dinle & Yaz) seçilir, böylece kullanıcı
// tek bir pratik tipine mahkum kalmaz.
//
// Mevcut 4 ayrı egzersiz ekranı (flashcards/quiz/match/spelling) ve V1'in
// sabit-aralıklı sistemi (recordMultiModalResult) AYNEN korunuyor — bu
// ekran onların YERİNE değil, YANINDA, "Zindana Gir" akışı için ek bir
// giriş noktası olarak çalışıyor. Her cevaptan sonra hem V1 sistemine hem
// de FSRS'e paralel yazım yapılır.
// ============================================================================

import 'dart:async';
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
import 'core/fsrs/fsrs_repository.dart';
import 'core/fsrs/fsrs_models.dart';

enum _MixedMode { quiz, match, spelling }

class MixedDungeonSessionScreen extends StatefulWidget {
  /// Bu oturumda işlenecek kartlar — çağıran taraf (flashcards_screen.dart)
  /// bunu FsrsRepository.getDueCards() ile besliyor.
  final List<Map<String, dynamic>> cards;

  /// Çeldirici (distractor) üretimi için tüm havuz — [cards] azsa buradan
  /// ek anlamlar çekiliyor. Boşsa [cards] kullanılır.
  final List<Map<String, dynamic>> allCards;

  final int xpMultiplier;

  const MixedDungeonSessionScreen({
    super.key,
    required this.cards,
    this.allCards = const [],
    this.xpMultiplier = 1,
  });

  @override
  State<MixedDungeonSessionScreen> createState() => _MixedDungeonSessionScreenState();
}

class _MixedDungeonSessionScreenState extends State<MixedDungeonSessionScreen> {
  static const List<String> _fallbackDistractors = [
    'başlangıç, ilk adım',
    'görüşme, sohbet, diyalog',
    'dikkatlice bakmak, gözetlemek',
    'içine doğru, dahilinde',
    'kıyı, nehir kenarı, banka',
    'keşfetmek, açığa çıkarmak',
    'anlamak, kavramak, idrak etmek',
    'hızlıca ilerlemek, koşmak',
    'karar vermek, tercih etmek',
  ];

  final Random _rand = Random();

  List<Map<String, dynamic>> _questions = [];
  List<_MixedMode> _modeSequence = [];
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _totalEarnedXp = 0;
  bool _isLoading = true;
  String? _cheerToast;

  // Quiz & Match paylaşımlı state
  List<String> _currentOptions = [];
  String? _selectedOption;
  bool _answered = false;

  // Spelling state
  List<_LetterTile> _letterTiles = [];
  List<_LetterTile> _placedTiles = [];
  bool _spellingChecked = false;
  bool _spellingCorrect = false;

  @override
  void initState() {
    super.initState();
    TtsService.instance.initService();
    _initSession();
  }

  void _initSession() {
    final filtered = widget.cards.where((c) {
      final w = (c['word'] ?? '').toString().trim();
      final m = (c['meaning'] ?? '').toString().trim();
      return w.isNotEmpty && m.isNotEmpty;
    }).toList();

    // Ardışık aynı modun tekrarlanma ihtimalini azaltmak için basit bir
    // "son modu tekrar seçme" kuralıyla rastgele dizi üretiyoruz.
    _MixedMode? lastMode;
    final sequence = <_MixedMode>[];
    for (var i = 0; i < filtered.length; i++) {
      final pool = _MixedMode.values.where((m) => m != lastMode).toList();
      final mode = pool[_rand.nextInt(pool.length)];
      sequence.add(mode);
      lastMode = mode;
    }

    setState(() {
      _questions = filtered;
      _modeSequence = sequence;
      _isLoading = false;
    });

    if (_questions.isNotEmpty) _loadCurrentQuestion();
  }

  List<Map<String, dynamic>> get _distractorPool => widget.allCards.isNotEmpty ? widget.allCards : widget.cards;

  bool _isTooSimilar(String opt1, String opt2) {
    final clean1 = opt1.toLowerCase().replaceAll(RegExp(r'[^a-zçğıöşü]'), ' ').trim();
    final clean2 = opt2.toLowerCase().replaceAll(RegExp(r'[^a-zçğıöşü]'), ' ').trim();
    if (clean1 == clean2) return true;
    final words1 = clean1.split(' ').where((w) => w.length > 2).toSet();
    final words2 = clean2.split(' ').where((w) => w.length > 2).toSet();
    return words1.intersection(words2).isNotEmpty;
  }

  Future<List<String>> _buildOptions(int optionCount) async {
    final card = _questions[_currentIndex];
    final correctAnswer = (card['meaning'] ?? '').toString().trim();
    final word = (card['word'] ?? '').toString().trim();

    final List<String> distinctOptions = [correctAnswer];

    // Önce havuzdaki diğer anlamlardan çeldirici topla (senkron, hızlı).
    final otherMeanings = _distractorPool
        .map((c) => (c['meaning'] ?? '').toString().trim())
        .where((m) => m.isNotEmpty && m != correctAnswer)
        .toSet()
        .toList()
      ..shuffle();
    for (var m in otherMeanings) {
      if (distinctOptions.length >= optionCount) break;
      if (!distinctOptions.any((opt) => _isTooSimilar(opt, m))) distinctOptions.add(m);
    }

    // Yetmezse veritabanının genel sözlüğünden otomatik çeldirici çek.
    if (distinctOptions.length < optionCount) {
      try {
        final dbDistractors = await DatabaseHelper.instance.getDistractorMeanings(
          correctWord: word,
          correctMeaning: correctAnswer,
          count: optionCount,
        );
        for (var m in dbDistractors) {
          if (distinctOptions.length >= optionCount) break;
          if (!distinctOptions.any((opt) => _isTooSimilar(opt, m))) distinctOptions.add(m);
        }
      } catch (_) {}
    }

    // Son çare: sabit yedek liste.
    if (distinctOptions.length < optionCount) {
      final availableFallbacks = _fallbackDistractors
          .where((f) => !distinctOptions.any((opt) => _isTooSimilar(opt, f)))
          .toList()
        ..shuffle();
      for (var f in availableFallbacks) {
        if (distinctOptions.length >= optionCount) break;
        distinctOptions.add(f);
      }
    }

    distinctOptions.shuffle();
    return distinctOptions;
  }

  Future<void> _loadCurrentQuestion() async {
    if (!mounted || _currentIndex >= _questions.length) return;
    final mode = _modeSequence[_currentIndex];

    setState(() {
      _answered = false;
      _selectedOption = null;
      _spellingChecked = false;
      _spellingCorrect = false;
      _placedTiles = [];
      _letterTiles = [];
      _currentOptions = [];
    });

    final card = _questions[_currentIndex];
    final word = (card['word'] ?? '').toString();

    if (mode == _MixedMode.spelling) {
      _setupSpelling(word);
    } else {
      final options = await _buildOptions(4);
      if (!mounted) return;
      setState(() => _currentOptions = options);
    }

    TtsService.instance.speakWord(word);
  }

  void _setupSpelling(String rawWord) {
    final cleanWord = rawWord.trim().toUpperCase().replaceAll(RegExp(r'[^A-ZÇĞİÖŞÜ]'), '');
    if (cleanWord.isEmpty) {
      _nextQuestionOrFinish();
      return;
    }
    final tiles = <_LetterTile>[
      for (var i = 0; i < cleanWord.length; i++) _LetterTile(id: i, letter: cleanWord[i]),
    ];
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final extraCount = cleanWord.length <= 4 ? 3 : 2;
    for (var i = 0; i < extraCount; i++) {
      tiles.add(_LetterTile(id: 100 + i, letter: alphabet[_rand.nextInt(alphabet.length)]));
    }
    tiles.shuffle();
    setState(() => _letterTiles = tiles);
  }

  void _triggerCheer(String msg) {
    if (!mounted) return;
    setState(() => _cheerToast = msg);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _cheerToast == msg) setState(() => _cheerToast = null);
    });
  }

  Future<void> _recordAnswer({required bool isCorrect, required String subMode}) async {
    final cardId = _questions[_currentIndex]['id'] as int? ?? 0;
    if (cardId <= 0) return;
    // V1'in sabit-aralıklı sistemi — dokunulmuyor, paralel çalışıyor.
    unawaited(DatabaseHelper.instance.recordMultiModalResult(cardId: cardId, isCorrect: isCorrect, mode: subMode).catchError((_) {}));
    // FSRS — bu oturumun asıl kaynağı olan sistem.
    unawaited(FsrsRepository.instance.recordReview(cardId: cardId, rating: FsrsRating.fromCorrectness(isCorrect)).catchError((_) {}));
  }

  void _handleOptionSelected(String option) async {
    if (_answered) return;
    final card = _questions[_currentIndex];
    final correctAnswer = (card['meaning'] ?? '').toString().trim();
    final isCorrect = option == correctAnswer;
    final mode = _modeSequence[_currentIndex];
    final subMode = mode == _MixedMode.quiz ? 'quiz' : 'match';

    setState(() {
      _selectedOption = option;
      _answered = true;
    });

    await _recordAnswer(isCorrect: isCorrect, subMode: subMode);
    await _applyResult(isCorrect);

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      _nextQuestionOrFinish();
    });
  }

  void _handleLetterTap(_LetterTile tile) {
    if (_spellingChecked || tile.isUsed) return;
    HapticFeedback.selectionClick();
    setState(() {
      tile.isUsed = true;
      _placedTiles.add(tile);
    });

    final card = _questions[_currentIndex];
    final target = (card['word'] ?? '').toString().trim().toUpperCase().replaceAll(RegExp(r'[^A-ZÇĞİÖŞÜ]'), '');
    if (_placedTiles.length == target.length) {
      _checkSpelling(target);
    }
  }

  void _removeLastLetter() {
    if (_spellingChecked || _placedTiles.isEmpty) return;
    setState(() {
      final last = _placedTiles.removeLast();
      last.isUsed = false;
    });
  }

  void _checkSpelling(String target) async {
    final built = _placedTiles.map((t) => t.letter).join();
    final isCorrect = built == target;

    setState(() {
      _spellingChecked = true;
      _spellingCorrect = isCorrect;
    });

    await _recordAnswer(isCorrect: isCorrect, subMode: 'spelling');
    await _applyResult(isCorrect);

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      _nextQuestionOrFinish();
    });
  }

  Future<void> _applyResult(bool isCorrect) async {
    if (!mounted) return;
    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _score++;
      _streak++;
      final earnedXp = 8 * widget.xpMultiplier;
      _totalEarnedXp += earnedXp;
      await XpShopService.instance.addXp(earnedXp);
      if (!mounted) return;
      final cheer = CoachMessages.getFlashcardCheer(_streak);
      if (cheer != null) _triggerCheer(cheer);
    } else {
      HapticFeedback.heavyImpact();
      _streak = 0;
      _triggerCheer(CoachMessages.getWrongAnswerEncouragement());
    }
  }

  void _nextQuestionOrFinish() {
    if (!mounted) return;
    if (_currentIndex + 1 < _questions.length) {
      setState(() => _currentIndex++);
      _loadCurrentQuestion();
    } else {
      _finishSession();
    }
  }

  void _finishSession() {
    if (!mounted) return;
    final feedback = CoachMessages.getFeedback(
      exerciseType: 'mixed',
      score: _score,
      total: _questions.length,
    );
    CelebrationDialog.show(
      context,
      emoji: feedback.emoji,
      title: feedback.title,
      subtitle: feedback.subtitle,
      earnedXp: _totalEarnedXp,
      actionLabel: feedback.actionLabel,
      onAction: () {
        if (!mounted) return;
        if (feedback.shouldOfferRetry) {
          setState(() {
            _currentIndex = 0;
            _score = 0;
            _streak = 0;
            _totalEarnedXp = 0;
          });
          _initSession();
        } else {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF070B14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF070B14),
        appBar: AppBar(
          backgroundColor: const Color(0xFF070B14),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text('Hafıza Zindanı', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Text('Tekrar edilecek kelime bulunamadı.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
        ),
      );
    }

    final card = _questions[_currentIndex];
    final word = (card['word'] ?? '').toString();
    final mode = _modeSequence[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070B14),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text('Hafıza Zindanı · Karma Mod', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
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
                      Text('Kelime ${_currentIndex + 1} / ${_questions.length}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF94A3B8))),
                      _buildModeBadge(mode),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_currentIndex) / _questions.length,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF111827),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA855F7)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildWordCard(word),
                  const SizedBox(height: 20),
                  Expanded(child: _buildModeBody(mode)),
                ],
              ),
            ),
            if (_cheerToast != null)
              Positioned(
                top: 10,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_cheerToast!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBadge(_MixedMode mode) {
    final data = switch (mode) {
      _MixedMode.quiz => (icon: PhosphorIcons.crosshairBold, label: 'Hızlı Test', color: const Color(0xFF38BDF8)),
      _MixedMode.match => (icon: PhosphorIcons.puzzlePieceBold, label: 'Eşleştirme', color: const Color(0xFF6366F1)),
      _MixedMode.spelling => (icon: PhosphorIcons.waveformBold, label: 'Dinle & Yaz', color: const Color(0xFF10B981)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 13, color: data.color),
          const SizedBox(width: 5),
          Text(data.label, style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w800, color: data.color)),
        ],
      ),
    );
  }

  Widget _buildWordCard(String word) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.5),
      ),
      child: Column(
        children: [
          Text(word, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white)),
          const SizedBox(height: 6),
          IconButton.filledTonal(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.15)),
            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF38BDF8)),
            onPressed: () {
              HapticFeedback.selectionClick();
              TtsService.instance.speakWord(word);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeBody(_MixedMode mode) {
    switch (mode) {
      case _MixedMode.quiz:
        return _buildOptionList(isGrid: false);
      case _MixedMode.match:
        return _buildOptionList(isGrid: true);
      case _MixedMode.spelling:
        return _buildSpellingBody();
    }
  }

  Widget _buildOptionList({required bool isGrid}) {
    if (_currentOptions.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    final correctAnswer = (_questions[_currentIndex]['meaning'] ?? '').toString().trim();

    Widget tile(int index) {
      final option = _currentOptions[index];
      final isSelected = _selectedOption == option;
      final isCorrect = option == correctAnswer;

      Color borderColor = const Color(0xFF1F2937);
      Color bgColor = const Color(0xFF111827);
      Color textColor = Colors.white;
      if (_answered) {
        if (isCorrect) {
          borderColor = const Color(0xFF10B981);
          bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
          textColor = const Color(0xFF10B981);
        } else if (isSelected) {
          borderColor = const Color(0xFFEF4444);
          bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
          textColor = const Color(0xFFEF4444);
        }
      }

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _answered ? null : () => _handleOptionSelected(option),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isSelected || (_answered && isCorrect) ? 2 : 1),
          ),
          child: Text(
            option,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textColor),
          ),
        ),
      );
    }

    if (isGrid) {
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: _currentOptions.length,
        itemBuilder: (context, i) => tile(i),
      );
    }
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _currentOptions.length,
      separatorBuilder: (context, i) => const SizedBox(height: 10),
      itemBuilder: (context, i) => tile(i),
    );
  }

  Widget _buildSpellingBody() {
    final card = _questions[_currentIndex];
    final target = (card['word'] ?? '').toString().trim().toUpperCase().replaceAll(RegExp(r'[^A-ZÇĞİÖŞÜ]'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _spellingChecked
                  ? (_spellingCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                  : const Color(0xFF1F2937),
              width: 1.5,
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              for (var i = 0; i < target.length; i++)
                _buildSpellingSlot(i < _placedTiles.length ? _placedTiles[i].letter : null),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!_spellingChecked) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _letterTiles.map((tile) => _buildLetterTile(tile)).toList(),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _placedTiles.isEmpty ? null : _removeLastLetter,
            icon: const Icon(Icons.backspace_outlined, color: Color(0xFF94A3B8), size: 18),
            label: Text('Son Harfi Sil', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _spellingCorrect ? 'Doğru!' : 'Doğrusu: $target',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _spellingCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpellingSlot(String? letter) {
    return Container(
      width: 30,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: letter != null ? const Color(0xFF1F2937) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Text(letter ?? '', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  Widget _buildLetterTile(_LetterTile tile) {
    return GestureDetector(
      onTap: () => _handleLetterTap(tile),
      child: Container(
        width: 38,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tile.isUsed ? const Color(0xFF111827) : const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF374151)),
        ),
        child: Text(
          tile.letter,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: tile.isUsed ? const Color(0xFF374151) : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _LetterTile {
  final int id;
  final String letter;
  bool isUsed = false;
  _LetterTile({required this.id, required this.letter});
}
