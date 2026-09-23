// ============================================================================
// DOSYA ADI: lib/flashcards_exercise_screen.dart
// AÇIKLAMA: Çok Boyutlu SRS, Modalite ('srs') ve Word Boss Entegreli Kart Ekranı
//           (Hile Korumalı Dinamik xpMultiplier ve Şeffaf Çapalama Tasarımı)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tts_service.dart';
import 'xp_shop_service.dart';
import 'celebration_dialog.dart';
import 'coach_messages.dart';
import 'core/design_system/tr_case.dart';
import 'database_helper.dart';
import 'dictionary_service.dart';
import 'core/fsrs/fsrs_repository.dart';
import 'core/fsrs/fsrs_models.dart';
import 'core/coach/ignis_moments_engine.dart';
import 'core/theme/draconic_theme.dart'; // T-1: yapısal renkler temadan
import 'core/branding/app_branding.dart';
import 'core/design_system/primitives.dart'; // P0-D: paylaşılan CheerToast

class FlashcardsExerciseScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final bool isReviewOnly;
  final int xpMultiplier; // Dinamik 2X XP FOMO Koruması

  const FlashcardsExerciseScreen({
    super.key, 
    required this.cards,
    this.isReviewOnly = false,
    this.xpMultiplier = 1,
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
  int _masteredCountInSession = 0;
  int _initialTotal = 0;
  int _consecutiveKnownStreak = 0;
  int _totalEarnedXp = 0;

  String? _cheerMessage;
  bool _isFlipped = false;
  bool _showHint = false;
  bool _celebrationShown = false;
  bool _isProcessing = false;

  // T-1: build() içinde her seferinde set edilir; yardımcı metodlar tema
  // parametresi almak zorunda kalmadan buradan okur.
  late DraconicTheme _theme;

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
    return _posTranslations[clean] ?? pos.toUpperCaseTr();
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
    Future.delayed(const Duration(milliseconds: 2400), () {
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
    int currentStreak = currentCard['success_streak'] as int? ?? (currentCard['repetitions'] as int? ?? 0);

    bool isCorrect = false;
    int xpGain = 0;

    if (rating == 0) {
      isCorrect = false;
      _consecutiveKnownStreak = 0;
      _reviewCount++;
      _struggledCards.add(currentCard);

      if (_reviewCount % 3 == 0) {
        _triggerCheer(CoachMessages.getWrongAnswerEncouragement());
      }
    } else if (rating == 1) {
      isCorrect = true;
      _hardCount++;
      _consecutiveKnownStreak = 0;
      _struggledCards.add(currentCard);
      xpGain = 4 * widget.xpMultiplier;
    } else {
      isCorrect = true;
      _knownCount++;
      _consecutiveKnownStreak++;
      xpGain = 6 * widget.xpMultiplier;

      if (currentStreak + 1 >= 6) {
        if (!widget.isReviewOnly) {
          _masteredCountInSession++;
          xpGain += (15 * widget.xpMultiplier);
          HapticFeedback.heavyImpact();
          _triggerCheer('✨ MASTERED! "${currentCard['word']}" kalıcı hafızada!');
        }
      } else if (currentStreak + 1 == 4) {
        _triggerCheer('🔥 Kalıcı hafızaya yaklaşıyorsun (Aşina)!');
      } else {
        final cheer = CoachMessages.getFlashcardCheer(_consecutiveKnownStreak);
        if (cheer != null) {
          _triggerCheer(cheer);
        }
      }
    }

    if (!widget.isReviewOnly) {
      // P0-D: örnek kelime havuzuyla (negatif cardId) yapılan deneme
      // pratiği XP kazandırmasın — sadece gerçek kelimeler XP verir.
      if (xpGain > 0 && cardId > 0) {
        _totalEarnedXp += xpGain;
        XpShopService.instance.addXp(xpGain).catchError((_) => 0);
      }

      if (cardId > 0) {
        DatabaseHelper.instance.recordMultiModalResult(
          cardId: cardId,
          isCorrect: isCorrect,
          mode: 'srs',
        ).catchError((_) {});
        // EJDERHA ROTASI V2 — FAZ 3: FSRS paralel yazım. V1 sistemine
        // dokunmadan aynı sonucu FSRS motoruna da besliyoruz.
        FsrsRepository.instance.recordReview(
          cardId: cardId,
          rating: FsrsRating.fromCorrectness(isCorrect),
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

  Future<void> _finishSrs() async {
    if (!mounted) return;
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

    // AŞAMA 2 — Ignis Anı: yerel istatistik motorundan veriye dayalı bir
    // mesaj iste (AI yok, sadece daily_stats/flashcards okuması). Ekranın
    // hâlâ mounted olduğunu bu async ara noktadan sonra tekrar kontrol et.
    final ignisMoment = await IgnisMomentsEngine.instance.getSessionEndMoment();
    if (!mounted) return;

    CelebrationDialog.show(
      context,
      emoji: _masteredCountInSession > 0 ? '🏆' : feedback.emoji,
      title: _masteredCountInSession > 0 ? 'Kalıcı Hafızaya Yeni Kelime Eklendi!' : feedback.title,
      subtitle: _masteredCountInSession > 0
          ? '$_masteredCountInSession kelimede ustalığa ulaştın.'
          : feedback.subtitle,
      themeColor: _masteredCountInSession > 0 ? _theme.primaryAmber : feedback.themeColor,
      earnedXp: _totalEarnedXp,
      totalWordsReviewed: _initialTotal,
      strengthenedWords: _knownCount,
      needsReviewWords: needsReviewCount,
      masteredWordsCount: _masteredCountInSession,
      ignisMomentTitle: ignisMoment?.title,
      ignisMomentMessage: ignisMoment?.message,
      ignisMomentPose: ignisMoment?.pose,
      actionLabel: feedback.actionLabel,
      onAction: () {
        if (!mounted) return;
        Navigator.of(context).pop();
      },
      secondaryActionLabel: needsReviewCount > 0
          ? '🧠 Zorlandıklarımı Tekrar Et ($needsReviewCount kelime)'
          : null,
      onSecondaryAction: needsReviewCount > 0
          ? () {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardsExerciseScreen(
                    cards: List.from(_struggledCards),
                    isReviewOnly: true,
                    xpMultiplier: widget.xpMultiplier,
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

  // NOT: 4 durumun (MASTERED/FAMILIAR/REVIEWING/LEARNING) kendine özgü
  // rozet renk şeması T-1 çekirdek token'larıyla birebir eşlenmiyor
  // (FAMILIAR'ın sarısı gibi bazı tonlar tabloda yok) — established
  // per-item semantik rozet istisnası (boss-level rozetleriyle aynı kural).
  Widget _buildLearningStateBadge(String state) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (state) {
      case 'MASTERED':
        bg = const Color(0xFF10B981).withValues(alpha: 0.15);
        fg = const Color(0xFF34D399);
        label = 'Usta (Mastered)';
        icon = Icons.check_circle_rounded;
        break;
      case 'FAMILIAR':
        bg = const Color(0xFFFBBF24).withValues(alpha: 0.15);
        fg = const Color(0xFFFDE68A);
        label = 'Aşina';
        icon = Icons.verified_outlined;
        break;
      case 'REVIEWING':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        fg = const Color(0xFFF59E0B);
        label = 'Tekrarda';
        icon = Icons.loop_rounded;
        break;
      case 'LEARNING':
      default:
        bg = const Color(0xFF818CF8).withValues(alpha: 0.15);
        fg = const Color(0xFF818CF8);
        label = 'Öğreniliyor';
        icon = Icons.auto_stories_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // A-6: sistem geri tuşu/kenar kaydırma (predictive back) artık kapatma
  // butonuyla AYNI onay akışından geçiyor — önceden geri jesti hiçbir
  // uyarı göstermeden ekranı direkt kapatıyordu, kapatma butonu ise zaten
  // aynı şeyi yapıyordu; burada asıl kazanım tutarlılık + kaza ile devam
  // eden bir egzersizden çıkışı önceden sormak (ilerleme her cevapta zaten
  // veritabanına anlık yazıldığı için veri kaybı riski düşük, ama kullanıcı
  // hâlâ kartları bitirmeden yarıda bırakabilir).
  Future<void> _confirmExit() async {
    if (_remainingCards.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        // Kaşını kaldırmış Ignis: "gerçekten gidiyor musun?" 🤨
        icon: Image.asset(
          AppBranding.poseAsset('suspicious'),
          width: 88,
          height: 88,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Egzersizden çık?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Kalan kartları tamamlamadan çıkıyorsun. Bu ana kadarki cevapların zaten kaydedildi.',
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

  Widget _buildEmptyCardsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, color: _theme.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'Bu modda hiç kart yok',
              textAlign: TextAlign.center,
              style: TextStyle(color: _theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Önce koleksiyonuna kelime ekle, sonra buradan tekrar et.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _theme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context).extension<DraconicTheme>()!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
      backgroundColor: _theme.background,
      appBar: AppBar(
        backgroundColor: _theme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: _theme.textPrimary),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.isReviewOnly ? 'Gözden Geçir' : 'SRS Hafıza Egzersizi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _theme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.xpMultiplier > 1 && !widget.isReviewOnly) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _theme.primaryAmber, borderRadius: BorderRadius.circular(6)),
                    child: Text('${widget.xpMultiplier}X XP', style: TextStyle(color: _theme.background, fontWeight: FontWeight.bold, fontSize: 10)),
                  )
                ]
              ],
            ),
            Text(
              '$_initialTotal kelime • ${_getEstimatedSessionTime()}',
              style: TextStyle(fontSize: 11.5, color: _theme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _theme.textPrimary),
          onPressed: _confirmExit,
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // P0 (#17): _remainingCards boşluğu İKİ farklı durumu aynı anda
            // temsil ediyordu — "henüz yüklenmedi" (geçici, spinner doğru) ve
            // "widget.cards baştan boş geldi" (kalıcı, spinner SONSUZA KADAR
            // dönüyordu). _initialTotal (initState'te bir kez set edilir) ile
            // ayırt ediyoruz: 0 ise gerçek/kalıcı boş durum.
            _initialTotal == 0
                ? _buildEmptyCardsState()
                : _remainingCards.isEmpty
                    ? Center(child: CircularProgressIndicator(color: _theme.infoTeal))
                    : _buildExerciseView(),

            if (_cheerMessage != null)
              CheerToast(
                message: _cheerMessage,
                accentColor: (_cheerMessage!.contains('✨') || _cheerMessage!.contains('🏆'))
                    ? _theme.primaryAmber
                    : null,
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildExerciseView() {
    final currentCard = _remainingCards.first;
    final String currentWord = currentCard['word'] ?? '';
    final String? contextSentence = currentCard['context_sentence'] as String?;
    final String bookTitle = (currentCard['book_title'] as String?)?.trim().isNotEmpty == true 
        ? currentCard['book_title'] 
        : 'Kütüphanem';
    final String? chapterInfo = currentCard['chapter_info'] as String?;

    final String currentState = (currentCard['learning_state'] as String? ?? 'LEARNING');
    final int currentIndex = _initialTotal - _remainingCards.length + 1;

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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _theme.textSecondary,
                  fontSize: 13.5,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _theme.successEmerald, size: 16),
                  const SizedBox(width: 4),
                  Text('$_knownCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _theme.textPrimary)),
                  const SizedBox(width: 10),
                  Icon(Icons.replay_circle_filled_rounded, color: _theme.dangerRed, size: 16),
                  const SizedBox(width: 4),
                  Text('$_reviewCount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _theme.textPrimary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (currentIndex - 1) / _initialTotal,
              backgroundColor: _theme.surfaceDark,
              valueColor: AlwaysStoppedAnimation<Color>(_theme.infoTeal),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: Dismissible(
              key: ValueKey('${currentCard['id']}_$currentIndex'),
              direction: _isFlipped && !_isProcessing
                  ? DismissDirection.horizontal 
                  : DismissDirection.none,
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
                  _handleSrsRating(2);
                } else {
                  _handleSrsRating(0);
                }
              },
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: _theme.successEmerald,
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
                  color: _theme.dangerRed,
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
                    color: _theme.surfaceDark,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: currentState == 'MASTERED'
                          ? _theme.successEmerald.withValues(alpha: 0.5)
                          : _theme.borderSubtle,
                      width: 1.5,
                    ),
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
                                  color: _theme.cognitiveIndigo.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _theme.cognitiveIndigo.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.menu_book_rounded, size: 13, color: _theme.cognitiveIndigo),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        '$bookTitle ${chapterInfo != null ? '• $chapterInfo' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _theme.cognitiveIndigo,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildLearningStateBadge(currentState),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: _theme.infoTeal.withValues(alpha: 0.15),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                  icon: Icon(Icons.volume_up_rounded, color: _theme.infoTeal, size: 20),
                                  tooltip: 'Telaffuzu Dinle',
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    TtsService.instance.speakWord(currentWord);
                                  },
                                ),
                              ],
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                color: _theme.textPrimary,
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
                                  color: _theme.infoTeal,
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
                                  fontWeight: FontWeight.w800,
                                  color: _theme.infoTeal,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const Spacer(),

                        if (hasValidContext) ...[
                          if (!_isFlipped) ...[
                            if (!_showHint)
                              // NOT: 0xFFFDE68A (sarı) — "İpucu" ikon/metin
                              // kimlik rengi, T-1 çekirdek token'larıyla
                              // eşlenmiyor (rozet renk şemasıyla aynı istisna).
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  backgroundColor: _theme.cognitiveIndigo.withValues(alpha: 0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFFDE68A)),
                                label: const Text('Kitaptan İpucu Gör', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A))),
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
                                  color: _theme.background,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _theme.borderSubtle),
                                ),
                                child: Text(
                                  '“${contextSentence.replaceAll(RegExp(RegExp.escape(currentWord), caseSensitive: false), '___')}”',
                                  textAlign: TextAlign.center,
                                  // NOT: 0xFFCBD5E1 — alıntı metni için sabit
                                  // açık gri ton, T-1 çekirdek token'larıyla
                                  // eşlenmiyor (word_boss'un 0xFFE2E8F0'ıyla
                                  // aynı istisna kuralı).
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ),
                          ] else ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _theme.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _theme.borderSubtle),
                              ),
                              child: Text(
                                '“$contextSentence”',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 14, color: _theme.textMuted),
                            const SizedBox(width: 5),
                            Text(
                              _isFlipped ? 'Gizlemek için dokun' : 'Cevabı görmek için dokun',
                              style: TextStyle(fontSize: 11.5, color: _theme.textMuted),
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
                  backgroundColor: _theme.primaryAmber,
                  foregroundColor: _theme.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.flip_rounded, size: 20),
                label: const Text('Cevabı Göster', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
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
                    color: _theme.dangerRed,
                    icon: Icons.replay_rounded,
                    onTap: () => _handleSrsRating(0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNaturalSrsButton(
                    title: 'Zor',
                    sub: 'Zorlandım',
                    color: _theme.primaryAmber,
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
                    color: _theme.successEmerald,
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